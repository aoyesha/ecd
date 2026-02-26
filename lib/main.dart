import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'services/database_service.dart';
import 'view/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await DatabaseService.instance.getDatabase();

  runApp(const ECCDApp());
}

// This is the "Softest" transition logic: A Pure Fade with a Sine Curve
class SoftFadeTransition extends CustomTransition {
  @override
  Widget buildTransition(
      BuildContext context,
      Curve? curve,
      Alignment? alignment,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
      ) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        // Curves.easeInOutSine is the smoothest mathematical fade
        curve: Curves.easeInOutSine,
      ),
      child: child,
    );
  }
}

class ECCDApp extends StatelessWidget {
  const ECCDApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ECCD Checklist',

      // --- THE FIX ---
      // We use our custom class to force a soft "melt" effect
      customTransition: SoftFadeTransition(),

      // 600ms-800ms is the sweet spot for "Soft"
      transitionDuration: const Duration(milliseconds: 600),
      // ----------------

      theme: ThemeData(
        // Keeping background consistent prevents "flickering" during the fade
        scaffoldBackgroundColor: Colors.white,
        textTheme: GoogleFonts.workSansTextTheme(),

        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      home: const LoginPage(),
    );
  }
}