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

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final session = auth.session;
    if (session == null) return const LoginPage();

    final role = session.role;
    final userId = session.userId;

    final pages = role == UserRole.teacher
        ? [
            TeacherDashboardPage(teacherId: userId),
            const TeacherArchivePage(),
            const TeacherHistoricalPage(),
            const SettingsPage(),
          ]
        : const [
            AdminDashboardPage(),
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

    final body = pages[index];
    final userFuture = auth.getUser(userId);

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
                    selectedIndex: index,
                    onSelected: (i) => setState(() => index = i),
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
                return SizedBox(
                  width: 280,
                  child: AppNav(
                    items: items,
                    selectedIndex: index,
                    onSelected: (i) => setState(() => index = i),
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                                'Early Childhood Development Checklist',
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  height: 1.05,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
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
