import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../view/landing_page.dart';
import '../view/archive_page.dart';
import '../view/historical_data_page.dart';
import '../view/settings_page.dart';
import '../view/login_page.dart';

class AppColors {
  static const Color maroon = Color(0xFF7A1E22);
  static const Color maroonDark = Color(0xFF61171A);
  static const Color maroonLight = Color(0xFF8E2A2F);
  static const Color bg = Color(0xFFF7F4F6);
  static const Color white = Colors.white;
}

class NavItem {
  final IconData icon;
  final String label;
  final Widget Function() builder;

  const NavItem({
    required this.icon,
    required this.label,
    required this.builder,
  });
}

class Navbar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final int userId;
  final String role;

  const Navbar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.userId,
    required this.role,
  }) : super(key: key);

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  String? divisionName;
  String? userName;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final db = DatabaseService.instance;
    Map<String, dynamic>? data;

    if (widget.role == 'Teacher') {
      data = await db.getTeacherById(widget.userId);
    } else {
      data = await db.getAdminById(widget.userId);
    }

    if (mounted && data != null) {
      setState(() {
        divisionName = data!['division'];
        userName = widget.role == 'Teacher'
            ? data['teacher_name']
            : data['admin_name'];
        isLoading = false;
      });
    }
  }

  String _getDivisionLogo(String? division) {
    switch (division) {
      case "Occidental Mindoro": return 'assets/occidental_min_logo.png';
      case "Oriental Mindoro": return 'assets/oriental_min_logo.gif';
      case "Calapan City": return 'assets/calapan_logo.jpeg';
      case "Marinduque": return 'assets/marinduque_logo.jpg';
      case "Romblon": return 'assets/romblon_logo.png';
      case "Palawan": return 'assets/palawan_logo.png';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <NavItem>[
      NavItem(
        icon: Icons.home,
        label: 'Dashboard',
        builder: () => LandingPage(userId: widget.userId, role: widget.role),
      ),
      NavItem(
        icon: Icons.archive,
        label: 'My Archive',
        builder: () => ArchivePage(userId: widget.userId, role: widget.role),
      ),
      NavItem(
        icon: Icons.analytics,
        label: 'Historical Data Analysis',
        builder: () => HistoricalDataPage(userId: widget.userId, role: widget.role),
      ),
      NavItem(
        icon: Icons.settings,
        label: 'Account Settings',
        builder: () => SettingsPage(userId: widget.userId, role: widget.role),
      ),
    ];

    final logoPath = _getDivisionLogo(divisionName);

    return Container(
      width: 280,
      color: AppColors.maroon,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: logoPath.isNotEmpty
                      ? Image.asset(logoPath, fit: BoxFit.contain)
                      : const Icon(Icons.account_balance, size: 40, color: AppColors.maroon),
                ),
              ),
            ),

            const SizedBox(height: 12),

            if (!isLoading) ...[
              Text(userName ?? "User",
                  style: const TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 26)),
              Text(divisionName ?? "MIMAROPA",
                  style: TextStyle(color: Colors.white.withOpacity(0.8),fontSize: 18)),
            ],

            const SizedBox(height: 20),
            const Divider(color: Colors.white24, indent: 20, endIndent: 20),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final isSelected = i == widget.selectedIndex;
                  return _NavTile(
                    icon: items[i].icon,
                    label: items[i].label,
                    selected: isSelected,
                    onTap: () {
                      widget.onItemSelected(i);
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => items[i].builder()),
                      );
                    },
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: Colors.black,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                    );
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.maroonDark : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
  }
}