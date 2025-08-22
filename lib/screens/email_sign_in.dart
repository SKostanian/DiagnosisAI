import 'package:diagnosis_ai/screens/verify_email.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:diagnosis_ai/app_drawer.dart';
import 'package:diagnosis_ai/app_colors.dart';

class EmailSignInScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const EmailSignInScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;
  String? _error;

  OutlineInputBorder _enabledBorder(bool isDark) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: isDark ? Colors.white38 : const Color(0xFFBDBDBD),
      width: 1.2,
    ),
  );

  OutlineInputBorder _focusedBorder(bool isDark) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(
      color: isDark ? Colors.white70 : const Color(0xFF024EE1),
      width: 1.6,
    ),
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // fetch sign in methods for an email across SDK versions
  Future<List<String>> _getSignInMethods(String email) async {
    final dynamic auth = FirebaseAuth.instance;
    try {
      // new SDK
      final res = await auth.fetchSignInMethodsForEmail(email);
      return List<String>.from(res as Iterable);
    } catch (_) {
      try {
        // old SDK
        final res = await auth.fetchProvidersForEmail(email);
        return List<String>.from(res as Iterable);
      } catch (_) {
        return const <String>[];
      }
    }
  }

  // forgot password
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    final emailRx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (email.isEmpty || !emailRx.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.email_enter_valid'.tr())),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('auth.reset_link_sent'.tr())),
      );
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'invalid-email' => 'auth.email_invalid'.tr(),
        'user-not-found' => 'auth.user_not_found'.tr(),
        'network-request-failed' => 'auth.network_error'.tr(),
        _ => e.message ?? 'auth.unknown_error'.tr(),
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // Sign in with email/password and preflight
  Future<void> _signIn() async {
    setState(() {
      _submitted = true;
      _error = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final pass = _passwordController.text.trim();

    try {
      // Preflight, which providers are attached to this email
      final methods = await _getSignInMethods(email);
      final usesPassword = methods.contains('password');
      final usesGoogle = methods.contains('google.com');

      if (!usesPassword && usesGoogle) {
        setState(() {
          _error = 'auth.use_google_to_sign_in'.tr();
        });
        return;
      }

      // sign in instance
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: pass);

      final user = cred.user;
      if (user == null) return;

      await user.reload();
      if (!user.emailVerified) {
        await user.sendEmailVerification();
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              isDarkMode: widget.isDarkMode,
              onThemeChanged: widget.onThemeChanged,
              nextRouteName: '/body_selection',
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/body_selection', (route) => false);
    } on FirebaseAuthException catch (e) {
      setState(() {
        switch (e.code) {
          case 'user-not-found':
            _error = 'auth.user_not_found'.tr();
            break;
          case 'wrong-password':
            _error = 'auth.wrong_password'.tr();
            break;
          case 'invalid-credential':
            _error = 'auth.invalid_credential'.tr();
            break;
          case 'too-many-requests':
            _error = 'auth.too_many_requests'.tr();
            break;
          case 'invalid-email':
            _error = 'auth.email_invalid'.tr();
            break;
          case 'user-disabled':
            _error = 'auth.user_disabled'.tr();
            break;
          case 'network-request-failed':
            _error = 'auth.network_error'.tr();
            break;
          default:
            _error = e.message ?? 'auth.unknown_error'.tr();
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
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

    const errStyle = TextStyle(fontSize: 14, height: 1.1);

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
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submitted
                        ? AutovalidateMode.always
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'auth.sign_in_title'.tr(),
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'auth.email'.tr(),
                            filled: true,
                            fillColor:
                            isDark ? const Color(0xFF2C2C2E) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            enabledBorder: _enabledBorder(isDark),
                            focusedBorder: _focusedBorder(isDark),
                            errorBorder: const OutlineInputBorder(
                              borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.black54,
                            ),
                            errorMaxLines: 2,
                            errorStyle: errStyle,
                            helperText: '',
                            helperStyle: const TextStyle(height: 0.01),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'auth.email_required'.tr();
                            final emailRx =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!emailRx.hasMatch(value)) {
                              return 'auth.email_invalid'.tr();
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'auth.password'.tr(),
                            filled: true,
                            fillColor:
                            isDark ? const Color(0xFF2C2C2E) : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 18),
                            enabledBorder: _enabledBorder(isDark),
                            focusedBorder: _focusedBorder(isDark),
                            errorBorder: const OutlineInputBorder(
                              borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius:
                              BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            labelStyle: TextStyle(
                              color: isDark
                                  ? Colors.white.withOpacity(0.85)
                                  : Colors.black54,
                            ),
                            errorMaxLines: 2,
                            errorStyle: errStyle,
                            helperText: '',
                            helperStyle: const TextStyle(height: 0.01),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'auth.password_required'.tr();
                            return null;
                          },
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _forgotPassword,
                            child: Text(
                              'auth.forgot_password'.tr(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_error != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacementNamed('/email-register'),
                          child: Text(
                            'auth.does_not_have_account'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color:
                              isDark ? Colors.white : Colors.black87,
                              decoration: TextDecoration.underline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _signIn,
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
                              'auth.sign_in'.tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () =>
                              Navigator.of(context).pushReplacementNamed('/'),
                          icon: const Icon(Icons.arrow_back),
                          label: Text(
                            'auth.back_to_auth'.tr(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
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
