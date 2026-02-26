import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'login_page.dart';

const Map<String, Map<String, List<String>>> regionHierarchy = {
  "MIMAROPA": {
    "Occidental Mindoro": [
      "Abra de Ilog", "Calintaan", "Looc", "Lubang", "Magsaysay",
      "Mamburao", "Paluan", "Rizal", "Sablayan", "San Jose", "Santa Cruz"
    ],
    "Oriental Mindoro": [
      "Baco", "Bansud", "Bongabong", "Bulalacao", "Gloria",
      "Mansalay", "Naujan", "Pinamalayan", "Pola", "Puerto Galera",
      "Roxas", "San Teodoro", "Socorro", "Victoria"
    ],
    "Calapan City": ["Calapan City North", "Calapan City South"],
    "Marinduque": [
      "Boac North", "Boac South", "Buenavista", "Gasan",
      "Mogpog", "Santa Cruz North", "Santa Cruz South", "Torrijos"
    ],
    "Romblon": [
      "Alcantara", "Banton", "Cajidiocan", "Calatrava", "Concepcion",
      "Corcuera", "Ferrol", "Looc", "Magdiwang", "Odiongan",
      "Romblon", "San Agustin", "San Andres", "San Fernando", "Santa Fe"
    ],
    "Palawan": [
      "Aborlan", "Agutaya", "Araceli", "Balabac", "Bataraza",
      "Brooke's Point", "Busuanga", "Cagayancillo", "Coron", "Culion",
      "Cuyo", "Dumaran", "El Nido", "Linapacan", "Magsaysay",
      "Narra", "Quezon", "Rizal", "Roxas", "San Vicente", "Sofronio Española", "Taytay"
    ],
    "Puerto Princesa City": ["Puerto Princesa North", "Puerto Princesa South"],
  },
};

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  final institutionController = TextEditingController();

  final recoveryAnswer1Controller = TextEditingController();
  final recoveryAnswer2Controller = TextEditingController();

  bool obscure = true;
  int currentStep = 1;

  String? selectedRole;
  String? selectedRegion;
  String? selectedDivision;
  String? selectedDistrict;

  final List<String> accountRole = ['Teacher', 'Admin'];

  @override
  void initState() {
    super.initState();

    selectedRegion = "MIMAROPA";
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    institutionController.dispose();
    recoveryAnswer1Controller.dispose();
    recoveryAnswer2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (selectedRegion != null && !regionHierarchy.containsKey(selectedRegion)) {
      selectedRegion = regionHierarchy.keys.first;
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return constraints.maxWidth > 700
                ? _desktopLayout()
                : _mobileLayout();
          },
        ),
      ),
    );
  }

  Widget _mobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 80),
          Image.asset('assets/kids.png', width: 220),
          const SizedBox(height: 24),
          _title(),
          const SizedBox(height: 20),
          _formHeader(),
          const SizedBox(height: 16),
          _form(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _desktopLayout() {
    return Center(
      child: SizedBox(
        width: 1100,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 50),
                    child: Image.asset(
                      'assets/kids.png',
                      width: 400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _title(),
                ],
              ),
            ),
            const SizedBox(width: 40),
            Expanded(
              flex: 4,
              child: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _formHeader(),
                      const SizedBox(height: 20),
                      _form(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title() {
    return const AutoSizeText(
      "Early Childhood\nDevelopment Checklist",
      textAlign: TextAlign.center,
      maxLines: 2,
      minFontSize: 28,
      style: TextStyle(
        fontSize: 50,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        height: 1.2,
      ),
    );
  }

  Widget _formHeader() {
    return const Center(
      child: Text(
        "Create an Account",
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required List<String> items,
    required String? value,
    ValueChanged<String?>? onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _passwordInput() {
    return TextFormField(
      controller: passwordController,
      obscureText: obscure,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: '••••••••',
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => obscure = !obscure),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (currentStep == 1) ...[
            _label('Account Role'),
            _dropdown(
              hint: 'Choose Role',
              items: accountRole,
              value: selectedRole,
              onChanged: (v) => setState(() => selectedRole = v),
            ),
            const SizedBox(height: 16),
            _label('Region'),
            _dropdown(
              hint: 'Select Region',
              items: regionHierarchy.keys.toList(),
              value: selectedRegion,
              onChanged: (v) {
                setState(() {
                  selectedRegion = v;
                  selectedDivision = null;
                  selectedDistrict = null;
                });
              },
            ),
            const SizedBox(height: 16),
            _label('Division'),
            _dropdown(
              hint: 'Select Division',
              items: selectedRegion == null
                  ? []
                  : regionHierarchy[selectedRegion!]!.keys.toList(),
              value: selectedDivision,
              onChanged: selectedRegion == null
                  ? null
                  : (v) {
                setState(() {
                  selectedDivision = v;
                  selectedDistrict = null;
                });
              },
            ),
            const SizedBox(height: 16),
            _label('District'),
            _dropdown(
              hint: 'Select District',
              items: (selectedRegion != null && selectedDivision != null)
                  ? regionHierarchy[selectedRegion!]![selectedDivision!]!
                  : [],
              value: selectedDistrict,
              onChanged: selectedDivision == null
                  ? null
                  : (v) => setState(() => selectedDistrict = v),
            ),
            const SizedBox(height: 16),
            _label('Institution / School Name'),
            _input(
              controller: institutionController,
              hint: 'e.g. San Isidro Child Development Center',
            ),
            const SizedBox(height: 24),
            _stepButton("Next", () {
              if (selectedRole == null ||
                  selectedRegion == null ||
                  selectedDivision == null ||
                  selectedDistrict == null ||
                  institutionController.text.trim().isEmpty) {
                _showSnackBar("Please complete all required fields");
                return;
              }
              setState(() => currentStep = 2);
            }),
          ],
          if (currentStep == 2) ...[
            _label('Your Name'),
            _input(controller: nameController, hint: 'Juan Dela Cruz'),
            const SizedBox(height: 18),
            _label('Your Email'),
            _input(controller: emailController, hint: 'juan.delacruz@deped.gov.ph'),
            const SizedBox(height: 18),
            _label('Set Password'),
            _passwordInput(),
            const SizedBox(height: 18),
            _label('Recovery Question 1'),
            _input(
              controller: recoveryAnswer1Controller,
              hint: 'What is your nickname?',
            ),
            const SizedBox(height: 18),
            _label('Recovery Question 2'),
            _input(
              controller: recoveryAnswer2Controller,
              hint: 'What city were you born in?',
            ),
            const SizedBox(height: 24),
            _stepButton("Create Account", () {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final password = passwordController.text.trim();
              final recovery1 = recoveryAnswer1Controller.text.trim();
              final recovery2 = recoveryAnswer2Controller.text.trim();
              final passwordErrors = [];

              if (name.isEmpty ||
                  email.isEmpty ||
                  password.isEmpty ||
                  recovery1.isEmpty ||
                  recovery2.isEmpty) {
                _showSnackBar("Please complete all required fields");
                return;
              }

              if (!email.endsWith("@deped.gov.ph")) {
                passwordErrors.add("Email must end with \"@deped.gov.ph\"");
              }

              if (password.length < 8) {
                passwordErrors.add("Password must be at least 8 characters");
              }

              if (!RegExp(r'[A-Z]').hasMatch(password)) {
                passwordErrors.add("Password must contain at least 1 uppercase letter");
              }

              if (!RegExp(r'[0-9]').hasMatch(password)) {
                passwordErrors.add("Password must contain at least 1 numerical digit");
              }

              if (!RegExp(r'[!@#\$%\^&\*\(\)_]').hasMatch(password)) {
                passwordErrors.add("Password must contain at least 1 special symbol (!, @, #, \$, %, ^, &, *, _,)");
              }

              if(passwordErrors.isNotEmpty){
                final String bulletList = passwordErrors
                    .map((msg) => '• $msg')
                    .join('\n');

                _showSnackBar(bulletList);
                return;
              }

              _handleCreateAccount();
            }),
            const SizedBox(height: 12),
            _stepButton("Back", () => setState(() => currentStep = 1)),
          ],
          const SizedBox(height: 24),
          Center(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.white.withOpacity(0.9)),
                children: [
                  const TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Log in',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginPage()),
                        );
                      },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _handleCreateAccount() async {
    final db = DatabaseService.instance;

    try {
      if (selectedRole == "Teacher") {
        await db.createTeacher({
          "teacher_name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "password": passwordController.text.trim(),
          "school": institutionController.text.trim(),
          "district": selectedDistrict,
          "division": selectedDivision,
          "region": selectedRegion,

          "recovery_q1": "What is your nickname?",
          "recovery_a1": recoveryAnswer1Controller.text.trim(),
          "recovery_q2": "What city were you born in?",
          "recovery_a2": recoveryAnswer2Controller.text.trim(),

          "status": "active",
        });
      } else {
        await db.createAdmin({
          "admin_name": nameController.text.trim(),
          "email": emailController.text.trim(),
          "password": passwordController.text.trim(),
          "school": institutionController.text.trim(),
          "district": selectedDistrict,
          "division": selectedDivision,
          "region": selectedRegion,

          "recovery_q1": "What is your nickname?",
          "recovery_a1": recoveryAnswer1Controller.text.trim(),
          "recovery_q2": "What city were you born in?",
          "recovery_a2": recoveryAnswer2Controller.text.trim(),

          "status": "active",
        });
      }

      _showSnackBar("Account created successfully", isError: false);

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      _showSnackBar("Registration failed: $e");
      debugPrint("REGISTER ERROR: $e");
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    final snackBar = SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: isError ? Colors.black : Colors.green[700],
      content: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
            child: const Icon(
              Icons.close,
              color: Colors.white,
            ),
          ),
        ],
      ),
      duration: const Duration(seconds: 5),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }
}