import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../db/app_db.dart';
import '../db/schema.dart';
import 'email_otp_service.dart';

class Session {
  final int userId;
  final UserRole role;

  Session({required this.userId, required this.role});
}

enum AuthLoginStatus {
  success,
  invalidCredentials,
  lockedOut,
  requiresMonthlyOtp,
}

class AuthLoginResult {
  final AuthLoginStatus status;
  final int? userId;
  final UserRole? role;
  final String? email;
  final EmailOtpChallenge? challenge;
  final DateTime? lockUntil;

  const AuthLoginResult._({
    required this.status,
    this.userId,
    this.role,
    this.email,
    this.challenge,
    this.lockUntil,
  });

  const AuthLoginResult.success({
    required int userId,
    required UserRole role,
    required String email,
  }) : this._(
         status: AuthLoginStatus.success,
         userId: userId,
         role: role,
         email: email,
       );

  const AuthLoginResult.invalidCredentials()
    : this._(status: AuthLoginStatus.invalidCredentials);

  const AuthLoginResult.lockedOut(DateTime? lockUntil)
    : this._(status: AuthLoginStatus.lockedOut, lockUntil: lockUntil);

  const AuthLoginResult.requiresMonthlyOtp({
    required int userId,
    required UserRole role,
    required String email,
    required EmailOtpChallenge challenge,
  }) : this._(
         status: AuthLoginStatus.requiresMonthlyOtp,
         userId: userId,
         role: role,
         email: email,
         challenge: challenge,
       );
}

class AuthService extends ChangeNotifier {
  Session? _session;
  Session? get session => _session;

  final EmailOtpService _emailOtpService = const EmailOtpService();

  int _failedAttempts = 0;
  DateTime? _lockUntil;

  String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  Future<AuthLoginResult> login({
    required UserRole role,
    required String email,
    required String password,
  }) async {
    if (_lockUntil != null && DateTime.now().isBefore(_lockUntil!)) {
      return AuthLoginResult.lockedOut(_lockUntil);
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
      return const AuthLoginResult.invalidCredentials();
    }

    final row = rows.first;
    final storedHash = (row[DbSchema.cUserPasswordHash] ?? '').toString();
    final passwordMatches = BCrypt.checkpw(password.trim(), storedHash);

    if (!passwordMatches) {
      _registerFailedAttempt();
      return const AuthLoginResult.invalidCredentials();
    }

    _failedAttempts = 0;
    _lockUntil = null;

    final userId = row[DbSchema.cUserId] as int;

    if (_requiresMonthlyOtp(role, row)) {
      final challenge = await _emailOtpService.createAndSendOtp(
        email: normalizedEmail,
        purpose: EmailOtpPurpose.monthlyLoginVerification,
      );
      return AuthLoginResult.requiresMonthlyOtp(
        userId: userId,
        role: role,
        email: normalizedEmail,
        challenge: challenge,
      );
    }

    await completeLogin(userId: userId, role: role);
    return AuthLoginResult.success(
      userId: userId,
      role: role,
      email: normalizedEmail,
    );
  }

  Future<void> completeLogin({
    required int userId,
    required UserRole role,
    bool markMonthlyVerified = false,
  }) async {
    if (markMonthlyVerified) {
      final db = AppDb.instance.db;
      await db.update(
        DbSchema.tUsers,
        {DbSchema.cUserLastMonthlyOtpAt: DateTime.now().toIso8601String()},
        where: '${DbSchema.cUserId} = ?',
        whereArgs: [userId],
      );
    }

    _session = Session(userId: userId, role: role);
    notifyListeners();
  }

