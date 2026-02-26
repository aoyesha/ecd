import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import 'assessment_scoring.dart';

class AssessmentService {

  // ============================================================
  // SAVE OR UPDATE ASSESSMENT (FINAL MERGED VERSION)
  // ============================================================
  static Future<void> saveAssessment({
    required int learnerId,
    required int classId,
    required String assessmentType,
    required DateTime date,
    required Map<String, bool> yesValues,
  }) async {
    final db = await DatabaseService.instance.getDatabase();

    await db.transaction((txn) async {

      // ---------------- GET LEARNER AGE ----------------
      final learner = await txn.query(
        DatabaseService.learnerTable,
        where: 'learner_id = ?',
        whereArgs: [learnerId],
        limit: 1,
      );
      if (learner.isEmpty) throw Exception("Learner not found.");

      final dobStr = learner.first['birthday'] as String?;
      if (dobStr == null || dobStr.isEmpty) {
        throw Exception("Learner birthday missing.");
      }

      final dob = DateTime.parse(dobStr);
      final days = date.difference(dob).inDays;
      final years = days ~/ 365;
      final months = (days % 365) / 30;
      final ageAsOfAssessment = years + months / 12;

      // ---------------- CHECK EXISTING ASSESSMENT ----------------
      final existing = await txn.query(
        DatabaseService.assessmentHeaderTable,
        where: 'learner_id = ? AND class_id = ? AND assessment_type = ?',
        whereArgs: [learnerId, classId, assessmentType],
        orderBy: 'date_taken DESC',
        limit: 1,
      );

      int assessmentId;

      if (existing.isNotEmpty) {
        assessmentId = existing.first['assessment_id'] as int;

        await txn.update(
          DatabaseService.assessmentHeaderTable,
          {
            'date_taken': date.toIso8601String(),
            'age_as_of_assessment': ageAsOfAssessment,
          },
          where: 'assessment_id = ?',
          whereArgs: [assessmentId],
        );

        await txn.delete(
          DatabaseService.assessmentResultsTable,
          where: 'assessment_id = ?',
          whereArgs: [assessmentId],
        );
        await txn.delete(
          DatabaseService.learnerEcdTable,
          where: 'assessment_id = ?',
          whereArgs: [assessmentId],
        );
      } else {
        assessmentId = await txn.insert(
          DatabaseService.assessmentHeaderTable,
          {
            'learner_id': learnerId,
            'class_id': classId,
            'assessment_type': assessmentType,
            'date_taken': date.toIso8601String(),
            'age_as_of_assessment': ageAsOfAssessment,
          },
        );
      }

      // ---------------- INSERT RESULTS ----------------
      final Map<String, int> domainTotals = {
        'gmd': 0,
        'fms': 0,
        'shd': 0,
        'rl': 0,
        'el': 0,
        'cd': 0,
        'sed': 0,
      };

      for (final entry in yesValues.entries) {
        final parts = entry.key.split('-');
        final domainLabel = parts.first;
        final qIndex = int.tryParse(parts.last) ?? 0;
        final answer = entry.value ? 1 : 0;

        await txn.insert(DatabaseService.assessmentResultsTable, {
          'assessment_id': assessmentId,
          'domain': domainLabel,
          'question_index': qIndex + 1,
          'answer': answer,
        });

        final code = _domainCode(domainLabel);
        if (code != null && answer == 1) {
          domainTotals[code] = domainTotals[code]! + 1;
        }
      }

      // ---------------- COMPUTE SCORES ----------------
      final scoring = AssessmentScoring.calculate(
        ageInYears: ageAsOfAssessment,
        gmdRaw: domainTotals['gmd']!,
        fmsRaw: domainTotals['fms']!,
        shdRaw: domainTotals['shd']!,
        rlRaw: domainTotals['rl']!,
        elRaw: domainTotals['el']!,
        cdRaw: domainTotals['cd']!,
        sedRaw: domainTotals['sed']!,
      );

      await txn.insert(DatabaseService.learnerEcdTable, {
        'assessment_id': assessmentId,
        ...scoring,
      });
    });
  }

