import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'db/app_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop DB init
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await AppDb.instance.init();
  runApp(const EccdNewApp());
}
