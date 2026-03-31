import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'db/app_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only run window_manager code on desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      maximumSize: null,
      minimumSize: Size(800, 600),
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.maximize();
      await windowManager.focus();
    });

    // Initialize desktop SQLite DB
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Init database for all platforms (mobile will use default)
  await AppDb.instance.init();

  runApp(const EccdNewApp());
}