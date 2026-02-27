import '../db/app_db.dart';
import '../db/schema.dart';
import '../data/eccd_questions.dart';
import 'scoring_service.dart';

class AssessmentService {
  final _scoring = ScoringService();

  /// Save checklist answers for a learner for:
  /// - 'pre'
  /// - 'post'
  /// If user selects "Conditional", pass conditionalOverwritePre=true and it will save as 'pre'.
  Future<void> saveAssessment({
    required int learnerId,
    required int classId,
    required String assessmentType, // 'pre'|'post'
    required bool conditionalOverwritePre,
    required String dateIso,
    required int ageAtAssessment,
    double? ageValueForScoring,
    required String language, // 'english'|'tagalog'
    required Map<String, List<int>> answersByDomain, // 0/1 per question
  }) async {
    final db = AppDb.instance.db;
    final scoringAge = ageValueForScoring ?? ageAtAssessment.toDouble();

    final effectiveType = conditionalOverwritePre ? 'pre' : assessmentType;

    // Upsert assessment header
    final existing = await db.query(
      DbSchema.tAssessments,
      where:
          '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
      whereArgs: [learnerId, classId, effectiveType],
      limit: 1,
    );

    int assessId;
    if (existing.isNotEmpty) {
      assessId = existing.first[DbSchema.cAssessId] as int;
      await db.update(
        DbSchema.tAssessments,
        {
          DbSchema.cAssessDate: dateIso,
          DbSchema.cAssessAgeAt: ageAtAssessment,
          DbSchema.cAssessLanguage: language,
        },
        where: '${DbSchema.cAssessId}=?',
        whereArgs: [assessId],
      );

      // Delete old answers + summaries
      await db.delete(
        DbSchema.tAnswers,
        where: '${DbSchema.cAnsAssessId}=?',
        whereArgs: [assessId],
      );
      await db.delete(
        DbSchema.tDomainSummary,
        where: '${DbSchema.cDomSumAssessId}=?',
        whereArgs: [assessId],
      );
      await db.delete(
        DbSchema.tAssessmentSummary,
        where: '${DbSchema.cSumAssessId}=?',
        whereArgs: [assessId],
      );
    } else {
      assessId = await db.insert(DbSchema.tAssessments, {
        DbSchema.cAssessLearnerId: learnerId,
        DbSchema.cAssessClassId: classId,
        DbSchema.cAssessType: effectiveType,
        DbSchema.cAssessDate: dateIso,
        DbSchema.cAssessAgeAt: ageAtAssessment,
        DbSchema.cAssessLanguage: language,
        DbSchema.cAssessCreatedAt: DateTime.now().toIso8601String(),
      });
    }

    // Insert answers
    for (final domain in EccdQuestions.domains) {
      final list = answersByDomain[domain] ?? const [];
      for (int i = 0; i < list.length; i++) {
        await db.insert(DbSchema.tAnswers, {
          DbSchema.cAnsAssessId: assessId,
          DbSchema.cAnsDomain: domain,
          DbSchema.cAnsIndex: i,
          DbSchema.cAnsValue: list[i],
        });
      }
    }

    // Compute summaries
    int overallScaled = 0;

    for (final domain in EccdQuestions.domains) {
      final list = answersByDomain[domain] ?? const [];
      final raw = list.fold<int>(0, (a, b) => a + (b == 1 ? 1 : 0));
      final scaled = _scoring.rawToScaled(
        ageValue: scoringAge,
        domain: domain,
        raw: raw,
      );
      final interp = _scoring.scaledInterpretation(scaled);
      overallScaled += scaled;

      await db.insert(DbSchema.tDomainSummary, {
        DbSchema.cDomSumAssessId: assessId,
        DbSchema.cDomSumDomain: domain,
        DbSchema.cDomSumRaw: raw,
        DbSchema.cDomSumScaled: scaled,
        DbSchema.cDomSumInterp: interp,
      });
    }

    final standard = _scoring.overallScaledToStandard(overallScaled);
    final overallInterp = _scoring.overallInterpretation(standard);

    await db.insert(DbSchema.tAssessmentSummary, {
      DbSchema.cSumAssessId: assessId,
      DbSchema.cSumOverallScaled: overallScaled,
      DbSchema.cSumStandardScore: standard,
      DbSchema.cSumOverallInterpretation: overallInterp,
    });
  }

  Future<bool> hasSavedAssessment({
    required int learnerId,
    required int classId,
    required String assessmentType, // pre|post
  }) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      DbSchema.tAssessments,
      columns: [DbSchema.cAssessId],
      where:
          '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
      whereArgs: [learnerId, classId, assessmentType],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, Object?>?> getAssessmentHeader({
    required int learnerId,
    required int classId,
    required String assessmentType,
  }) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      DbSchema.tAssessments,
      where:
          '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
      whereArgs: [learnerId, classId, assessmentType],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, List<int>>> loadAnswers({
    required int assessmentId,
  }) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      DbSchema.tAnswers,
      where: '${DbSchema.cAnsAssessId}=?',
      whereArgs: [assessmentId],
      orderBy: '${DbSchema.cAnsDomain} ASC, ${DbSchema.cAnsIndex} ASC',
    );

    final map = <String, List<int>>{};
    for (final d in EccdQuestions.domains) {
      map[d] = List<int>.filled(
        EccdQuestions.get(d, EccdLanguage.english).length,
        0,
      );
    }

    final selfHelpCoreLen = EccdQuestions.selfHelpCore(
      EccdLanguage.english,
    ).length;
    final selfHelpDressLen = EccdQuestions.get(
      'Dressing',
      EccdLanguage.english,
    ).length;

    for (final r in rows) {
      final rawDomain = r[DbSchema.cAnsDomain] as String;
      String domain = rawDomain;
      int idx = r[DbSchema.cAnsIndex] as int;
      if (rawDomain == 'Dressing' || rawDomain == 'Toilet') {
        domain = 'Self Help';
        idx += selfHelpCoreLen;
        if (rawDomain == 'Toilet') {
          idx += selfHelpDressLen;
        }
      }
      final val = r[DbSchema.cAnsValue] as int;
      if (idx >= 0 && idx < map[domain]!.length) {
        map[domain]![idx] = val;
      }
    }
    return map;
  }
}
