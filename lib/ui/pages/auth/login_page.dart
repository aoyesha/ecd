import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/nav_no_transition.dart';
import '../../../core/ui_feedback.dart';
import '../../../core/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/email_otp_service.dart';
import '../../widgets/app_shell.dart';
import 'register_page.dart';
import 'widgets/auth_form_parts.dart';
import 'widgets/auth_layout.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final EmailOtpService _emailOtpService = const EmailOtpService();

  UserRole role = UserRole.teacher;
  bool loading = false;
  bool obscure = true;

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUppercase(String v) => RegExp(r'[A-Z]').hasMatch(v);
  bool _hasLowercase(String v) => RegExp(r'[a-z]').hasMatch(v);
  bool _hasNumber(String v) => RegExp(r'[0-9]').hasMatch(v);
  bool _hasSpecialChar(String v) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v);

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);
    final auth = context.read<AuthService>();

    try {
      final result = await auth.login(
        role: role,
        email: emailCtrl.text,
        password: passCtrl.text,
      );

      if (!mounted) return;

      switch (result.status) {
        case AuthLoginStatus.invalidCredentials:
          setState(() => loading = false);
          _snack('The email or password you entered is incorrect.');
          return;
        case AuthLoginStatus.lockedOut:
          setState(() => loading = false);
          _snack(_lockoutMessage(result.lockUntil));
          return;
        case AuthLoginStatus.requiresMonthlyOtp:
          setState(() => loading = false);
          final verified = await _showMonthlyOtpDialog(
            email: result.email!,
            initialChallenge: result.challenge!,
          );
          if (!mounted || !verified) return;

          setState(() => loading = true);
          await auth.completeLogin(
            userId: result.userId!,
            role: result.role!,
            markMonthlyVerified: true,
          );
          if (!mounted) return;
          setState(() => loading = false);
          await navReplaceNoTransition(context, const AppShell());
          return;
        case AuthLoginStatus.success:
          setState(() => loading = false);
          await navReplaceNoTransition(context, const AppShell());
          return;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      final message = kDebugMode
          ? 'Login failed: ${e.runtimeType}: $e'
          : 'Login failed. Please try again.';
      _snack(message);
    }
  }

  Future<bool> _showMonthlyOtpDialog({
    required String email,
    required EmailOtpChallenge initialChallenge,
  }) async {
    final otpCtrl = TextEditingController();
    var challenge = initialChallenge;
    var errorText = '';
    var helperText =
        'A monthly verification code was sent to $email to confirm that this teacher account is still active.';
    var sending = false;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Monthly Account Verification'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(helperText),
                  const SizedBox(height: 12),
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: 'OTP code',
                      errorText: errorText.isEmpty ? null : errorText,
                    ),
                  ),
                  Text(
                    'This code expires at ${TimeOfDay.fromDateTime(challenge.expiresAt).format(dialogContext)}.',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: sending
                        ? null
                        : () async {
                            setDialogState(() {
                              sending = true;
                              errorText = '';
                            });
                            try {
                              final nextChallenge = _emailOtpService
                                  .createChallenge();
                              await _emailOtpService.sendOtp(
                                email: email,
                                challenge: nextChallenge,
                                purpose:
                                    EmailOtpPurpose.monthlyLoginVerification,
                              );
                              setDialogState(() {
                                challenge = nextChallenge;
                                helperText =
                                    'A new verification code was sent.';
                              });
                            } catch (e) {
                              setDialogState(() {
                                errorText = kDebugMode
                                    ? 'Failed to send verification code: ${e.runtimeType}: $e'
                                    : 'Failed to send verification code. Please try again.';
                              });
                            } finally {
                              setDialogState(() => sending = false);
                            }
                          },
                    icon: sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: const Text('Resend code'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final entered = otpCtrl.text.trim();
                    if (challenge.isExpired) {
                      setDialogState(() {
                        errorText =
                            'This code has expired. Please request another one.';
                      });
                      return;
                    }
                    if (entered != challenge.code) {
                      setDialogState(() {
                        errorText = 'The OTP you entered is incorrect.';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Verify'),
                ),
              ],
            );
          },
        );
      },
    );

    otpCtrl.dispose();
    return verified ?? false;
  }

  Future<void> _showForgotPasswordDialog() async {
    final auth = context.read<AuthService>();
    EmailOtpChallenge? challenge;
    var resetEmail = emailCtrl.text.trim();
    var otpCode = '';
    var newPassword = '';
    var confirmPassword = '';
    var helperText =
        'Enter the email for the account you want to reset. We will send a reset code to that address.';
    var generalErrorText = '';
    var otpErrorText = '';
    var passwordErrorText = '';
    var confirmPasswordErrorText = '';
    var sending = false;
    var resetting = false;
    UserRole? matchedRole;

    final resetSuccessful = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Reset Password'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(helperText),
                    if (generalErrorText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        generalErrorText,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: resetEmail,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) => resetEmail = value,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 10),
                    if (challenge != null) ...[
                      TextField(
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        onChanged: (value) => otpCode = value,
                        decoration: InputDecoration(
                          labelText: 'Reset OTP',
                          errorText: otpErrorText.isEmpty ? null : otpErrorText,
                        ),
                      ),
                      TextField(
                        obscureText: true,
                        onChanged: (value) => newPassword = value,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          errorText: passwordErrorText.isEmpty
                              ? null
                              : passwordErrorText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        obscureText: true,
                        onChanged: (value) => confirmPassword = value,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          errorText: confirmPasswordErrorText.isEmpty
                              ? null
                              : confirmPasswordErrorText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use at least 8 characters with uppercase, lowercase, number, and special character.',
                        style: Theme.of(dialogContext).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                if (challenge != null)
                  TextButton(
                    onPressed: sending
                        ? null
                        : () async {
                            setDialogState(() {
                              sending = true;
                              generalErrorText = '';
                              otpErrorText = '';
                              passwordErrorText = '';
                              confirmPasswordErrorText = '';
                            });
                            try {
                              final email = resetEmail.trim();
                              final user = await auth.getUserByEmailAnyRole(
                                email,
                              );
                              if (user == null) {
                                setDialogState(() {
                                  generalErrorText =
                                      'No account was found for this email address.';
                                });
                                return;
                              }
                              final nextRole =
                                  ((user['role'] ?? '')
                                          .toString()
                                          .toLowerCase() ==
                                      UserRole.admin.name)
                                  ? UserRole.admin
                                  : UserRole.teacher;
                              final nextChallenge = _emailOtpService
                                  .createChallenge();
                              await _emailOtpService.sendOtp(
                                email: email,
                                challenge: nextChallenge,
                                purpose: EmailOtpPurpose.passwordReset,
                              );
                              setDialogState(() {
                                challenge = nextChallenge;
                                matchedRole = nextRole;
                                helperText =
                                    'A new reset code was sent to $email for the ${roleLabel(nextRole).toLowerCase()} account.';
                              });
                            } catch (e) {
                              setDialogState(() {
                                generalErrorText = kDebugMode
                                    ? 'Failed to send reset code: ${e.runtimeType}: $e'
                                    : 'Failed to send reset code.';
                              });
                            } finally {
                              setDialogState(() => sending = false);
                            }
                          },
                    child: const Text('Resend'),
                  ),
                FilledButton(
                  onPressed: sending || resetting
                      ? null
                      : () async {
                          final email = resetEmail.trim();
                          final emailValidation = Validators.accountEmail(
                            email,
                          );
                          if (emailValidation != null) {
                            setDialogState(() {
                              generalErrorText = emailValidation;
                            });
                            return;
                          }

                          if (challenge == null) {
                            setDialogState(() {
                              sending = true;
                              generalErrorText = '';
                              otpErrorText = '';
                              passwordErrorText = '';
                              confirmPasswordErrorText = '';
                            });
                            try {
                              final user = await auth.getUserByEmailAnyRole(
                                email,
                              );
                              if (user == null) {
                                setDialogState(() {
                                  generalErrorText =
                                      'No account was found for this email address.';
                                });
                                return;
                              }
                              final nextRole =
                                  ((user['role'] ?? '')
                                          .toString()
                                          .toLowerCase() ==
                                      UserRole.admin.name)
                                  ? UserRole.admin
                                  : UserRole.teacher;
                              final nextChallenge = _emailOtpService
                                  .createChallenge();
                              await _emailOtpService.sendOtp(
                                email: email,
                                challenge: nextChallenge,
                                purpose: EmailOtpPurpose.passwordReset,
                              );
                              setDialogState(() {
                                challenge = nextChallenge;
                                matchedRole = nextRole;
                                helperText =
                                    'A reset code was sent to $email for the ${roleLabel(nextRole).toLowerCase()} account. Enter it with your new password below.';
                              });
                            } catch (e) {
                              setDialogState(() {
                                generalErrorText = kDebugMode
                                    ? 'Reset OTP failed: ${e.runtimeType}: $e'
                                    : 'Failed to send reset code.';
                              });
                            } finally {
                              setDialogState(() => sending = false);
                            }
                            return;
                          }

                          if (!_isStrongPassword(newPassword)) {
                            setDialogState(() {
                              passwordErrorText =
                                  'Password must be at least 8 characters and include uppercase, lowercase, number, and special character.';
                              confirmPasswordErrorText = '';
                            });
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            setDialogState(() {
                              passwordErrorText = '';
                              confirmPasswordErrorText =
                                  'Passwords do not match.';
                            });
                            return;
                          }

                          if (challenge!.isExpired) {
                            setDialogState(() {
                              otpErrorText =
                                  'This reset code has expired. Please request another one.';
                            });
                            return;
                          }

                          if (otpCode.trim() != challenge!.code) {
                            setDialogState(() {
                              otpErrorText =
                                  'The OTP you entered is incorrect.';
                            });
                            return;
                          }

                          setDialogState(() {
                            resetting = true;
                            generalErrorText = '';
                            otpErrorText = '';
                            passwordErrorText = '';
                            confirmPasswordErrorText = '';
                          });
                          try {
                            await auth.resetPasswordByEmail(
                              role: matchedRole ?? role,
                              email: email,
                              newPassword: newPassword,
                            );
                            if (!dialogContext.mounted) return;
                            FocusScope.of(dialogContext).unfocus();
                            Navigator.of(dialogContext).pop(true);
                            return;
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              generalErrorText = kDebugMode
                                  ? 'Reset failed: ${e.runtimeType}: $e'
                                  : 'Failed to reset password.';
                            });
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() => resetting = false);
                            }
                          }
                        },
                  child: Text(
                    challenge == null
                        ? (sending ? 'Sending...' : 'Send Code')
                        : (resetting ? 'Resetting...' : 'Reset Password'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (resetSuccessful == true && mounted) {
      AppFeedback.showSnackBar(
        context,
        'Password reset successful. You can now log in.',
        tone: AppFeedbackTone.success,
      );
    }
  }

  bool _isStrongPassword(String value) {
    return _hasMinLength(value) &&
        _hasUppercase(value) &&
        _hasLowercase(value) &&
        _hasNumber(value) &&
        _hasSpecialChar(value);
  }

  void _snack(String message) {
    AppFeedback.showSnackBar(context, message, tone: AppFeedbackTone.error);
  }

  String _lockoutMessage(DateTime? lockUntil) {
    if (lockUntil == null) {
      return 'Too many failed attempts. Please try again in 5 minutes.';
    }

    final remaining = lockUntil.difference(DateTime.now());
    if (remaining.isNegative) {
      return 'Too many failed attempts. Please try again now.';
    }

    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    if (minutes > 0) {
      return 'Too many failed attempts. Try again in ${minutes}m ${seconds}s.';
    }
    return 'Too many failed attempts. Try again in ${seconds}s.';
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      heading: 'Log in',
      form: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthFormParts.label('Your Email'),
            TextFormField(
              controller: emailCtrl,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
              decoration:
                  AuthFormParts.inputDecoration(
                    'juan.delacruz@deped.gov.ph',
                  ).copyWith(
                    hintStyle: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            AuthFormParts.label('Password'),
            TextFormField(
              controller: passCtrl,
              obscureText: obscure,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w500,
              ),
              decoration: AuthFormParts.inputDecoration('••••••••').copyWith(
                hintStyle: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: loading ? null : _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 4,
                  ),
                ),
                child: const Text('Forgot Password?'),
              ),
            ),
            const SizedBox(height: 8),
            _roleSelector(),
            const SizedBox(height: 18),
            ElevatedButton(
              style: AuthFormParts.actionButtonStyle(),
              onPressed: loading ? null : _login,
              child: Text(loading ? 'Logging in...' : 'Log in'),
            ),
            const SizedBox(height: 14),
            Center(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: Colors.white.withOpacity(0.95)),
                  children: [
                    const TextSpan(text: "Don't have an account yet? "),
                    TextSpan(
                      text: 'Sign Up',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () =>
                            navPushNoTransition(context, const RegisterPage()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Radio<UserRole>(
          value: UserRole.teacher,
          groupValue: role,
          fillColor: WidgetStateProperty.all(Colors.white),
          onChanged: (v) => setState(() => role = v ?? UserRole.teacher),
        ),
        const Text('Teacher', style: TextStyle(color: Colors.white)),
        const SizedBox(width: 22),
        Radio<UserRole>(
          value: UserRole.admin,
          groupValue: role,
          fillColor: WidgetStateProperty.all(Colors.white),
          onChanged: (v) => setState(() => role = v ?? UserRole.admin),
        ),
        const Text('Admin', style: TextStyle(color: Colors.white)),
      ],
    );
  }
}
