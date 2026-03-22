/* Currently not working due to SMS region policy restrictions.

Test phone numbers have been configured,
but SMS verification is not being delivered.

The overall issue will be reported in project report.
*/

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:diagnosis_ai/app_drawer.dart';
import 'package:diagnosis_ai/app_colors.dart';

class PhoneSignInScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const PhoneSignInScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();

  bool _submitted = false;
  bool _codeSent = false;
  bool _sending = false;
  bool _verifying = false;

  String? _error;
  String? _verificationId;
  int? _resendToken;
  int _cooldown = 0;
  Timer? _cooldownTimer;

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
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();

    if (!mounted) return;
    setState(() => _cooldown = seconds);

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }

      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendCode() async {
    if (!mounted) return;

    setState(() {
      _submitted = true;
      _error = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = _phoneController.text.trim();

    setState(() => _sending = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential cred) async {
          debugPrint('verificationCompleted fired');

          try {
            final userCredential =
            await FirebaseAuth.instance.signInWithCredential(cred);

            debugPrint(
              'AUTO SIGNED IN: ${userCredential.user?.uid}',
            );

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('auth.sign_in_success'.tr()),
              ),
            );

            Navigator.of(context).pop(true);
          } on FirebaseAuthException catch (e) {
            debugPrint('Auto sign-in FirebaseAuthException: ${e.code} ${e.message}');
            if (!mounted) return;
            setState(() {
              _error = e.message ?? 'auth.unknown_error'.tr();
            });
          } catch (e) {
            debugPrint('Auto sign-in error: $e');
            if (!mounted) return;
            setState(() {
              _error = e.toString();
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('verificationFailed: ${e.code} ${e.message}');

          if (!mounted) return;

          setState(() {
            final msg = e.message ?? '';

            if (msg.contains('BILLING_NOT_ENABLED')) {
              _error = 'auth.billing_not_enabled'.tr();
            } else if (e.code == 'invalid-phone-number') {
              _error = 'auth.invalid_phone'.tr();
            } else if (e.code == 'too-many-requests') {
              _error = 'auth.too_many_requests'.tr();
            } else if (e.code == 'network-request-failed') {
              _error = 'auth.network_error'.tr();
            } else if (e.code == 'captcha-check-failed') {
              _error = 'auth.captcha_failed'.tr();
            } else {
              _error = e.message ?? 'auth.unknown_error'.tr();
            }
          });
        },
        codeSent: (String verificationId, int? forceResendToken) {
          debugPrint('codeSent fired');

          if (!mounted) return;

          setState(() {
            _verificationId = verificationId;
            _resendToken = forceResendToken;
            _codeSent = true;
            _error = null;
          });

          _startCooldown(60);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('auth.sms_sent'.tr())),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('codeAutoRetrievalTimeout fired');
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      debugPrint('verifyPhoneNumber error: $e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null || _verificationId!.isEmpty) {
      setState(() {
        _error = 'Verification ID is missing. Please request the code again.';
      });
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });

    final code = _smsController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _verifying = false;
        _error = 'auth.sms_code_required'.tr();
      });
      return;
    }

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(cred);

      debugPrint('MANUAL SIGNED IN: ${userCredential.user?.uid}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('auth.sign_in_success'.tr()),
        ),
      );

      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      debugPrint('_verifyCode FirebaseAuthException: ${e.code} ${e.message}');

      if (!mounted) return;

      setState(() {
        if (e.code == 'invalid-verification-code') {
          _error = 'auth.sms_code_invalid'.tr();
        } else if (e.code == 'session-expired') {
          _error = 'auth.session_expired'.tr();
        } else {
          _error = e.message ?? 'auth.unknown_error'.tr();
        }
      });
    } catch (e) {
      debugPrint('_verifyCode error: $e');

      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
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
                  isDark
                      ? 'assets/frame_dark.png'
                      : 'assets/frame_light.png',
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _submitted
                        ? AutovalidateMode.always
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),


                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange, width: 1.2),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              const Icon(Icons.warning_amber, color: Colors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'auth.phone_disabled'.tr(),
                                  style: TextStyle(
                                    color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

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
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            labelText: 'auth.phone_number'.tr(),
                            hintText: '+1234567890',
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF2C2C2E)
                                : Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
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
                            if (value.isEmpty) {
                              return 'auth.phone_required'.tr();
                            }

                            // for regex here number needs to have "+" and 6 numbers
                            final rx = RegExp(r'^\+\d{6,}$');
                            if (!rx.hasMatch(value)) {
                              return 'auth.invalid_phone'.tr();
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        if (_codeSent) ...[
                          TextFormField(
                            controller: _smsController,
                            keyboardType: TextInputType.number,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              labelText: 'auth.sms_code'.tr(),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
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
                              if (!_codeSent) return null;
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) {
                                return 'auth.sms_code_required'.tr();
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed:
                            (_sending || _cooldown > 0) ? null : _sendCode,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: (_sending || _cooldown > 0)
                                    ? (isDark
                                    ? Colors.white24
                                    : Colors.black26)
                                    : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF024EE1)),
                                width: 1.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                            ),
                            child: Text(
                              _cooldown > 0
                                  ? 'verify.resend_in'
                                  .tr(args: [_cooldown.toString()])
                                  : 'auth.resend_code'.tr(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: (_sending || _cooldown > 0)
                                    ? (isDark
                                    ? Colors.white54
                                    : Colors.black45)
                                    : (isDark
                                    ? Colors.white
                                    : const Color(0xFF024EE1)),
                              ),
                            ),
                          ),
                        ],
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
                            onPressed: _codeSent
                                ? (_verifying ? null : _verifyCode)
                                : (_sending ? null : _sendCode),
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
                              _codeSent
                                  ? (_verifying
                                  ? 'auth.verifying'.tr()
                                  : 'auth.verify_and_sign_in'.tr())
                                  : (_sending
                                  ? 'auth.sending'.tr()
                                  : 'auth.send_code'.tr()),
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
                              fontSize: 18,
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