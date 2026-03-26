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
  final bool compact;
  final bool closeOnSelect;
  final VoidCallback? onToggleCompact;

  const AppNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.profileName,
    required this.division,
    this.compact = false,
    this.closeOnSelect = false,
    this.onToggleCompact,
  });

  @override
  Widget build(BuildContext context) {
    final logoAsset = _logoForDivision(division);

    return Container(
      color: AppColors.maroon,
      child: SafeArea(
        child: Column(
          children: [
            if (onToggleCompact != null)
              Align(
                alignment: compact ? Alignment.center : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 10 : 12,
                    12,
                    compact ? 10 : 12,
                    0,
                  ),
                  child: IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      foregroundColor: Colors.white,
                    ),
                    tooltip: compact ? 'Expand sidebar' : 'Collapse sidebar',
                    onPressed: onToggleCompact,
                    icon: Icon(
                      compact
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 10 : 14,
                onToggleCompact == null ? 14 : 10,
                compact ? 10 : 14,
                compact ? 8 : 10,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(compact ? 24 : 18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(compact ? 12 : 10),
                child: compact
                    ? Tooltip(
                        message: '$profileName\n$division',
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.offWhite,
                          backgroundImage: AssetImage(logoAsset),
                        ),
                      )
                    : Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.offWhite,
                            backgroundImage: AssetImage(logoAsset),
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
                                    fontSize: 17,
                                  ),
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
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 6 : 10,
                ),
                children: [
                  for (int i = 0; i < items.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: compact ? 10 : 8),
                      child: _navTile(
                        context,
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

  Widget _navTile(
    BuildContext context,
    AppNavItem item,
    bool selected,
    VoidCallback onTap,
  ) {
    final tile = Material(
      color: selected ? AppColors.maroonDark : Colors.transparent,
      borderRadius: BorderRadius.circular(compact ? 20 : 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(compact ? 20 : 16),
        onTap: () {
          if (closeOnSelect) {
            Navigator.of(context).pop();
            Future.delayed(const Duration(milliseconds: 180), onTap);
            return;
          }

          onTap();
        },
        child: Padding(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 0, vertical: 16)
              : const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: compact
              ? Center(child: Icon(item.icon, color: Colors.white, size: 24))
              : Row(
                  children: [
                    Icon(item.icon, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    if (compact) {
      return Tooltip(message: item.label, child: tile);
    }

    return tile;
  }

  String _logoForDivision(String division) {
    final d = division.toLowerCase();
    if (d.contains('oriental')) return 'assets/oriental_min_logo.gif';
    if (d.contains('occidental')) return 'assets/occidental_min_logo.png';
    if (d.contains('marinduque')) return 'assets/marinduque_logo.jpg';
    if (d.contains('romblon')) return 'assets/romblon_logo.jpg';
    if (d.contains('palawan')) return 'assets/palawan_logo.png';
    if (d.contains('calapan')) return 'assets/calapan_logo.jpeg';
    if (d.contains('puerto')) return 'assets/puerto_prinsesa.jpg';
    if (d.contains('mimaropa')) return 'assets/mimaropa_logo.png';
    return 'assets/puerto_prinsesa.jpg';
  }
}
