import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';

import 'package:diagnosis_ai/app_colors.dart';
import 'package:diagnosis_ai/app_drawer.dart';
import 'package:diagnosis_ai/screens/verify_email.dart';
import 'package:diagnosis_ai/services/auth_service.dart';

class GoogleAccountUi {
  final String? displayName;
  final String email;
  final String? photoUrl;

  GoogleAccountUi({
    this.displayName,
    required this.email,
    this.photoUrl,
  });
}

class AuthScreen extends StatefulWidget {
  final VoidCallback onSkip;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const AuthScreen({
    required this.onSkip,
    required this.isDarkMode,
    required this.onThemeChanged,
    super.key,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // consent
  bool _consentAccepted = false;
  bool _isShowingConsent = false;

  // auth state
  GoogleAccountUi? _googleInfo;
  StreamSubscription<User?>? _authSub;
  User? _authUser;
  bool _canShowAccount = false;

  // TEST: set true if you want to always reset consent on every app start
  static const bool _debugAlwaysResetConsent = true;

  @override
  void initState() {
    super.initState();

    _boot();
  }

  Future<void> _boot() async {
    if (_debugAlwaysResetConsent) {
      await _debugResetConsent();
    }

    await _initConsent();

    _applyUser(AuthService().currentUser);
    _authSub = AuthService().userChanges.listen((u) {
      if (!mounted) return;
      setState(() => _applyUser(u));
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _debugResetConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('consentAccepted');
    if (!mounted) return;
    setState(() => _consentAccepted = false);
  }

  Future<void> _initConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool('consentAccepted') ?? false;

    if (!mounted) return;
    setState(() => _consentAccepted = accepted);
  }

  void _applyUser(User? u) {
    _authUser = u;

    if (u == null) {
      _googleInfo = null;
      _canShowAccount = false;
      return;
    }

    _googleInfo = GoogleAccountUi(
      displayName: u.displayName,
      email: u.email ?? '',
      photoUrl: u.photoURL,
    );

    _canShowAccount = AuthService().shouldShowAccountHeader(u);
  }

  bool get _showUnverifiedBanner {
    final u = _authUser;
    if (u == null) return false;
    final providers = u.providerData.map((p) => p.providerId).toSet();
    return !AuthService().shouldShowAccountHeader(u) && providers.contains('password');
  }

  Future<bool> _ensureConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final acceptedNow = prefs.getBool('consentAccepted') ?? false;

    if (!mounted) return false;

    if (acceptedNow) {
      if (!_consentAccepted) setState(() => _consentAccepted = true);
      return true;
    }

    if (_isShowingConsent) return false;

    _isShowingConsent = true;
    try {
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetCtx) => _ConsentSheet(
          isDark: widget.isDarkMode,
          onOpenPrivacy: () => Navigator.pushNamed(context, '/privacy'),
          onOpenTerms: () => Navigator.pushNamed(context, '/terms'),
          onOpenDisclaimer: () => Navigator.pushNamed(context, '/disclaimer'),
        ),
      );

      if (accepted == true) {
        await prefs.setBool('consentAccepted', true);
        if (!mounted) return false;
        setState(() => _consentAccepted = true);
        return true;
      }

      return false;
    } catch (e, st) {
      // TEST: show error (so you can see if it fails silently)
      debugPrint('CONSENT SHOW ERROR: $e');
      debugPrint('$st');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Consent error: $e')),
      );
      return false;
    } finally {
      _isShowingConsent = false;
    }
  }

  Future<void> _goToVerify() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    if (!u.emailVerified) {
      try {
        await u.sendEmailVerification();
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VerifyEmailScreen(
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
          nextRouteName: '/body_selection',
        ),
      ),
    );
  }

  Future<void> _showSkipDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('auth.dialog_are_you_sure'.tr()),
        content: Text(
          'auth.dialog_not_saved'.tr(),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('auth.no'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onSkip();
            },
            child: Text('auth.yes'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _handleContinueWithGoogle() async {
    final ok = await _ensureConsent();
    debugPrint('CONSENT RESULT (Google): $ok');
    if (!ok) return;

    final user = await AuthService().signInWithGoogle();
    if (!mounted) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.google_failed'.tr())),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('auth.welcome'.tr()),
        content: Text(
          '${'auth.signed_in_as'.tr()} ${user.displayName ?? user.email}',
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              widget.onSkip();
            },
            child: Text(
              'auth.continue'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignInEmailPhone() async {
    final ok = await _ensureConsent();
    debugPrint('CONSENT RESULT (Email/Phone): $ok');
    if (!ok) return;

    _openEmailPhoneSheet(context, isDark: widget.isDarkMode);
  }

  Future<void> _handleSkip() async {
    final ok = await _ensureConsent();
    debugPrint('CONSENT RESULT (Skip): $ok');
    if (!ok) return;

    await _showSkipDialog(context);
  }

  Future<void> _handleTestConsentButton() async {
    final ok = await _ensureConsent();
    debugPrint('CONSENT RESULT (TEST BUTTON): $ok');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('TEST consent result: $ok')),
    );
  }

  Future<String?> _showAccountMenuSheet() {
    final isDark = widget.isDarkMode;
    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final textColor = isDark ? Colors.white : Colors.black87;
        final divider = isDark ? Colors.white24 : Colors.black26;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                if (_googleInfo != null)
                  ListTile(
                    leading: const Icon(Icons.switch_account),
                    title: Text(
                      'auth.google_use_another'.tr(),
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.pop(ctx, 'switch'),
                  ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(
                    'auth.sign_out'.tr(),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                  onTap: () => Navigator.pop(ctx, 'signout'),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onAvatarTap() async {
    final choice = await _showAccountMenuSheet();
    if (choice == null) return;

    if (choice == 'signout') {
      await AuthService().signOutAll();
      if (!mounted) return;

      setState(() => _applyUser(null));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.signed_out'.tr())),
      );
      return;
    }

    if (choice == 'switch') {
      final user = await AuthService().signInWithGoogle(forceChooseAccount: true);
      if (!mounted) return;

      if (user != null) {
        setState(() => _applyUser(user));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.switched_account'.tr())),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.google_failed'.tr())),
        );
      }
    }
  }

  Widget _buildOAuthButton({
    required String label,
    required String assetPath,
    required VoidCallback onTap,
    required bool isDark,
    Color? background,
    Color? foreground,
    double height = 56,
    double iconSize = 24,
    double borderWidth = 1,
  }) {
    final resolvedBg = background ?? (isDark ? const Color(0xFF2C2C2E) : Colors.white);
    final resolvedFg = foreground ?? (isDark ? Colors.white : Colors.black87);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 3,
          backgroundColor: resolvedBg,
          foregroundColor: resolvedFg,
          shape: const StadiumBorder(),
          side: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
            width: borderWidth,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(assetPath, height: iconSize),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: resolvedFg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openEmailPhoneSheet(BuildContext context, {required bool isDark}) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: false,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'auth.sign_in_using'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _signInWithEmail(context);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                  ),
                  child: Text(
                    'auth.email_password'.tr(),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _signInWithPhone(context);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                  ),
                  child: Text(
                    'auth.phone_number'.tr(),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _signInWithEmail(BuildContext context) {
    Navigator.pushNamed(context, '/email-register');
  }

  void _signInWithPhone(BuildContext context) {
    Navigator.pushNamed(context, '/phone-sign_in');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;

    final gradient = isDarkMode
        ? LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Colors.black87, Colors.grey.shade900],
    )
        : const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF63E6AB), Color(0xFFD2F4FF)],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawer: AppDrawer(
        selectedLanguage: context.locale.languageCode,
        onLanguageChanged: (_) => setState(() {}),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Switch(
            value: isDarkMode,
            onChanged: widget.onThemeChanged,
            activeColor: Colors.white,
            inactiveThumbColor: AppColors.lightPrimary,
          ),
        ),
        title: (_canShowAccount && _googleInfo != null)
            ? InkWell(
          onTap: _onAvatarTap,
          borderRadius: BorderRadius.circular(28),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: (_googleInfo!.photoUrl != null && _googleInfo!.photoUrl!.isNotEmpty)
                    ? NetworkImage(_googleInfo!.photoUrl!)
                    : null,
                child: (_googleInfo!.photoUrl == null || _googleInfo!.photoUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 24)
                    : null,
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  (_googleInfo!.displayName?.trim().isNotEmpty ?? false)
                      ? _googleInfo!.displayName!.trim()
                      : _googleInfo!.email,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        )
            : null,
        actions: [
          Builder(
            builder: (ctx) => Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: InkWell(
                onTap: () => Scaffold.of(ctx).openEndDrawer(),
                borderRadius: BorderRadius.circular(21),
                child: Ink(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.menu,
                    color: Color(0xFF024EE1),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(gradient: gradient)),
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.scale(
                scale: 1.12,
                child: Image.asset(
                  isDarkMode ? 'assets/frame_dark.png' : 'assets/frame_light.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenHeight = constraints.maxHeight;
                final screenWidth = constraints.maxWidth;
                final buttonsMaxWidth = screenWidth * 0.84;

                final double bannerFont = screenWidth < 360 ? 13.5 : 14.5;
                final double bannerCtaFont = bannerFont + 1;

                final Color verifyBg = isDarkMode ? Colors.white : AppColors.lightPrimary;
                final Color verifyFg = isDarkMode ? Colors.black87 : Colors.white;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenHeight),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // TEST BUTTON (always visible)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _handleTestConsentButton,
                              child: Text(
                                'TEST CONSENT (tap me)',
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Text(
                            'consentAccepted=$_consentAccepted, isShowing=$_isShowingConsent',
                            style: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),

                        if (_showUnverifiedBanner)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (isDarkMode ? AppColors.darkAccent : AppColors.lightPrimary).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDarkMode ? Colors.white24 : AppColors.lightPrimary,
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: isDarkMode ? Colors.white70 : AppColors.lightPrimary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'auth.email_unverified_banner'.tr(),
                                      style: TextStyle(
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                        fontSize: bannerFont,
                                        fontWeight: FontWeight.w600,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _goToVerify,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      backgroundColor: verifyBg,
                                      foregroundColor: verifyFg,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(
                                      'auth.verify_now'.tr(),
                                      style: TextStyle(
                                        fontSize: bannerCtaFont,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        SizedBox(height: screenHeight * 0.008),
                        Image.asset(
                          'assets/logo.png',
                          height: screenHeight * 0.42,
                          width: screenWidth * 1.5,
                          fit: BoxFit.contain,
                        ),

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                          child: Text(
                            'Auth Screen (TEST)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: screenHeight * 0.028,
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: buttonsMaxWidth),
                          child: Column(
                            children: [
                              _buildOAuthButton(
                                label: 'auth.continue_google'.tr(),
                                assetPath: 'assets/google_logo.png',
                                onTap: _handleContinueWithGoogle,
                                isDark: isDarkMode,
                                background: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
                                foreground: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              const SizedBox(height: 12),
                              if (Platform.isIOS)
                                _buildOAuthButton(
                                  label: 'auth.continue_apple'.tr(),
                                  assetPath: 'assets/apple_logo_white.png',
                                  onTap: () async {
                                    final ok = await _ensureConsent();
                                    debugPrint('CONSENT RESULT (Apple): $ok');
                                    if (!ok) return;
                                    // sign in apple
                                  },
                                  isDark: true,
                                  background: const Color(0xFF000000),
                                  foreground: Colors.white,
                                ),
                              SizedBox(height: Platform.isIOS ? 16 : 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Divider(
                                      indent: 8,
                                      endIndent: 8,
                                      color: isDarkMode ? Colors.white24 : Colors.black26,
                                      thickness: 1,
                                    ),
                                  ),
                                  Text(
                                    'auth.or'.tr(),
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      indent: 8,
                                      endIndent: 8,
                                      color: isDarkMode ? Colors.white24 : Colors.black26,
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.center,
                                child: TextButton(
                                  onPressed: _handleSignInEmailPhone,
                                  child: Text(
                                    'auth.sign_in_email_phone'.tr(),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.02),

                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 24),
                          child: TextButton(
                            onPressed: _handleSkip,
                            child: Text(
                              'auth.skip_registration'.tr(),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsentSheet extends StatefulWidget {
  final bool isDark;
  final VoidCallback onOpenPrivacy;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenDisclaimer;

  const _ConsentSheet({
    required this.isDark,
    required this.onOpenPrivacy,
    required this.onOpenTerms,
    required this.onOpenDisclaimer,
  });

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  bool checked = false;

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final divider = widget.isDark ? Colors.white24 : Colors.black26;
    final linkColor = widget.isDark ? const Color(0xFF7CCFFF) : const Color(0xFF024EE1);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'consent.title'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Divider(color: divider, height: 1),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 380),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'consent.description'.tr(),
                      style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _LinkText(
                          label: 'consent.privacy_policy'.tr(),
                          onTap: widget.onOpenPrivacy,
                          color: linkColor,
                        ),
                        _LinkText(
                          label: 'consent.terms_of_use'.tr(),
                          onTap: widget.onOpenTerms,
                          color: linkColor,
                        ),
                        _LinkText(
                          label: 'consent.medical_disclaimer'.tr(),
                          onTap: widget.onOpenDisclaimer,
                          color: linkColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: divider, height: 1),
            CheckboxListTile(
              value: checked,
              onChanged: (v) => setState(() => checked = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'consent.accept_checkbox'.tr(),
                style: TextStyle(color: textColor),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: checked ? () => Navigator.of(context).pop(true) : null,
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                child: Text('consent.accept_button'.tr()),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'consent.decline'.tr(),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _LinkText({
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          decoration: TextDecoration.underline,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
