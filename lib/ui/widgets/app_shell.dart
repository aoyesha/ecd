import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/responsive.dart';
import '../../services/auth_service.dart';
import '../pages/admin/admin_archive_page.dart';
import '../pages/admin/admin_dashboard_page.dart';
import '../pages/admin/admin_historical_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/common/settings_page.dart';
import '../pages/teacher/teacher_archive_page.dart';
import '../pages/teacher/teacher_dashboard_page.dart';
import '../pages/teacher/teacher_historical_page.dart';
import 'app_nav.dart';
import 'nav_ui_state.dart';
import 'page_directory_line.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int index;
  late bool navExpanded;
  List<String>? _overrideDirectorySegments;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    navExpanded = NavUiState.expanded;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final session = auth.session;
    if (session == null) {
      return const LoginPage();
    }

    final role = session.role;
    final userId = session.userId;

    final topInset = MediaQuery.of(context).padding.top; // ⭐ mobile fix

    final pages = role == UserRole.teacher
        ? [
            TeacherDashboardPage(
              teacherId: userId,
              onDirectoryChanged: (segments) {
                if (!mounted) return;
                setState(() => _overrideDirectorySegments = segments);
              },
            ),
            const TeacherArchivePage(),
            const TeacherHistoricalPage(),
            const SettingsPage(),
          ]
        : [
            AdminDashboardPage(
              onDirectoryChanged: (segments) {
                if (!mounted) return;
                setState(() => _overrideDirectorySegments = segments);
              },
            ),
            AdminArchivePage(),
            AdminHistoricalPage(),
            SettingsPage(),
          ];

    final items = const [
      AppNavItem(icon: Icons.dashboard, label: 'Dashboard'),
      AppNavItem(icon: Icons.archive, label: 'My Archive'),
      AppNavItem(icon: Icons.insights, label: 'Historical Data Analysis'),
      AppNavItem(icon: Icons.settings, label: 'Account Settings'),
    ];

    final safeIndex = index >= 0 && index < pages.length ? index : 0;
    final body = pages[safeIndex];
    final userFuture = auth.getUser(userId);
    final directorySegments = safeIndex == 0 && _overrideDirectorySegments != null
        ? _overrideDirectorySegments!
        : switch (safeIndex) {
      0 => const ['Dashboard'],
      1 => const ['Dashboard', 'My Archive'],
      2 => const ['Dashboard', 'Historical Data Analysis'],
      3 => const ['Dashboard', 'Account Settings'],
      _ => const ['Dashboard'],
    };

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      drawer: isDesktop(context)
          ? null
          : FutureBuilder<Map<String, Object?>?>(
              future: userFuture,
              builder: (context, snapshot) {
                final u = snapshot.data ?? const <String, Object?>{};
                return Drawer(
                  child: AppNav(
                    items: items,
                    selectedIndex: safeIndex,
                    closeOnSelect: true,
                    onSelected: (i) => setState(() {
                      index = i;
                      _overrideDirectorySegments = null;
                    }),
                    profileName: (u['name'] ?? 'User').toString(),
                    division: (u['division'] ?? 'MIMAROPA').toString(),
                  ),
                );
              },
            ),
      body: Row(
        children: [
          if (isDesktop(context))
            FutureBuilder<Map<String, Object?>?>(
              future: userFuture,
              builder: (context, snapshot) {
                final u = snapshot.data ?? const <String, Object?>{};
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: navExpanded ? 260 : 96,
                  child: AppNav(
                    items: items,
                    selectedIndex: safeIndex,
                    compact: !navExpanded,
                    onToggleCompact: () => setState(() {
                      navExpanded = !navExpanded;
                      NavUiState.setExpanded(navExpanded);
                    }),
                    onSelected: (i) => setState(() {
                      index = i;
                      _overrideDirectorySegments = null;
                    }),
                    profileName: (u['name'] ?? 'User').toString(),
                    division: (u['division'] ?? 'MIMAROPA').toString(),
                  ),
                );
              },
            ),
          Expanded(
            child: Container(
              color: AppColors.offWhite,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: AppColors.offWhite,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      isDesktop(context)
                          ? 16
                          : topInset + 16, // ⭐ mobile spacing fix
                      16,
                      12,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final titleSize = constraints.maxWidth < 600
                            ? 20.0
                            : 30.0;
                        return Row(
                          children: [
                            if (!isDesktop(context))
                              Builder(
                                builder: (context) => IconButton(
                                  onPressed: () =>
                                      Scaffold.of(context).openDrawer(),
                                  icon: const Icon(Icons.menu),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                'Early Childhood Development (ECD)',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  height: 1.05,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  PageDirectoryLine(
                    segments: directorySegments,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
