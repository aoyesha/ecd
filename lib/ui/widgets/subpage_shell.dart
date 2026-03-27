import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../core/nav_no_transition.dart';
import '../../core/responsive.dart';
import '../../services/auth_service.dart';
import '../pages/auth/login_page.dart';
import 'app_nav.dart';
import 'app_shell.dart';
import 'nav_ui_state.dart';
import 'page_directory_line.dart';

class SubpageShell extends StatefulWidget {
  final String title;
  final List<String> directorySegments;
  final Widget body;
  final int navIndex;
  final List<Widget>? actions;
  final bool showBackButton;

  const SubpageShell({
    super.key,
    required this.title,
    required this.directorySegments,
    required this.body,
    required this.navIndex,
    this.actions,
    this.showBackButton = true,
  });

  @override
  State<SubpageShell> createState() => _SubpageShellState();
}

class _SubpageShellState extends State<SubpageShell> {
  late bool navExpanded;

  @override
  void initState() {
    super.initState();
    navExpanded = NavUiState.expanded;
  }

  void _goToShellIndex(int index) {
    navReplaceNoTransition(context, AppShell(initialIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final session = auth.session;
    if (session == null) {
      return const LoginPage();
    }

    final topInset = MediaQuery.of(context).padding.top;
    final userFuture = auth.getUser(session.userId);
    final items = const [
      AppNavItem(icon: Icons.dashboard, label: 'Dashboard'),
      AppNavItem(icon: Icons.archive, label: 'My Archive'),
      AppNavItem(icon: Icons.insights, label: 'Historical Data Analysis'),
      AppNavItem(icon: Icons.settings, label: 'Account Settings'),
    ];

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
                    selectedIndex: widget.navIndex,
                    closeOnSelect: true,
                    onSelected: _goToShellIndex,
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
                    selectedIndex: widget.navIndex,
                    compact: !navExpanded,
                    onToggleCompact: () => setState(() {
                      navExpanded = !navExpanded;
                      NavUiState.setExpanded(navExpanded);
                    }),
                    onSelected: _goToShellIndex,
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
                      isDesktop(context) ? 16 : topInset + 16,
                      16,
                      10,
                    ),
                    child: Row(
                      children: [
                        if (!isDesktop(context))
                          Builder(
                            builder: (context) => IconButton(
                              onPressed: () => Scaffold.of(context).openDrawer(),
                              icon: const Icon(Icons.menu),
                            ),
                          ),
                        if (widget.showBackButton)
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: 'Back',
                          ),
                        Expanded(
                          child: Text(
                            widget.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                              height: 1.05,
                            ),
                          ),
                        ),
                        if (widget.actions != null) ...widget.actions!,
                      ],
                    ),
                  ),
                  PageDirectoryLine(
                    segments: widget.directorySegments,
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                  ),
                  Expanded(child: widget.body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