  // ============================================================
  // DOMAIN NAME → CODE MAPPER (MERGED)
  // ============================================================
  static String? _domainCode(String domainLabel) {
    final d = domainLabel.toLowerCase().trim();

    if (d.contains('gross')) return 'gmd';
    if (d.contains('fine')) return 'fms';
    if (d.contains('self') || d.contains('dress') || d.contains('toilet')) return 'shd';
    if (d.contains('receptive')) return 'rl';
    if (d.contains('expressive')) return 'el';
    if (d.contains('cognitive')) return 'cd';
    if (d.contains('socio') || d.contains('social') || d.contains('emotional')) return 'sed';

    if (['gmd','fms','shd','rl','el','cd','sed'].contains(d)) return d;
    return null;
  }

  // ============================================================
  // GET LATEST ASSESSMENT + RESULTS
  // ============================================================
  static Future<List<Map<String, dynamic>>> getAssessment({
    required int learnerId,
    required int classId,
    required String assessmentType,
  }) async {
    final db = await DatabaseService.instance.getDatabase();

    final header = await db.query(
      DatabaseService.assessmentHeaderTable,
      where: 'learner_id = ? AND class_id = ? AND assessment_type = ?',
      whereArgs: [learnerId, classId, assessmentType],
      orderBy: 'date_taken DESC',
      limit: 1,
    );

    if (header.isEmpty) return [];

    final assessmentId = header.first['assessment_id'] as int;
    final dateTaken = header.first['date_taken'];

    final results = await db.query(
      DatabaseService.assessmentResultsTable,
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
      orderBy: 'domain ASC, question_index ASC',
    );

    return results.map((row) {
      final m = Map<String, dynamic>.from(row);
      m['date_taken'] = dateTaken;
      m['assessment_id'] = assessmentId;
      return m;
    }).toList();
  }

  // ============================================================
  // HELPERS USED BY SUMMARY / CLASS LIST
  // ============================================================

  static Future<bool> hasPostTest({
    required int learnerId,
    required int classId,
  }) async {
    final db = await DatabaseService.instance.getDatabase();
    final rows = await db.query(
      DatabaseService.assessmentHeaderTable,
      where: 'learner_id = ? AND class_id = ? AND assessment_type = ?',
      whereArgs: [learnerId, classId, 'Post-Test'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<int?> getLatestAssessmentId({
    required int learnerId,
    required int classId,
    required String assessmentType,
  }) async {
    final db = await DatabaseService.instance.getDatabase();
    final rows = await db.query(
      DatabaseService.assessmentHeaderTable,
      where: 'learner_id = ? AND class_id = ? AND assessment_type = ?',
      whereArgs: [learnerId, classId, assessmentType],
      orderBy: 'date_taken DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['assessment_id'] as int;
  }

  static Future<Map<String, dynamic>?> getEcdSummary({
    required int assessmentId,
  }) async {
    final db = await DatabaseService.instance.getDatabase();
    final rows = await db.query(
      DatabaseService.learnerEcdTable,
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<List<Map<String, dynamic>>> getAssessmentResultsByAssessmentId(
      int assessmentId,
      ) async {
    final db = await DatabaseService.instance.getDatabase();
    return db.query(
      DatabaseService.assessmentResultsTable,
      where: 'assessment_id = ?',
      whereArgs: [assessmentId],
      orderBy: 'domain ASC, question_index ASC',
    );
  }

  // ============================================================
  // LEGACY SUPPORT (OLD SUMMARY PAGE STILL USES THIS)
  // ============================================================
  static Future<List<Map<String, dynamic>>> fetchEcdDataForTeacher(int teacherId) async {
    final db = await DatabaseService.instance.getDatabase();

    return db.rawQuery('''
      SELECT l.sex,
             e.gmd_ss, e.fms_ss, e.shd_ss, e.rl_ss, e.el_ss, e.cd_ss, e.sed_ss
      FROM learner_ecd_table e
      JOIN assessment_header a ON a.assessment_id = e.assessment_id
      JOIN learner_information_table l ON l.learner_id = a.learner_id
      JOIN class_table c ON c.class_id = a.class_id
      WHERE c.teacher_id = ?
    ''', [teacherId]);
  }
}