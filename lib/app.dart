import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants.dart';
import 'core/nav_no_transition.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'ui/pages/auth/login_page.dart';
import 'ui/widgets/app_shell.dart';

class EccdNewApp extends StatelessWidget {
  const EccdNewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: Consumer2<SettingsService, AuthService>(
        builder: (context, settings, auth, _) {
          return MaterialApp(
            title: 'ECCD Checklist',
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: TextScaler.linear(settings.fontScale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.maroon),
              scaffoldBackgroundColor: Colors.white,
              useMaterial3: true,
              cardTheme: const CardThemeData(
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
              textTheme: Theme.of(
                context,
              ).textTheme.apply(fontSizeFactor: settings.fontScale),
              pageTransitionsTheme: PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: const NoTransitionsBuilder(),
                  TargetPlatform.iOS: const NoTransitionsBuilder(),
                  TargetPlatform.macOS: const NoTransitionsBuilder(),
                  TargetPlatform.windows: const NoTransitionsBuilder(),
                  TargetPlatform.linux: const NoTransitionsBuilder(),
                },
              ),
            ),
            home: auth.session == null ? const LoginPage() : const AppShell(),
          );
        },
      ),
    );
  }
}
