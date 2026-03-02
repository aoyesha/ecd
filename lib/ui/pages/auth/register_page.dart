import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/nav_no_transition.dart';
import '../../../core/validators.dart';
import '../../../services/auth_service.dart';
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
      'Santa Cruz'
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
      'Victoria'
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
  bool _hasSpecialChar(String v) => RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v);

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
    setState(() => loading = true);
    try {
      await context.read<AuthService>().register(
            role: role,
            email: emailCtrl.text,
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
      navReplaceNoTransition(context, const LoginPage());
    } catch (e) {
      _snack('Registration failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
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

  Future<void> _showPolicyDialog({
    required String title,
    required String content,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Text(
                content,
                style: const TextStyle(height: 1.45),
              ),
            ),
          ),
          actions: [
            TextButton(
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
      form: Form(
        key: formKey,
        child: step == 1 ? _stepOne() : _stepTwo(),
      ),
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
          validator: (v) =>
              Validators.required(v, label: 'Division'),
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
          validator: (v) =>
              Validators.required(v, label: 'District'),
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
          validator: (v) => Validators.required(v, label: 'Name'),
        ),
        const SizedBox(height: 14),
        AuthFormParts.label('Your Email'),
        TextFormField(
          controller: emailCtrl,
          decoration:
          AuthFormParts.inputDecoration('juan.delacruz@deped.gov.ph'),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            final v = value?.trim() ?? '';
            if (v.isEmpty) {
              return 'Email is required';
            }

            final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@deped\.gov\.ph$');

            if (!emailRegex.hasMatch(v)) {
              return 'Email must be a valid @deped.gov.ph address';
            }

            return null;
          },
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
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: Colors.white.withOpacity(0.95)),
          children: [
            const TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Log in',
              style: const TextStyle(fontWeight: FontWeight.bold),
              recognizer: TapGestureRecognizer()
                ..onTap = () => navReplaceNoTransition(context, const LoginPage()),
            ),
          ],
        ),
      ),
    );
  }
  Widget _whiteLink({
    required String text,
    required VoidCallback onTap,
  }) {
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
By creating and using an ECCD Checklist account, you agree to these Terms and Conditions.

2. Purpose of Use
This application is intended for educational assessment and reporting aligned with ECCD checklist implementation.
You agree to use the system only for authorized school, division, district, and regional workflows.

3. Account Responsibility
You are responsible for keeping your login credentials confidential.
You must ensure that records entered under your account are accurate and updated.

4. Data Entry and Validation
Required learner and class information must be entered truthfully.
Optional fields may be blank, but any provided data must still be correct.

5. Assessment Integrity
Checklist responses, raw scores, scaled scores, and interpretation outputs must follow the official process implemented in the system.
Users must not intentionally manipulate records to misrepresent learner outcomes.

6. Local Storage and Exports
Data is stored locally in your deployed ECCD system database.
CSV and PDF exports are generated only through user action and should be handled securely.

7. Authorized Sharing
Exported summaries may be forwarded only through official reporting channels.
Users are responsible for verifying recipient identity before sharing files.

8. Prohibited Actions
You agree not to:
- access another user's account without permission;
- alter system behavior to bypass validations or controls;
- use learner data for non-educational or unauthorized purposes.

9. Changes to the System
Application updates may revise interface, fields, or reporting format to align with approved policy and technical requirements.

10. Limitation and Support
The system assists assessment documentation but does not replace professional judgment.
For operational issues, coordinate with your designated ECCD focal personnel or technical support team.
''';

const String _privacyPolicyText = '''
1. Scope
This Privacy Policy explains how learner, class, and user account data are handled within the ECCD Checklist system.

2. Data Collected
The system may collect:
- user account details (name, role, school, district, division, region, email);
- learner profile details (required and optional fields entered by authorized users);
- checklist responses and computed results;
- class and summary report data.

3. Purpose of Processing
Data is processed to:
- record learner assessments;
- compute scores and interpretation summaries;
- generate class and consolidated reports;
- support authorized administrative review and planning.

4. Storage
System data is stored in the local application database configured for this deployment.
No internet upload is performed unless users explicitly export and transmit files through external channels.

5. Data Sharing
Sharing happens through user-generated exports (CSV/PDF) in official reporting workflows.
Users and offices receiving files are responsible for secure handling and storage.

6. Access Control
Only authenticated users can access protected areas of the app.
Role-based access (teacher/admin) is used to limit visibility and operations.

7. Retention and Archiving
Records may be retained for reporting and historical analysis based on institutional requirements.
Archived classes or data sources may be excluded from active summaries but remain available for authorized review.

8. Data Accuracy
Users should review and update records promptly when corrections are needed.
Incorrect entries can affect summaries and interpretations.

9. Your Responsibilities
Do not disclose learner or account data to unauthorized parties.
Always verify exported files before sharing.

10. Policy Updates
This policy may be updated to reflect legal, policy, or system changes.
Continued use of the system signifies acceptance of the latest policy text displayed in the application.
''';
