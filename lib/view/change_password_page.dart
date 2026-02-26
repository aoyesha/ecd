import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';

class ChangePasswordPage extends StatefulWidget {
  final String role;
  final int userId;

  const ChangePasswordPage({
    Key? key,
    required this.role,
    required this.userId,
  }) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final newPassController = TextEditingController();
  final confirmController = TextEditingController();

  bool _busy = false;
  bool _loadingEmail = true;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    Map<String, dynamic>? row;

    if (widget.role == 'Teacher') {
      row = await DatabaseService.instance.getTeacherById(widget.userId);
    } else {
      row = await DatabaseService.instance.getAdminById(widget.userId);
    }

    emailController.text = row?['email'] ?? '';
    setState(() => _loadingEmail = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);

    try {
      await DatabaseService.instance.updatePassword(
        role: widget.role,
        email: emailController.text.trim(),
        newPassword: newPassController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Password updated.")));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Update failed: $e")));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // MOBILE HEADER
  Widget _mobileHeader() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            left: 64,
            right: 64,
            child: Center(
              child: Text(
                "Change Password",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 6,
            bottom: 6,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopHeader() {
    return Container(
      color: const Color(0xFFF7F4F6),
      padding: const EdgeInsets.fromLTRB(80, 14, 16, 10),
      child: const Row(
        children: [
          Text(
            "Change Password",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _form(bool isMobile) {
    final titleSize = isMobile ? 22.0 : 34.0;
    final fieldFont = isMobile ? 14.0 : 16.0;
    final width = isMobile ? 320.0 : 520.0;

    Widget label(String text) => Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: fieldFont)),
      ),
    );

    Widget viewField(String value) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3E3E3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(value, style: TextStyle(fontSize: fieldFont)),
    );

    Widget inputField(TextEditingController controller) => TextFormField(
      controller: controller,
      obscureText: true,
      validator: (v) {
        if (controller == newPassController && (v == null || v.length < 6)) {
          return "Min 6 characters";
        }
        if (controller == confirmController && v != newPassController.text) {
          return "Passwords do not match";
        }
        return null;
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: const Color(0xFFE3E3E3),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    return Center(
      child: SizedBox(
        width: width,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text("",
                  style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800)),
              const SizedBox(height: 30),

              label("Email"),
              viewField(emailController.text),
              const SizedBox(height: 20),

              label("Password"),
              inputField(newPassController),
              const SizedBox(height: 20),

              label("Confirm Password"),
              inputField(confirmController),
              const SizedBox(height: 28),

              SizedBox(
                width: isMobile ? 220 : 260,
                height: isMobile ? 44 : 48,
                child: ElevatedButton(
                  onPressed: _busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8F3531),
                  ),
                  child: Text(_busy ? "Saving..." : "Save Changes"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      drawer: isMobile
          ? Navbar(
        selectedIndex: 5,
        onItemSelected: (_) {},
        role: widget.role,
        userId: widget.userId,
      )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
                if (!isMobile)
                  Navbar(
                    selectedIndex: 5,
                    onItemSelected: (_) {},
                    role: widget.role,
                    userId: widget.userId,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (isMobile) _mobileHeader(),
                      if (!isMobile) _desktopHeader(),
                      Expanded(
                        child: _loadingEmail
                            ? const Center(child: CircularProgressIndicator())
                            : SingleChildScrollView(child: _form(isMobile)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 285,
              child: const NavbarBackButton(),
            ),
        ],
      ),
    );
  }
}