  void _registerFailedAttempt() {
    _failedAttempts++;

    if (_failedAttempts >= 5) {
      _lockUntil = DateTime.now().add(const Duration(minutes: 5));
      _failedAttempts = 0;
    }
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
    final normalizedEmail = email.trim().toLowerCase();
    final nowIso = DateTime.now().toIso8601String();

    final existing = await db.query(
      DbSchema.tUsers,
      columns: [DbSchema.cUserId],
      where: 'LOWER(${DbSchema.cUserEmail}) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw StateError('Email already exists.');
    }

    return db.insert(DbSchema.tUsers, {
      DbSchema.cUserRole: role.name,
      DbSchema.cUserEmail: normalizedEmail,
      DbSchema.cUserPasswordHash: _hashPassword(password.trim()),
      DbSchema.cUserName: name.trim(),
      DbSchema.cUserSchool: school?.trim(),
      DbSchema.cUserDistrict: district?.trim(),
      DbSchema.cUserDivision: division?.trim(),
      DbSchema.cUserRegion: region?.trim(),
      DbSchema.cUserAcceptedTos: acceptedTos ? 1 : 0,
      DbSchema.cUserAcceptedPrivacy: acceptedPrivacy ? 1 : 0,
      DbSchema.cUserCreatedAt: nowIso,
      DbSchema.cUserLastMonthlyOtpAt: nowIso,
    });
  }

  Future<void> ensureEmailAvailable(
    String email, {
    int? excludingUserId,
  }) async {
    final db = AppDb.instance.db;
    final normalizedEmail = email.trim().toLowerCase();
    final whereBuffer = StringBuffer('LOWER(${DbSchema.cUserEmail}) = ?');
    final whereArgs = <Object>[normalizedEmail];

    if (excludingUserId != null) {
      whereBuffer.write(' AND ${DbSchema.cUserId} != ?');
      whereArgs.add(excludingUserId);
    }

    final existing = await db.query(
      DbSchema.tUsers,
      columns: [DbSchema.cUserId],
      where: whereBuffer.toString(),
      whereArgs: whereArgs,
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw StateError('Email already exists.');
    }
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

    final storedHash = (rows.first[DbSchema.cUserPasswordHash] ?? '')
        .toString();

    if (!BCrypt.checkpw(currentPassword.trim(), storedHash)) {
      throw StateError('Current password is incorrect.');
    }

    await db.update(
      DbSchema.tUsers,
      {DbSchema.cUserPasswordHash: _hashPassword(newPassword.trim())},
      where: '${DbSchema.cUserId} = ?',
      whereArgs: [userId],
    );
  }

  Future<void> resetPasswordByEmail({
    required UserRole role,
    required String email,
    required String newPassword,
  }) async {
    final user = await getUserByEmail(role: role, email: email);
    if (user == null) {
      throw StateError('Account not found.');
    }

    final db = AppDb.instance.db;
    await db.update(
      DbSchema.tUsers,
      {DbSchema.cUserPasswordHash: _hashPassword(newPassword.trim())},
      where: '${DbSchema.cUserId} = ?',
      whereArgs: [user[DbSchema.cUserId]],
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

  Future<Map<String, Object?>?> getUserByEmail({
    required UserRole role,
    required String email,
  }) async {
    final db = AppDb.instance.db;
    final normalizedEmail = email.trim().toLowerCase();

    final rows = await db.query(
      DbSchema.tUsers,
      where:
          'LOWER(${DbSchema.cUserEmail}) = ? AND LOWER(${DbSchema.cUserRole}) = ?',
      whereArgs: [normalizedEmail, role.name.toLowerCase()],
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
    final normalizedEmail = email.trim().toLowerCase();

    final existing = await db.query(
      DbSchema.tUsers,
      where: 'LOWER(${DbSchema.cUserEmail}) = ? AND ${DbSchema.cUserId} != ?',
      whereArgs: [normalizedEmail, userId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw StateError('Email already exists.');
    }

    await db.update(
      DbSchema.tUsers,
      {
        DbSchema.cUserName: name.trim(),
        DbSchema.cUserEmail: normalizedEmail,
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

  bool _requiresMonthlyOtp(UserRole role, Map<String, Object?> row) {
    if (role != UserRole.teacher) {
      return false;
    }

    final lastVerifiedRaw = (row[DbSchema.cUserLastMonthlyOtpAt] ?? '')
        .toString()
        .trim();
    if (lastVerifiedRaw.isEmpty) {
      return true;
    }

    final lastVerified = DateTime.tryParse(lastVerifiedRaw);
    if (lastVerified == null) {
      return true;
    }

    final now = DateTime.now();
    return lastVerified.year != now.year || lastVerified.month != now.month;
  }
}
