import 'package:diagnosis_ai/screens/verify_email.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:diagnosis_ai/app_drawer.dart';
import 'package:diagnosis_ai/app_colors.dart';

class EmailRegisterScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const EmailRegisterScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<EmailRegisterScreen> createState() => _EmailRegisterScreenState();
}

Widget _buildPasswordStrengthIndicator(String password, bool isDarkMode) {
  int score = 0;

  if (password.length >= 6) score++;
  if (password.length >= 10) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#\$&*~()]').hasMatch(password)) score++;

  Color color;
  String label;

  switch (score) {
    case 0:
    case 1:
      color = const Color(0xFFFA0909);
      label = tr('auth.strength_weak');
      break;
    case 2:
    case 3:
      color = Colors.orangeAccent;
      label = tr('auth.strength_medium');
      break;
    default:
      color = Colors.green;
      label = tr('auth.strength_strong');
  }

  return Container(
    margin: const EdgeInsets.only(top: 4, bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    decoration: BoxDecoration(
      color: isDarkMode ? const Color(0xFF2C2C2E) : Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black12),
    ),
    child: Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: score >= 4 ? 1.0 : score / 5,
            color: color,
            backgroundColor: color.withOpacity(0.2),
            minHeight: 6,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(offset: Offset(0.5, 0.5), color: Colors.black12, blurRadius: 1),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmailRegisterScreenState extends State<EmailRegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _submitted = false;

  String? _error;
  bool _showPasswordStrength = false;

  // borders
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
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      if (!_showPasswordStrength && _passwordController.text.isNotEmpty) {
        setState(() => _showPasswordStrength = true);
      } else {
        setState(() {}); // обновляем индикатор при вводе
      }
    });
  }


  @override
  // dispose is like cleaning out memory
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() {
      _submitted = true;
      _error = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      setState(() => _error = 'auth.passwords_do_not_match'.tr());
      return;
    }

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              isDarkMode: widget.isDarkMode,
              onThemeChanged: widget.onThemeChanged,
              nextRouteName: '/body_selection',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );
          final user = cred.user;

          if (user != null && !user.emailVerified) {
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

          // if verified then go to body selection screen
          if (user != null && user.emailVerified) {
            if (!mounted) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/body_selection',
                  (route) => false,
            );
            return;
          }

        } on FirebaseAuthException catch (e2) {
          setState(() {
            if (e2.code == 'wrong-password' || e2.code == 'invalid-credential') {
              _error = 'auth.account_exists_login'.tr();
            } else {
              _error = e2.message ?? 'auth.unknown_error'.tr();
            }
          });
        }
      } else {
        setState(() {
          _error = e.message ?? 'auth.unknown_error'.tr();
        });
      }
    }
    catch (e) {
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

    // style for errors
    const errStyle = TextStyle(fontSize: 14, height: 1.25);

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
                    autovalidateMode:
                    _submitted ? AutovalidateMode.always : AutovalidateMode.disabled,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        Text(
                          'auth.sign_up_title'.tr(),
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 16),

                        // Email
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
                            fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            enabledBorder: _enabledBorder(isDark),
                            focusedBorder: _focusedBorder(isDark),
                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.85) : Colors.black54,
                            ),
                            errorMaxLines: 2,
                            errorStyle: const TextStyle(fontSize: 14, height: 1.1),
                            // почти невидимый helper — место больше не «раздувает»
                            helperText: '',
                            helperStyle: const TextStyle(height: 0.01),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'auth.email_required'.tr();
                            final emailRx = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                            if (!emailRx.hasMatch(value)) return 'auth.email_invalid'.tr();
                            return null;
                          },
                        ),

                        const SizedBox(height: 18),

                        // Password
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
                            fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            enabledBorder: _enabledBorder(isDark),
                            focusedBorder: _focusedBorder(isDark),
                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.85) : Colors.black54,
                            ),
                            errorMaxLines: 2,
                            errorStyle: const TextStyle(fontSize: 14, height: 1.1),
                            // почти невидимый helper — место больше не «раздувает»
                            helperText: '',
                            helperStyle: const TextStyle(height: 0.01),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'auth.password_required'.tr();
                            if (value.length < 6) return 'auth.password_too_short'.tr();
                            return null;
                          },
                        ),

                        const SizedBox(height: 8),

                        Visibility(
                          visible: _showPasswordStrength,
                          child: _buildPasswordStrengthIndicator(
                            _passwordController.text,
                            isDark,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'auth.confirm_password'.tr(),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            enabledBorder: _enabledBorder(isDark),
                            focusedBorder: _focusedBorder(isDark),
                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white.withOpacity(0.85) : Colors.black54,
                            ),
                            errorMaxLines: 2,
                            errorStyle: const TextStyle(fontSize: 14, height: 1.1),
                            // почти невидимый helper — место больше не «раздувает»
                            helperText: '',
                            helperStyle: const TextStyle(height: 0.01),
                          ),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'auth.confirm_password_required'.tr();
                            if (value != _passwordController.text.trim()) {
                              return 'auth.passwords_do_not_match'.tr();
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pushReplacementNamed('/email-sign-in'),
                          child: Text(
                            'auth.already_have_account'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                              decoration: TextDecoration.underline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 8),

                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _register,
                            style: ElevatedButton.styleFrom(
                              elevation: 3,
                              backgroundColor:
                              isDark ? AppColors.darkAccent : AppColors.lightPrimary,
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
                              'auth.register'.tr(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
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
