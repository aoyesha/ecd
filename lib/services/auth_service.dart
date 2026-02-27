import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

import '../core/constants.dart';
import '../db/app_db.dart';
import '../db/schema.dart';

class Session {
  final int userId;
  final UserRole role;

  Session({required this.userId, required this.role});
}

class AuthService extends ChangeNotifier {
  Session? _session;
  Session? get session => _session;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<int?> login({
    required UserRole role,
    required String email,
    required String password,
  }) async {
    final db = AppDb.instance.db;
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedRole = role.name.toLowerCase();

    final rows = await db.query(
      DbSchema.tUsers,
      where:
          'LOWER(${DbSchema.cUserEmail}) = ? AND LOWER(${DbSchema.cUserRole}) = ?',
      whereArgs: [normalizedEmail, normalizedRole],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final stored = (row[DbSchema.cUserPasswordHash] ?? '').toString();
    final trimmedPassword = password.trim();
    final hash = _hashPassword(password.trim());

    // Backward compatibility:
    // - standard: stored hash
    // - legacy: plaintext password still in DB (migrate on successful login)
    if (stored != hash && stored != trimmedPassword) return null;

    if (stored == trimmedPassword) {
      await db.update(
        DbSchema.tUsers,
        {DbSchema.cUserPasswordHash: hash},
        where: '${DbSchema.cUserId} = ?',
        whereArgs: [row[DbSchema.cUserId]],
      );
    }

    _session = Session(userId: row[DbSchema.cUserId] as int, role: role);
    notifyListeners();
    return _session!.userId;
  }

  Future<int> register({
    required UserRole role,
    required String email,
    required String password,
    required String name,
    String? school,
    String? district,
    String? division,
    String? region,
    required bool acceptedTos,
    required bool acceptedPrivacy,
  }) async {
    final db = AppDb.instance.db;
    final id = await db.insert(DbSchema.tUsers, {
      DbSchema.cUserRole: role.name,
      DbSchema.cUserEmail: email.trim().toLowerCase(),
      DbSchema.cUserPasswordHash: _hashPassword(password.trim()),
      DbSchema.cUserName: name.trim(),
      DbSchema.cUserSchool: school?.trim(),
      DbSchema.cUserDistrict: district?.trim(),
      DbSchema.cUserDivision: division?.trim(),
      DbSchema.cUserRegion: region?.trim(),
      DbSchema.cUserAcceptedTos: acceptedTos ? 1 : 0,
      DbSchema.cUserAcceptedPrivacy: acceptedPrivacy ? 1 : 0,
      DbSchema.cUserCreatedAt: DateTime.now().toIso8601String(),
    });
    return id;
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      DbSchema.tUsers,
      columns: [DbSchema.cUserPasswordHash],
      where: '${DbSchema.cUserId} = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('User not found.');
    }

    final stored = (rows.first[DbSchema.cUserPasswordHash] ?? '').toString();
    final currentTrimmed = currentPassword.trim();
    final currentHash = _hashPassword(currentTrimmed);
    final currentMatches = stored == currentHash || stored == currentTrimmed;
    if (!currentMatches) {
      throw StateError('Current password is incorrect.');
    }

    await db.update(
      DbSchema.tUsers,
      {DbSchema.cUserPasswordHash: _hashPassword(newPassword.trim())},
      where: '${DbSchema.cUserId} = ?',
      whereArgs: [userId],
    );
  }

  Future<Map<String, Object?>?> getUser(int userId) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      DbSchema.tUsers,
      where: '${DbSchema.cUserId}=?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> updateProfile({
    required int userId,
    required String name,
    required String email,
    String? school,
    String? district,
    String? division,
    String? region,
  }) async {
    final db = AppDb.instance.db;
    await db.update(
      DbSchema.tUsers,
      {
        DbSchema.cUserName: name.trim(),
        DbSchema.cUserEmail: email.trim().toLowerCase(),
        DbSchema.cUserSchool: school?.trim(),
        DbSchema.cUserDistrict: district?.trim(),
        DbSchema.cUserDivision: division?.trim(),
        DbSchema.cUserRegion: region?.trim(),
      },
      where: '${DbSchema.cUserId} = ?',
      whereArgs: [userId],
    );
    notifyListeners();
  }

  void logout() {
    _session = null;
    notifyListeners();
  }
}
