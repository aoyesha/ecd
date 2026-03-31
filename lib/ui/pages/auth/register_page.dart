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
import 'login_page.dart';
import 'widgets/auth_form_parts.dart';
import 'widgets/auth_layout.dart';

const Map<String, Map<String, List<String>>> _regionHierarchy = {
  'MIMAROPA': {
    'Occidental Mindoro': [
      'Abra de Ilog',
      'Calintaan',
      'Looc',
      'Lubang',
      'Mamburao',
      'Paluan',
      'Rizal',
      'Sablayan',
      'San Jose',
      'Santa Cruz',
    ],
    'Oriental Mindoro': [
      'Baco',
      'Bansud',
      'Bongabong',
      'Bulalacao',
      'Naujan',
      'Pinamalayan',
      'Roxas',
      'Socorro',
      'Victoria',
    ],
    'Marinduque': ['Boac North', 'Boac South', 'Gasan', 'Mogpog', 'Torrijos'],
    'Romblon': ['Alcantara', 'Odiongan', 'Romblon', 'San Andres'],
    'Palawan': ['Aborlan', 'Bataraza', 'Coron', 'Narra', 'Roxas', 'Taytay'],
    'Puerto Princesa City': ['Puerto Princesa North', 'Puerto Princesa South'],
    'Calapan City': ['Calapan City North', 'Calapan City South'],
  },
};

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();
  final EmailOtpService _emailOtpService = const EmailOtpService();

  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final schoolCtrl = TextEditingController();

  UserRole role = UserRole.teacher;
  bool obscure = true;
  bool loading = false;
  bool acceptedTos = false;
  bool acceptedPrivacy = false;
  bool showPasswordRules = false;

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUppercase(String v) => RegExp(r'[A-Z]').hasMatch(v);
  bool _hasLowercase(String v) => RegExp(r'[a-z]').hasMatch(v);
  bool _hasNumber(String v) => RegExp(r'[0-9]').hasMatch(v);
  bool _hasSpecialChar(String v) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_]').hasMatch(v);

  int step = 1;
  String? selectedRegion = 'MIMAROPA';
  String? selectedDivision;
  String? selectedDistrict;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    schoolCtrl.dispose();
    super.dispose();
  }

  Widget _passwordChecklist(String value) {
    Widget item(bool ok, String text) => Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? Colors.greenAccent : Colors.white70,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: ok ? Colors.greenAccent : Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(_hasMinLength(value), 'At least 8 characters'),
          item(_hasUppercase(value), 'Contains uppercase letter'),
          item(_hasLowercase(value), 'Contains lowercase letter'),
          item(_hasNumber(value), 'Contains a number'),
          item(_hasSpecialChar(value), 'Contains special character'),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (!formKey.currentState!.validate()) return;
    if (!acceptedTos || !acceptedPrivacy) {
      _snack('You must accept Terms & Conditions and Privacy Policy.');
      return;
    }

    final auth = context.read<AuthService>();
    final normalizedEmail = emailCtrl.text.trim().toLowerCase();

    setState(() => loading = true);
    try {
      await auth.ensureEmailAvailable(normalizedEmail);
      var challenge = _emailOtpService.createChallenge();
      await _emailOtpService.sendOtp(
        email: normalizedEmail,
        challenge: challenge,
      );

      if (!mounted) return;
      setState(() => loading = false);

      final verified = await _showOtpDialog(
        email: normalizedEmail,
        initialChallenge: challenge,
      );

      if (!mounted || !verified) return;

      setState(() => loading = true);
      await auth.register(
        role: role,
        email: normalizedEmail,
        password: passCtrl.text,
        name: nameCtrl.text,
        school: schoolCtrl.text,
        district: selectedDistrict,
        division: selectedDivision,
        region: selectedRegion,
        acceptedTos: acceptedTos,
        acceptedPrivacy: acceptedPrivacy,
      );

      if (!mounted) return;
      _snack('Account verified and created. You can now log in.');
      // Don't navigate manually - the auth state change will auto-redirect via app.dart's home widget
    } catch (e) {
      if (e is StateError && e.message == 'Email already exists.') {
        _snack('This email is already registered.');
      } else if (e is StateError &&
          e.message.toString().contains('Email OTP is not configured')) {
        _snack(
          'Email OTP is not configured yet. Add SMTP settings before testing sign up.',
        );
      } else {
        final debugMessage = kDebugMode
            ? 'Registration failed: ${e.runtimeType}: $e'
            : 'Registration failed. Please try again.';
        _snack(debugMessage);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> _showOtpDialog({
    required String email,
    required EmailOtpChallenge initialChallenge,
  }) async {
    final otpCtrl = TextEditingController();
    var errorText = '';
    var successText = '';
    var challenge = initialChallenge;
    var sending = false;

    final verified = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Verify Your Email'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A 6-digit code was sent to:'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          email,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Enter OTP Code',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: otpCtrl,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 8,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          hintStyle: const TextStyle(letterSpacing: 8),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFE0E0E0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFD32F2F),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      if (errorText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFEF9A9A),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFD32F2F),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorText,
                                  style: const TextStyle(
                                    color: Color(0xFFD32F2F),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (successText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFC8E6C9),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF2E7D32),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  successText,
                                  style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Expires: ${TimeOfDay.fromDateTime(challenge.expiresAt).format(context)}',
                            style: const TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 12,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: sending
                                ? null
                                : () async {
                                    setDialogState(() {
                                      sending = true;
                                      errorText = '';
                                      successText = '';
                                    });

                                    try {
                                      final nextChallenge = _emailOtpService
                                          .createChallenge();
                                      await _emailOtpService.sendOtp(
                                        email: email,
                                        challenge: nextChallenge,
                                      );
                                      setDialogState(() {
                                        challenge = nextChallenge;
                                        successText = 'New code sent.';
                                      });
                                    } catch (e) {
                                      setDialogState(() {
                                        errorText = 'Failed to send code.';
                                      });
                                    } finally {
                                      setDialogState(() => sending = false);
                                    }
                                  },
                            icon: sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: Text(sending ? 'Sending...' : 'Resend'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                  ),
                  onPressed: () {
                    final enteredCode = otpCtrl.text.trim();
                    if (challenge.isExpired) {
                      setDialogState(() {
                        errorText = 'Code expired. Request a new one.';
                      });
                      return;
                    }

                    if (enteredCode.length != 6) {
                      setDialogState(() {
                        errorText = 'Please enter all 6 digits.';
                      });
                      return;
                    }

                    if (enteredCode != challenge.code) {
                      setDialogState(() {
                        errorText = 'Incorrect code. Try again.';
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

  void _snack(String message) {
    final tone =
        message.toLowerCase().contains('failed') ||
            message.toLowerCase().contains('incorrect') ||
            message.toLowerCase().contains('not configured') ||
            message.toLowerCase().contains('already registered')
        ? AppFeedbackTone.error
        : AppFeedbackTone.success;
    AppFeedback.showSnackBar(context, message, tone: tone);
  }

  Future<void> _showPolicyDialog({
    required String title,
    required String content,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        // Responsive dialog width: 90% on mobile, max 600 on larger screens
        final screenWidth = MediaQuery.of(context).size.width;
        final dialogWidth = screenWidth < 700
            ? screenWidth * 0.9
            : 600.0;

        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Text(content, style: const TextStyle(height: 1.45)),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      heading: 'Create an Account',
      form: Form(key: formKey, child: step == 1 ? _stepOne() : _stepTwo()),
    );
  }

  Widget _stepOne() {
    final divisions = selectedRegion == null
        ? <String>[]
        : _regionHierarchy[selectedRegion!]!.keys.toList();
    final districts = (selectedRegion != null && selectedDivision != null)
        ? _regionHierarchy[selectedRegion!]![selectedDivision!]!
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFormParts.label('Account Role'),
        DropdownButtonFormField<UserRole>(
          value: role,
          items: const [
            DropdownMenuItem(value: UserRole.teacher, child: Text('Teacher')),
            DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
          ],
          onChanged: (v) => setState(() => role = v ?? UserRole.teacher),
          decoration: AuthFormParts.inputDecoration('Select role'),
        ),
        const SizedBox(height: 14),
        AuthFormParts.label('Region'),
        DropdownButtonFormField<String>(
          value: selectedRegion,
          items: _regionHierarchy.keys
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() {
            selectedRegion = v;
            selectedDivision = null;
            selectedDistrict = null;
          }),
          decoration: AuthFormParts.inputDecoration('Select region'),
        ),
        const SizedBox(height: 14),
        AuthFormParts.label('Division'),
        DropdownButtonFormField<String>(
          value: selectedDivision,
          items: divisions
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() {
            selectedDivision = v;
            selectedDistrict = null;
          }),
          decoration: AuthFormParts.inputDecoration('Select division'),
          validator: (v) => Validators.required(v, label: 'Division'),
        ),
        const SizedBox(height: 14),
        AuthFormParts.label('District'),
        DropdownButtonFormField<String>(
          value: selectedDistrict,
          items: districts
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => selectedDistrict = v),
          decoration: AuthFormParts.inputDecoration('Select district'),
          validator: (v) => Validators.required(v, label: 'District'),
        ),
        const SizedBox(height: 14),
        AuthFormParts.label('Institution / School Name'),
        TextFormField(
          controller: schoolCtrl,
          decoration: AuthFormParts.inputDecoration('Enter school name'),
          validator: (v) => Validators.required(v, label: 'School'),
        ),
        const SizedBox(height: 18),
        ElevatedButton(
          style: AuthFormParts.actionButtonStyle(),
          onPressed: () {
            if (selectedDivision == null || selectedDistrict == null) {
              _snack('Please complete Region/Division/District.');
              return;
            }
            if (schoolCtrl.text.trim().isEmpty) {
              _snack('School is required.');
              return;
            }
            setState(() => step = 2);
          },
          child: const Text('Next'),
        ),
        const SizedBox(height: 12),
        _loginHint(),
      ],
    );
  }

  Widget _stepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthFormParts.label('Full Name'),
        TextFormField(
          controller: nameCtrl,
          decoration: AuthFormParts.inputDecoration('Juan Dela Cruz'),
          validator: (v) {
            final value = v?.trim() ?? '';

            if (value.isEmpty) {
              return 'Name is required';
            }

            final nameRegex = RegExp(r"^[A-Za-z]+([ '\-][A-Za-z]+)*$");

            if (!nameRegex.hasMatch(value)) {
              return 'Name must contain letters only';
            }

            return null;
          },
        ),
        const SizedBox(height: 14),
        AuthFormParts.label('Your Email'),
        TextFormField(
          controller: emailCtrl,
          decoration: AuthFormParts.inputDecoration(
            'juan.delacruz@deped.gov.ph',
          ),
          keyboardType: TextInputType.emailAddress,
          validator: Validators.accountEmail,
        ),
        const SizedBox(height: 14),
        AuthFormParts.label('Set Password'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: passCtrl,
              obscureText: obscure,
              onChanged: (_) => setState(() => showPasswordRules = true),
              decoration: AuthFormParts.inputDecoration('••••••••').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => obscure = !obscure),
                ),
              ),
              validator: (value) {
                final v = value ?? '';
                if (!_hasMinLength(v) ||
                    !_hasUppercase(v) ||
                    !_hasLowercase(v) ||
                    !_hasNumber(v) ||
                    !_hasSpecialChar(v)) {
                  return 'Password does not meet requirements';
                }
                return null;
              },
            ),

            if (showPasswordRules) _passwordChecklist(passCtrl.text),
          ],
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            unselectedWidgetColor: Colors.white, // important
          ),
          child: CheckboxListTile(
            value: acceptedTos,
            onChanged: (v) => setState(() => acceptedTos = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,

            // ⭐ THIS FIXES THE BORDER COLOR
            side: const BorderSide(color: Colors.white, width: 1.6),

            fillColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.white;
              }
              return Colors.transparent;
            }),
            checkColor: Colors.black,

            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('I accept ', style: TextStyle(color: Colors.white)),
                _whiteLink(
                  text: 'Terms and Conditions',
                  onTap: () => _showPolicyDialog(
                    title: 'Terms and Conditions',
                    content: _termsAndConditionsText,
                  ),
                ),
              ],
            ),
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
            unselectedWidgetColor: Colors.white,
          ),
          child: CheckboxListTile(
            value: acceptedPrivacy,
            onChanged: (v) => setState(() => acceptedPrivacy = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,

            side: const BorderSide(color: Colors.white, width: 1.6),

            fillColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return Colors.white;
              }
              return Colors.transparent;
            }),
            checkColor: Colors.black,

            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('I accept ', style: TextStyle(color: Colors.white)),
                _whiteLink(
                  text: 'Privacy Policy',
                  onTap: () => _showPolicyDialog(
                    title: 'Privacy Policy',
                    content: _privacyPolicyText,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: AuthFormParts.actionButtonStyle(),
          onPressed: loading ? null : _register,
          child: Text(loading ? 'Creating account...' : 'Create Account'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
          ),
          onPressed: () => setState(() => step = 1),
          child: const Text('Back'),
        ),
        const SizedBox(height: 12),
        _loginHint(),
      ],
    );
  }

  Widget _loginHint() {
    return Center(
      child: GestureDetector(
        onTap: () => navReplaceNoTransition(context, const LoginPage()),
        child: RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.white.withOpacity(0.95)),
            children: [
              const TextSpan(text: 'Already have an account? '),
              TextSpan(
                text: 'Log in',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _whiteLink({required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

const String _termsAndConditionsText = '''
1. Acceptance of Terms
By creating and using an Early Childhood Development (ECD) account, you agree to these Terms and Conditions.

2. Email Requirement - IMPORTANT
ONLY DepEd-issued email addresses ending with @deped.gov.ph are authorized to register and use this system.
Personal, third-party, or non-DepEd email addresses are strictly prohibited.
Verification of your @deped.gov.ph email is mandatory for account activation.
Accounts created with non-authorized email addresses will be deactivated immediately.

3. Purpose of Use
This application is intended exclusively for DepEd educators and administrators conducting Early Childhood Development (ECD) assessments.
You agree to use the system only for authorized school, division, district, and regional educational workflows in alignment with DepEd policies.

4. Account Responsibility
You are responsible for keeping your login credentials confidential and secure.
You must ensure that all records entered under your account are accurate, truthful, and current.
You may not share your account credentials with other users; each person must maintain an individual @deped.gov.ph account.

5. Data Entry and Validation
Required learner and class information must be entered truthfully and completely.
Optional fields may be blank, but any provided data must still be accurate and verifiable.
False or misleading information entered into assessments constitutes a violation of this agreement.

6. Assessment Integrity
Checklist responses, raw scores, scaled scores, and interpretation outputs must follow the official SPARKLER process and validation rules implemented in the system.
Users must not intentionally manipulate, alter, or misrepresent learner assessment outcomes.
Assessment data must reflect genuine observations and professional judgment by authorized educators.

7. Local Storage and Exports
Data is stored locally in your deployed Early Childhood Development (ECD) system database within DepEd facilities.
CSV and PDF exports are generated only through explicit user action and must be handled securely according to DepEd data protection guidelines.
Exported files containing learner information are official records requiring secure handling.

8. Authorized Sharing
Exported assessment summaries may be forwarded only through official DepEd reporting channels.
Recipients of exported files must be authorized DepEd personnel or designated educational stakeholders.
Users are responsible for verifying recipient identity and authorization before sharing learner assessment files.

9. Prohibited Actions
You agree not to:
- access another user's account without explicit permission;
- alter, bypass, or manipulate system validations or built-in safeguards;
- use learner data for non-educational, commercial, or unauthorized purposes;
- register using non-DepEd email addresses or share credentials with others;
- export assessment data for purposes outside official DepEd workflows.

10. Changes to the System
Application updates may revise interface design, data fields, reporting formats, or validation rules to align with DepEd policy and technical requirements.
Continued use of the system constitutes acceptance of updates and modifications.

11. Limitation and Support
The system assists in standardized assessment documentation but does not replace the professional judgment of trained educators.
Users remain responsible for interpreting assessment results in context and consulting with learners' families and support teams.
For technical issues or policy clarifications, coordinate with your designated Early Childhood Development (ECD) focal person or DepEd technical support.

12. Policy Compliance
By registering, you confirm that you are a DepEd-authorized educator and that all information provided is accurate.
Non-compliance with these terms may result in account suspension or deactivation.
''';

const String _privacyPolicyText = '''
1. Scope
This Privacy Policy explains how learner, class, teacher, and user account data are handled within the Early Childhood Development (ECD) system deployed by the Department of Education (DepEd).

2. DepEd Authorization
This system is authorized for use by DepEd personnel only.
Only users with valid @deped.gov.ph email addresses are permitted to create accounts and access the system.
Non-DepEd email addresses are prohibited and account access will be immediately terminated if detected.

3. Data Collected
The system collects:
- user account details (name, role, school, division, district, region, @deped.gov.ph email);
- learner profile details (required and optional information entered by authorized DepEd educators);
- detailed assessment responses and computed results;
- class rosters, summaries, and consolidated reports;
- assessment timestamps and user activity records.

4. Purpose of Processing
Data is processed exclusively for:
- standardized learner developmental assessments aligned with DepEd Early Childhood Development standards;
- generating accurate scores, interpretations, and educational recommendations;
- producing class and consolidated reports for school, division, district, and regional administrators;
- supporting authorized DepEd professional development and educational planning;
- maintaining audit trails for data governance and compliance.

5. Data Governance and Storage
System data is stored in the local Early Childhood Development (ECD) database deployed within DepEd-authorized facilities.
Data remains under DepEd control and ownership.
No automatic internet uploads occur; data transmission only happens through explicit user export actions via CSV or PDF.
Exported files are official DepEd educational records.

6. Data Sharing and Access
Data access is restricted to:
- the educator who entered the assessment data (@deped.gov.ph account holder);
- their designated school supervisors and administrators;
- authorized division and district ECD coordinators;
- DepEd officials performing authorized reviews or inspections.

Sharing of assessment data happens only through:
- secure user-generated exports (CSV/PDF) in official DepEd reporting workflows;
- internal school, division, or district reporting systems;
- official DepEd assessment consolidation processes.

Sharing outside DepEd channels is strictly prohibited.

7. Access Control and Authentication
Only authenticated users with active @deped.gov.ph email addresses can access the system.
Role-based access control (teacher/admin) limits visibility and operations based on DepEd authorization level.
Multi-factor authentication (monthly OTP verification) provides additional security for sensitive accounts.

8. Retention and Archiving
Records are retained according to DepEd records management policies and educational standards.
Historical assessment data is preserved for longitudinal analysis, institutional reporting, and accountability purposes.
Archived classes or data sources may be excluded from active dashboards but remain accessible for authorized archival review.
Data is not deleted unless explicitly requested through DepEd records management procedures.

9. Data Security and Protection
Users must protect their @deped.gov.ph credentials and not share account access with other educators.
System passwords must meet security standards (minimum 8 characters, mixed case, numbers, special characters).
Failed login attempts trigger a 5-minute account lockout to prevent unauthorized access.
All data is encrypted in transit and at rest per DepEd cybersecurity standards.

10. Data Accuracy and Correction
Users should review and correct assessment records promptly if errors are identified.
Inaccurate entries can affect learner support decisions, progress reports, and educational planning.
Teachers and administrators share responsibility for data quality and verification.

11. User Responsibilities
Users with @deped.gov.ph accounts must:
- maintain confidentiality of learner information;
- enter assessment data truthfully and professionally;
- verify exported files before sharing with colleagues or supervisors;
- report any data breaches or unauthorized access immediately to their school administration and DepEd technical support;
- not disclose learner identifiable information to unauthorized parties.

12. Non-Compliance
Unauthorized access, data misuse, or account sharing will result in:
- account suspension or permanent deactivation;
- escalation to school administration and DepEd regional offices;
- potential disciplinary action under DepEd personnel policies.

13. Policy Updates
This Privacy Policy may be updated to reflect DepEd policy changes, legal requirements, or system improvements.
Continued use of the system signifies acceptance of the latest policy displayed in the application.

14. Questions and Concerns
For privacy concerns, data requests, or policy questions, contact your DepEd school supervisor or division ECD focal person.
''';
