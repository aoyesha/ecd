import '../db/app_db.dart';
import '../db/schema.dart';

class ClassService {
  Future<bool> sectionExists({
    required int teacherId,
    required String section,
    required String schoolYear,
    int? excludeClassId,
  }) async {
    final db = AppDb.instance.db;
    var query = StringBuffer(
        '${DbSchema.cClassTeacherId}=? AND ${DbSchema.cClassSection}=? AND ${DbSchema.cClassSchoolYear}=? AND ${DbSchema.cClassStatus}=?');
    var args = <Object?>[teacherId, section.trim(), schoolYear.trim(), 'active'];
    
    if (excludeClassId != null) {
      query.write(' AND ${DbSchema.cClassId}!=?');
      args.add(excludeClassId);
    }
    
    final result = await db.query(
      DbSchema.tClasses,
      where: query.toString(),
      whereArgs: args,
    );
    return result.isNotEmpty;
  }

  Future<int> createClass({
    required int teacherId,
    required String grade,
    required String section,
    required String schoolYear,
  }) async {
    final db = AppDb.instance.db;
    return db.insert(DbSchema.tClasses, {
      DbSchema.cClassTeacherId: teacherId,
      DbSchema.cClassGrade: grade.trim(),
      DbSchema.cClassSection: section.trim(),
      DbSchema.cClassSchoolYear: schoolYear.trim(),
      DbSchema.cClassStatus: 'active',
      DbSchema.cClassCreatedAt: DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> listActiveClasses(int teacherId,
      {String? schoolYear}) async {
    final db = AppDb.instance.db;
    final where = StringBuffer(
        '${DbSchema.cClassTeacherId}=? AND ${DbSchema.cClassStatus}=?');
    final args = <Object?>[teacherId, 'active'];
    if (schoolYear != null && schoolYear.trim().isNotEmpty) {
      where.write(' AND ${DbSchema.cClassSchoolYear}=?');
      args.add(schoolYear.trim());
    }
    return db.query(DbSchema.tClasses,
        where: where.toString(),
        whereArgs: args,
        orderBy: '${DbSchema.cClassCreatedAt} DESC');
  }

  Future<List<Map<String, Object?>>> listArchivedClasses(int teacherId) async {
    final db = AppDb.instance.db;
    return db.query(
      DbSchema.tClasses,
      where: '${DbSchema.cClassTeacherId}=? AND ${DbSchema.cClassStatus}=?',
      whereArgs: [teacherId, 'archived'],
      orderBy: '${DbSchema.cClassCreatedAt} DESC',
    );
  }

  Future<void> archiveClass(int classId) async {
    final db = AppDb.instance.db;
    await db.update(DbSchema.tClasses, {DbSchema.cClassStatus: 'archived'},
        where: '${DbSchema.cClassId}=?', whereArgs: [classId]);
  }

  Future<void> unarchiveClass(int classId) async {
    final db = AppDb.instance.db;
    await db.update(DbSchema.tClasses, {DbSchema.cClassStatus: 'active'},
        where: '${DbSchema.cClassId}=?', whereArgs: [classId]);
  }

  Future<void> updateClass({
    required int classId,
    String? grade,
    String? section,
  }) async {
    final db = AppDb.instance.db;
    final updates = <String, Object?>{};
    if (grade != null) {
      updates[DbSchema.cClassGrade] = grade.trim();
    }
    if (section != null) {
      updates[DbSchema.cClassSection] = section.trim();
    }
    if (updates.isNotEmpty) {
      await db.update(DbSchema.tClasses, updates,
          where: '${DbSchema.cClassId}=?', whereArgs: [classId]);
    }
  }
}
