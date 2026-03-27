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
            title: 'Early Childhood Development (ECD)',
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
              scaffoldBackgroundColor: const Color(0xFFFBF8F6),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.maroon,
                foregroundColor: Colors.white,
                elevation: 0,
                centerTitle: false,
                titleTextStyle: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              snackBarTheme: SnackBarThemeData(
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: Color(0xFFE5D6D7)),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFEEE4E4)),
                ),
                titleTextStyle: const TextStyle(
                  color: Color(0xFF241617),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                contentTextStyle: const TextStyle(
                  color: Color(0xFF5A4A4B),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFEDE3E3)),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                labelStyle: const TextStyle(
                  color: Color(0xFF6E5B5C),
                  fontWeight: FontWeight.w600,
                ),
                hintStyle: const TextStyle(color: Color(0xFF9A8A8B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE8DCDD)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE8DCDD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.maroon,
                    width: 1.4,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFB33A3E)),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFB33A3E)),
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.maroon,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.maroon,
                  side: const BorderSide(color: Color(0xFFD8B8BA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              segmentedButtonTheme: SegmentedButtonThemeData(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  side: WidgetStateProperty.all(
                    const BorderSide(color: Color(0xFFD8B8BA)),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFFF7D6D3);
                    }
                    return Colors.white;
                  }),
                  foregroundColor: WidgetStateProperty.all(
                    const Color(0xFF2A2021),
                  ),
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              dividerTheme: const DividerThemeData(
                color: Color(0xFFEADFE0),
                thickness: 1,
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
