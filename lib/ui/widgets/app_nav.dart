import 'package:flutter/material.dart';
import '../../core/constants.dart';

class AppNavItem {
  final IconData icon;
  final String label;
  const AppNavItem({required this.icon, required this.label});
}

class AppNav extends StatelessWidget {
  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String profileName;
  final String division;
  const AppNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.profileName,
    required this.division,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.maroon,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.offWhite,
                      backgroundImage: AssetImage(_logoForDivision(division)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            division,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                children: [
                  for (int i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _navTile(
                        items[i],
                        i == selectedIndex,
                        () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navTile(AppNavItem item, bool selected, VoidCallback onTap) {
    return Material(
      color: selected ? AppColors.maroonDark : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(item.icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _logoForDivision(String division) {
    final d = division.toLowerCase();
    if (d.contains('oriental')) return 'assets/oriental_min_logo.gif';
    if (d.contains('occidental')) return 'assets/occidental_min_logo.png';
    if (d.contains('marinduque')) return 'assets/marinduque_logo.jpg';
    if (d.contains('romblon')) return 'assets/romblon_logo.jpg';
    if (d.contains('palawan')) return 'assets/palawan_logo.png';
    if (d.contains('calapan')) return 'assets/calapan_logo.jpeg';
    if (d.contains('mimaropa')) return 'assets/mimaropa_logo.png';
    return 'assets/div_logo.jpg';
  }
}
