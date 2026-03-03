import 'package:flutter/foundation.dart';
import 'package:bcrypt/bcrypt.dart';

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

  // ---------------------------
  // Rate limiting (basic)
  // ---------------------------
  int _failedAttempts = 0;
  DateTime? _lockUntil;

  // ---------------------------
  // Password hashing (bcrypt)
  // ---------------------------
  String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  // ---------------------------
  // LOGIN
  // ---------------------------
  Future<int?> login({
    required UserRole role,
    required String email,
    required String password,
  }) async {
    // Account temporarily locked
    if (_lockUntil != null &&
        DateTime.now().isBefore(_lockUntil!)) {
      return null;
    }

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

    if (rows.isEmpty) {
      _registerFailedAttempt();
      return null;
    }

    final row = rows.first;
    final storedHash =
    (row[DbSchema.cUserPasswordHash] ?? '').toString();

    final passwordMatches =
    BCrypt.checkpw(password.trim(), storedHash);

    if (!passwordMatches) {
      _registerFailedAttempt();
      return null;
    }

    // Success → reset lock
    _failedAttempts = 0;
    _lockUntil = null;

    _session = Session(
      userId: row[DbSchema.cUserId] as int,
      role: role,
    );

    notifyListeners();
    return _session!.userId;
  }

  void _registerFailedAttempt() {
    _failedAttempts++;

    if (_failedAttempts >= 5) {
      _lockUntil =
          DateTime.now().add(const Duration(minutes: 5));
      _failedAttempts = 0;
    }
  }

  // ---------------------------
  // REGISTER
  // ---------------------------
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
      DbSchema.cUserPasswordHash:
      _hashPassword(password.trim()),
      DbSchema.cUserName: name.trim(),
      DbSchema.cUserSchool: school?.trim(),
      DbSchema.cUserDistrict: district?.trim(),
      DbSchema.cUserDivision: division?.trim(),
      DbSchema.cUserRegion: region?.trim(),
      DbSchema.cUserAcceptedTos: acceptedTos ? 1 : 0,
      DbSchema.cUserAcceptedPrivacy: acceptedPrivacy ? 1 : 0,
      DbSchema.cUserCreatedAt:
      DateTime.now().toIso8601String(),
    });

    return id;
  }

  // ---------------------------
  // CHANGE PASSWORD
  // ---------------------------
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

    final storedHash =
    (rows.first[DbSchema.cUserPasswordHash] ?? '')
        .toString();

    if (!BCrypt.checkpw(
        currentPassword.trim(), storedHash)) {
      throw StateError(
          'Current password is incorrect.');
    }

    await db.update(
      DbSchema.tUsers,
      {
        DbSchema.cUserPasswordHash:
        _hashPassword(newPassword.trim()),
      },
      where: '${DbSchema.cUserId} = ?',
      whereArgs: [userId],
    );
  }

  // ---------------------------
  // GET USER
  // ---------------------------
  Future<Map<String, Object?>?> getUser(
      int userId) async {
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

  // ---------------------------
  // UPDATE PROFILE
  // ---------------------------
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
        DbSchema.cUserEmail:
        email.trim().toLowerCase(),
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

  // ---------------------------
  // LOGOUT
  // ---------------------------
  void logout() {
    _session = null;
    notifyListeners();
  }
}