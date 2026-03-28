import 'package:sqflite/sqflite.dart';

import '../db/app_db.dart';
import '../db/schema.dart';

class LearnerService {
  Future<Map<String, Object?>> _filterExistingLearnerColumns(
    Map<String, Object?> values,
  ) async {
    final db = AppDb.instance.db;
    final cols = await db.rawQuery('PRAGMA table_info(${DbSchema.tLearners})');
    final existing = cols
        .map((c) => (c['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toSet();
    final out = <String, Object?>{};
    values.forEach((k, v) {
      if (existing.contains(k)) out[k] = v;
    });
    return out;
  }

  Future<int> addLearner({
    required int classId,
    required String firstName,
    required String lastName,
    required String gender, // 'M'|'F'
    required int age,
    String? middleName,
    String? lrn,
    String? birthDate,
    String? birthOrder,
    String? numberOfSiblings,
    String? province,
    String? city,
    String? barangay,
    String? parentName,
    String? parentOccupation,
    String? parentEducation,
    String? guardianName,
    String? guardianOccupation,
    String? guardianEducation,
    String? motherName,
    String? motherOccupation,
    String? motherEducation,
    String? fatherName,
    String? fatherOccupation,
    String? fatherEducation,
    String? dominantHand,
    String? ageMotherAtBirth,
    String? spouseOccupation,
  }) async {
    final db = AppDb.instance.db;
    final values = {
      DbSchema.cLearnerClassId: classId,
      DbSchema.cLearnerFirstName: firstName.trim(),
      DbSchema.cLearnerLastName: lastName.trim(),
      DbSchema.cLearnerGender: gender.trim().toUpperCase(),
      DbSchema.cLearnerAge: age,
      DbSchema.cLearnerMiddleName: middleName?.trim(),
      DbSchema.cLearnerLrn: lrn?.trim(),
      DbSchema.cLearnerBirthDate: birthDate?.trim(),
      DbSchema.cLearnerBirthOrder: birthOrder?.trim(),
      DbSchema.cLearnerNumSiblings: numberOfSiblings?.trim(),
      DbSchema.cLearnerProvince: province?.trim(),
      DbSchema.cLearnerCity: city?.trim(),
      DbSchema.cLearnerBarangay: barangay?.trim(),
      DbSchema.cLearnerParentName: parentName?.trim(),
      DbSchema.cLearnerParentOccupation: parentOccupation?.trim(),
      DbSchema.cLearnerParentEducation: parentEducation?.trim(),
      DbSchema.cLearnerGuardianName: guardianName?.trim(),
      DbSchema.cLearnerGuardianOccupation: guardianOccupation?.trim(),
      DbSchema.cLearnerGuardianEducation: guardianEducation?.trim(),
      DbSchema.cLearnerMotherName: motherName?.trim(),
      DbSchema.cLearnerMotherOccupation: motherOccupation?.trim(),
      DbSchema.cLearnerMotherEducation: motherEducation?.trim(),
      DbSchema.cLearnerFatherName: fatherName?.trim(),
      DbSchema.cLearnerFatherOccupation: fatherOccupation?.trim(),
      DbSchema.cLearnerFatherEducation: fatherEducation?.trim(),
      DbSchema.cLearnerDominantHand: dominantHand?.trim(),
      DbSchema.cLearnerAgeMotherAtBirth: ageMotherAtBirth?.trim(),
      DbSchema.cLearnerSpouseOccupation: spouseOccupation?.trim(),
      DbSchema.cLearnerStatus: 'active',
      DbSchema.cLearnerCreatedAt: DateTime.now().toIso8601String(),
    };
    final filtered = await _filterExistingLearnerColumns(values);
    try {
      return await db.insert(DbSchema.tLearners, filtered);
    } on DatabaseException catch (e) {
      final message = e.toString();
      if (message.contains('UNIQUE') || message.contains('constraint failed')) {
        if (lrn != null && lrn.isNotEmpty) {
          throw Exception(
            'The LRN "${lrn.trim()}" is already registered in the system. '
            'Please enter a unique Learner Reference Number.',
          );
        }
        throw Exception(
          'A learner with this information already exists. '
          'Please verify the details and try again.',
        );
      }
      rethrow;
    }
  }

  Future<bool> lrnExists(String lrn) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      DbSchema.tLearners,
      where:
          '${DbSchema.cLearnerLrn} IS NOT NULL AND TRIM(${DbSchema.cLearnerLrn}) = ?',
      whereArgs: [lrn.trim()],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> updateLearner({
    required int learnerId,
    required String firstName,
    required String lastName,
    required String gender,
    required int age,
    String? middleName,
    String? lrn,
    String? birthDate,
    String? birthOrder,
    String? numberOfSiblings,
    String? province,
    String? city,
    String? barangay,
    String? parentName,
    String? parentOccupation,
    String? parentEducation,
    String? guardianName,
    String? guardianOccupation,
    String? guardianEducation,
    String? motherName,
    String? motherOccupation,
    String? motherEducation,
    String? fatherName,
    String? fatherOccupation,
    String? fatherEducation,
    String? dominantHand,
    String? ageMotherAtBirth,
    String? spouseOccupation,
  }) async {
    final db = AppDb.instance.db;
    final values = <String, Object?>{
      DbSchema.cLearnerFirstName: firstName.trim(),
      DbSchema.cLearnerLastName: lastName.trim(),
      DbSchema.cLearnerGender: gender.trim().toUpperCase(),
      DbSchema.cLearnerAge: age,
    };
    if (middleName != null) {
      values[DbSchema.cLearnerMiddleName] = middleName.trim();
    }
    if (lrn != null) {
      values[DbSchema.cLearnerLrn] = lrn.trim();
    }
    if (birthDate != null) {
      values[DbSchema.cLearnerBirthDate] = birthDate.trim();
    }
    if (birthOrder != null) {
      values[DbSchema.cLearnerBirthOrder] = birthOrder.trim();
    }
    if (numberOfSiblings != null) {
      values[DbSchema.cLearnerNumSiblings] = numberOfSiblings.trim();
    }
    if (province != null) {
      values[DbSchema.cLearnerProvince] = province.trim();
    }
    if (city != null) {
      values[DbSchema.cLearnerCity] = city.trim();
    }
    if (barangay != null) {
      values[DbSchema.cLearnerBarangay] = barangay.trim();
    }
    if (parentName != null) {
      values[DbSchema.cLearnerParentName] = parentName.trim();
    }
    if (parentOccupation != null) {
      values[DbSchema.cLearnerParentOccupation] = parentOccupation.trim();
    }
    if (parentEducation != null) {
      values[DbSchema.cLearnerParentEducation] = parentEducation.trim();
    }
    if (guardianName != null) {
      values[DbSchema.cLearnerGuardianName] = guardianName.trim();
    }
    if (guardianOccupation != null) {
      values[DbSchema.cLearnerGuardianOccupation] = guardianOccupation.trim();
    }
    if (guardianEducation != null) {
      values[DbSchema.cLearnerGuardianEducation] = guardianEducation.trim();
    }
    if (motherName != null) {
      values[DbSchema.cLearnerMotherName] = motherName.trim();
    }
    if (motherOccupation != null) {
      values[DbSchema.cLearnerMotherOccupation] = motherOccupation.trim();
    }
    if (motherEducation != null) {
      values[DbSchema.cLearnerMotherEducation] = motherEducation.trim();
    }
    if (fatherName != null) {
      values[DbSchema.cLearnerFatherName] = fatherName.trim();
    }
    if (fatherOccupation != null) {
      values[DbSchema.cLearnerFatherOccupation] = fatherOccupation.trim();
    }
    if (fatherEducation != null) {
      values[DbSchema.cLearnerFatherEducation] = fatherEducation.trim();
    }
    if (dominantHand != null) {
      values[DbSchema.cLearnerDominantHand] = dominantHand.trim();
    }
    if (ageMotherAtBirth != null) {
      values[DbSchema.cLearnerAgeMotherAtBirth] = ageMotherAtBirth.trim();
    }
    if (spouseOccupation != null) {
      values[DbSchema.cLearnerSpouseOccupation] = spouseOccupation.trim();
    }
    final filtered = await _filterExistingLearnerColumns(values);

    await db.update(
      DbSchema.tLearners,
      filtered,
      where: '${DbSchema.cLearnerId}=?',
      whereArgs: [learnerId],
    );
  }

  Future<Map<String, Object?>?> getLearner(int learnerId) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerId}=?',
      whereArgs: [learnerId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, Object?>>> listActiveLearners(int classId) async {
    final db = AppDb.instance.db;
    return db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [classId, 'active'],
      orderBy: '${DbSchema.cLearnerLastName} ASC',
    );
  }

  Future<List<Map<String, Object?>>> listDroppedLearners(int classId) async {
    final db = AppDb.instance.db;
    return db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [classId, 'dropped'],
      orderBy: '${DbSchema.cLearnerLastName} ASC',
    );
  }

  Future<void> dropLearner(int learnerId) async {
    final db = AppDb.instance.db;
    await db.update(
      DbSchema.tLearners,
      {DbSchema.cLearnerStatus: 'dropped'},
      where: '${DbSchema.cLearnerId}=?',
      whereArgs: [learnerId],
    );
  }

  Future<void> reactivateLearner(int learnerId) async {
    final db = AppDb.instance.db;
    await db.update(
      DbSchema.tLearners,
      {DbSchema.cLearnerStatus: 'active'},
      where: '${DbSchema.cLearnerId}=?',
      whereArgs: [learnerId],
    );
  }

  Future<bool> learnerExists({
    required int classId,
    required String firstName,
    required String lastName,
    required String birthDate,
  }) async {
    final db = AppDb.instance.db;

    final rows = await db.query(
      'learners',
      where: '''
      class_id = ? AND
      first_name = ? AND
      last_name = ? AND
      birth_date = ?
    ''',
      whereArgs: [classId, firstName, lastName, birthDate],
      limit: 1,
    );

    return rows.isNotEmpty;
  }
}
