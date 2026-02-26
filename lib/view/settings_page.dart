import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';
import 'change_password_page.dart';

class AppColors {
  static const Color bg = Color(0xFFF7F4F6);
}

class SettingsPage extends StatefulWidget {
  final int userId;
  final String role;

  const SettingsPage({
    Key? key,
    required this.userId,
    required this.role,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  double _fontScale = 1.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    Map<String, dynamic>? row;
    if (widget.role == 'Teacher') {
      row = await DatabaseService.instance.getTeacherById(widget.userId);
    } else {
      row = await DatabaseService.instance.getAdminById(widget.userId);
    }
    if (!mounted) return;
    setState(() {
      _user = row;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: isMobile
          ? Navbar(
        selectedIndex: 3,
        onItemSelected: (_) {},
        userId: widget.userId,
        role: widget.role,
      )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
                if (!isMobile)
                  Navbar(
                    selectedIndex: 3,
                    onItemSelected: (_) {},
                    userId: widget.userId,
                    role: widget.role,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (isMobile) _mobileHeader(),
                      if (!isMobile) _desktopHeader(),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _content(isMobile),
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
                "Account Settings",
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
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: const Column(
        children: [
          Text("Account Settings",
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
          SizedBox(height: 14),
        ],
      ),
    );
  }


  Widget _content(bool isMobile) {
    final u = _user ?? {};
    final name = (widget.role == 'Teacher')
        ? (u['teacher_name'] ?? '—')
        : (u['admin_name'] ?? '—');

    final scale = _fontScale;
    final titleStyle =
    TextStyle(fontSize: (isMobile ? 16 : 20) * scale, fontWeight: FontWeight.w800);
    final textStyle =
    TextStyle(fontSize: (isMobile ? 13 : 16) * scale, color: Colors.black87);
    final tileStyle =
    TextStyle(fontSize: (isMobile ? 14 : 17) * scale, fontWeight: FontWeight.w600);

    return Padding(
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      child: ListView(
        children: [
          // PROFILE
          Card(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile', style: titleStyle),
                  const SizedBox(height: 12),
                  _kv('Role', widget.role, textStyle),
                  _kv('Name', '$name', textStyle),
                  _kv('Email', '${u['email'] ?? '—'}', textStyle),
                  _kv('School', '${u['school'] ?? '—'}', textStyle),
                  _kv('District', '${u['district'] ?? '—'}', textStyle),
                  _kv('Division', '${u['division'] ?? '—'}', textStyle),
                  _kv('Region', '${u['region'] ?? '—'}', textStyle),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),


          Card(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Accessibility', style: titleStyle),
                  const SizedBox(height: 14),
                  Text("Font Size", style: textStyle),
                  Slider(
                    value: _fontScale,
                    min: 0.8,
                    max: 1.4,
                    divisions: 3,
                    label: _fontScale.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _fontScale = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ACTIONS (FULLY RESTORED)
          Card(
            child: Column(
              children: [
                _tile(Icons.lock, 'Change Password', tileStyle, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChangePasswordPage(userId: widget.userId, role: widget.role),
                    ),
                  );
                }),
                const Divider(height: 1),
                _tile(Icons.privacy_tip, 'Privacy Policy', tileStyle,
                        () => _showDialog('Privacy Policy', 'Add your privacy policy text here.')),
                const Divider(height: 1),
                _tile(Icons.description, 'Terms & Conditions', tileStyle,
                        () => _showDialog('Terms & Conditions', 'Add your terms text here.')),
                const Divider(height: 1),
                _tile(Icons.help_outline, 'FAQ', tileStyle,
                        () => _showDialog('FAQ', 'Add your FAQ here.')),
                const Divider(height: 1),
                _tile(Icons.contact_mail, 'Contact Us', tileStyle,
                        () => _showDialog('Contact Us', 'Email: example@deped.gov.ph\nPhone: (000) 000-0000')),
                const Divider(height: 1),
                _tile(Icons.groups, 'Developers', tileStyle,
                        () => _showDialog('Developers', '• Vincent Yuri Jose\n• (Add other devs)')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, TextStyle style, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 22),
      title: Text(title, style: style),
      onTap: onTap,
    );
  }

  Widget _kv(String k, String v, TextStyle style) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(k, style: style)),
          Expanded(child: Text(v, style: style)),
        ],
      ),
    );
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }
}