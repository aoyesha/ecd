import '../db/app_db.dart';
import '../db/schema.dart';

class LearnerService {
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
    String? motherName,
    String? motherOccupation,
    String? fatherName,
    String? fatherOccupation,
    String? ageMotherAtBirth,
    String? spouseOccupation,
  }) async {
    final db = AppDb.instance.db;
    return db.insert(DbSchema.tLearners, {
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
      DbSchema.cLearnerMotherName: motherName?.trim(),
      DbSchema.cLearnerMotherOccupation: motherOccupation?.trim(),
      DbSchema.cLearnerFatherName: fatherName?.trim(),
      DbSchema.cLearnerFatherOccupation: fatherOccupation?.trim(),
      DbSchema.cLearnerAgeMotherAtBirth: ageMotherAtBirth?.trim(),
      DbSchema.cLearnerSpouseOccupation: spouseOccupation?.trim(),
      DbSchema.cLearnerStatus: 'active',
      DbSchema.cLearnerCreatedAt: DateTime.now().toIso8601String(),
    });
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
    String? motherName,
    String? motherOccupation,
    String? fatherName,
    String? fatherOccupation,
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
    if (motherName != null) {
      values[DbSchema.cLearnerMotherName] = motherName.trim();
    }
    if (motherOccupation != null) {
      values[DbSchema.cLearnerMotherOccupation] = motherOccupation.trim();
    }
    if (fatherName != null) {
      values[DbSchema.cLearnerFatherName] = fatherName.trim();
    }
    if (fatherOccupation != null) {
      values[DbSchema.cLearnerFatherOccupation] = fatherOccupation.trim();
    }
    if (ageMotherAtBirth != null) {
      values[DbSchema.cLearnerAgeMotherAtBirth] = ageMotherAtBirth.trim();
    }
    if (spouseOccupation != null) {
      values[DbSchema.cLearnerSpouseOccupation] = spouseOccupation.trim();
    }

    await db.update(
      DbSchema.tLearners,
      values,
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
