import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:diagnosis_ai/app_drawer.dart';
import 'package:diagnosis_ai/app_colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final String nextRouteName;

  const VerifyEmailScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.nextRouteName,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with WidgetsBindingObserver {
  bool _sending = false;
  bool _checking = false;
  int _cooldown = 30;
  Timer? _cooldownTimer;
  Timer? _pollTimer;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCooldown();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkVerified(silent: true);
    }
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 0) {
        t.cancel();
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkVerified(silent: true);
    });
  }

  Future<void> _resendEmail() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance
          .setLanguageCode(context.locale.languageCode);

      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      if (!mounted) return;

      // cooldown reload
      setState(() => _cooldown = 30);
      _startCooldown();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('verify.sent_again'.tr())),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'too-many-requests') {
          _error = 'auth.too_many_requests'.tr();
        } else {
          _error = e.message ?? 'auth.unknown_error'.tr();
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerified({bool silent = false}) async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      if (user.emailVerified) {
        _pollTimer?.cancel();
        if (!mounted) return;
        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('verify.success'.tr())),
          );
        }
        Navigator.of(context).pushNamedAndRemoveUntil(
          widget.nextRouteName,
              (route) => false,
        );
      } else {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('verify.not_yet'.tr())),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message ?? 'auth.unknown_error'.tr());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    final gradient = isDark
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

    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final baseText = isDark ? Colors.white : Colors.black87;
    final subText = isDark ? Colors.white70 : Colors.black54;
    final outlineActive =
    isDark ? Colors.white70 : const Color(0xFF024EE1);
    final outlineDisabled = isDark ? Colors.white24 : Colors.black26;
    final disabled = _sending || _cooldown > 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      endDrawer: AppDrawer(
        selectedLanguage: context.locale.languageCode,
        onLanguageChanged: (_) => setState(() {}),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Switch(
            value: isDark,
            onChanged: widget.onThemeChanged,
            activeColor: Colors.white,
            inactiveThumbColor: AppColors.lightPrimary,
          ),
        ),
        actions: [
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: GestureDetector(
                onTap: () => Scaffold.of(context).openEndDrawer(),
                child: Container(
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
                  isDark ? 'assets/frame_dark.png' : 'assets/frame_light.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'verify.title'.tr(),
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: baseText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),

                      // email card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                          isDark ? const Color(0xFF2C2C2E) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : const Color(0xFFBDBDBD),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'verify.subtitle'.tr(),
                              style:
                              TextStyle(fontSize: 16, color: subText),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: baseText,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_error != null) ...[
                        Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // I verified
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _checking
                              ? null
                              : () => _checkVerified(silent: false),
                          style: ElevatedButton.styleFrom(
                            elevation: 3,
                            backgroundColor: isDark
                                ? AppColors.darkAccent
                                : AppColors.lightPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          child: Text(
                            _checking
                                ? 'verify.checking'.tr()
                                : 'verify.i_verified'.tr(),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      OutlinedButton(
                        onPressed: disabled ? null : _resendEmail,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: disabled
                                ? outlineDisabled
                                : outlineActive,
                            width: 1.4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                        ),
                        child: Text(
                          _cooldown > 0
                              ? 'verify.resend_in'
                              .tr(args: [_cooldown.toString()])
                              : 'verify.resend'.tr(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: disabled
                                ? (isDark
                                ? Colors.white54
                                : Colors.black45)
                                : (isDark
                                ? Colors.white
                                : const Color(0xFF024EE1)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'verify.tip'.tr(),
                        style: TextStyle(color: subText),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 16),

                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: baseText,
                        ),
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          'auth.back_to_auth'.tr(),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
