import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/nav_no_transition.dart';
import '../../../core/validators.dart';
import '../../../services/auth_service.dart';
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

  UserRole role = UserRole.teacher;
  bool loading = false;
  bool obscure = true;

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
    final userId = await auth.login(
      role: role,
      email: emailCtrl.text,
      password: passCtrl.text,
    );
    if (!mounted) return;
    setState(() => loading = false);
    if (userId == null) {
      _snack('Invalid email/password for selected role.');
      return;
    }
    await navReplaceNoTransition(context, const AppShell());
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
              decoration:
                  AuthFormParts.inputDecoration('juan.delacruz@deped.gov.ph'),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            AuthFormParts.label('Password'),
            TextFormField(
              controller: passCtrl,
              obscureText: obscure,
              decoration: AuthFormParts.inputDecoration('••••••••').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
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
