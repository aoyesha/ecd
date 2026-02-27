import '../data/eccd_questions.dart';
import '../db/app_db.dart';
import '../db/schema.dart';
import 'scoring_service.dart';

class ClassSummaryRow {
  final String level;
  final Map<String, DomainGenderCounts> perDomain; // domain -> counts
  ClassSummaryRow({required this.level, required this.perDomain});
}

class DomainGenderCounts {
  int m = 0;
  int f = 0;
  int get total => m + f;
}

class TopSkill {
  final String domain;
  final int skillIndex;
  final String skillText;
  final int checkedCount;
  final int totalLearners;

  TopSkill({
    required this.domain,
    required this.skillIndex,
    required this.skillText,
    required this.checkedCount,
    required this.totalLearners,
  });

  double get pct => totalLearners == 0 ? 0 : checkedCount / totalLearners;
}

class TeacherHistoricalSnapshot {
  final int classCount;
  final int assessedLearnerCount;
  final Map<String, int> levelTotals;
  final Map<String, int> domainTotals;

  TeacherHistoricalSnapshot({
    required this.classCount,
    required this.assessedLearnerCount,
    required this.levelTotals,
    required this.domainTotals,
  });
}

class AnalyticsService {
  final _levels = DevLevels.ordered;
  final _domains = const [
    'Gross Motor',
    'Fine Motor',
    'Self Help',
    'Receptive Language',
    'Expressive Language',
    'Cognitive',
    'Social Emotional',
  ];

  String _normalizeDomain(String domain) {
    final d = domain.trim();
    if (d == 'Dressing' || d == 'Toilet') return 'Self Help';
    return d;
  }

  Future<Map<String, DomainGenderCounts>> buildClassOverallLevelCounts({
    required int classId,
    required String assessmentType, // pre|post
  }) async {
    final db = AppDb.instance.db;
    final out = <String, DomainGenderCounts>{
      for (final lvl in _levels) lvl: DomainGenderCounts(),
    };

    final learners = await db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [classId, 'active'],
    );

    for (final l in learners) {
      final learnerId = l[DbSchema.cLearnerId] as int;
      final gender = (l[DbSchema.cLearnerGender] as String).toUpperCase();

      final assess = await db.query(
        DbSchema.tAssessments,
        columns: [DbSchema.cAssessId],
        where:
            '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
        whereArgs: [learnerId, classId, assessmentType],
        limit: 1,
      );
      if (assess.isEmpty) continue;

      final assessId = assess.first[DbSchema.cAssessId] as int;
      final sum = await db.query(
        DbSchema.tAssessmentSummary,
        columns: [DbSchema.cSumOverallInterpretation],
        where: '${DbSchema.cSumAssessId}=?',
        whereArgs: [assessId],
        limit: 1,
      );
      if (sum.isEmpty) continue;

      final level = (sum.first[DbSchema.cSumOverallInterpretation] ?? '')
          .toString();
      if (!out.containsKey(level)) continue;
      if (gender == 'M') {
        out[level]!.m += 1;
      } else if (gender == 'F') {
        out[level]!.f += 1;
      }
    }

    return out;
  }

  Future<List<String>> listTeacherSchoolYears(int teacherId) async {
    final db = AppDb.instance.db;
    final rows = await db.query(
      DbSchema.tClasses,
      columns: [DbSchema.cClassSchoolYear],
      where: '${DbSchema.cClassTeacherId}=?',
      whereArgs: [teacherId],
      orderBy: '${DbSchema.cClassSchoolYear} DESC',
    );

    final seen = <String>{};
    final out = <String>[];
    for (final r in rows) {
      final sy = (r[DbSchema.cClassSchoolYear] ?? '').toString().trim();
      if (sy.isEmpty || seen.contains(sy)) continue;
      seen.add(sy);
      out.add(sy);
    }
    return out;
  }

  Future<TeacherHistoricalSnapshot> buildTeacherHistoricalSnapshot({
    required int teacherId,
    required String schoolYear,
    required String assessmentType, // pre|post
  }) async {
    final db = AppDb.instance.db;

    final classes = await db.query(
      DbSchema.tClasses,
      columns: [DbSchema.cClassId],
      where: '${DbSchema.cClassTeacherId}=? AND ${DbSchema.cClassSchoolYear}=?',
      whereArgs: [teacherId, schoolYear],
    );

    final classIds = classes.map((e) => e[DbSchema.cClassId] as int).toList();
    if (classIds.isEmpty) {
      return TeacherHistoricalSnapshot(
        classCount: 0,
        assessedLearnerCount: 0,
        levelTotals: {for (final l in _levels) l: 0},
        domainTotals: {for (final d in _domains) d: 0},
      );
    }

    final levelTotals = <String, int>{for (final l in _levels) l: 0};
    final domainTotals = <String, int>{for (final d in _domains) d: 0};
    int assessedLearners = 0;

    for (final classId in classIds) {
      final learners = await db.query(
        DbSchema.tLearners,
        columns: [DbSchema.cLearnerId],
        where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
        whereArgs: [classId, 'active'],
      );

      for (final l in learners) {
        final learnerId = l[DbSchema.cLearnerId] as int;
        final assess = await db.query(
          DbSchema.tAssessments,
          columns: [DbSchema.cAssessId],
          where:
              '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
          whereArgs: [learnerId, classId, assessmentType],
          limit: 1,
        );
        if (assess.isEmpty) continue;
        assessedLearners += 1;

        final assessId = assess.first[DbSchema.cAssessId] as int;
        final dom = await db.query(
          DbSchema.tDomainSummary,
          where: '${DbSchema.cDomSumAssessId}=?',
          whereArgs: [assessId],
        );
        for (final ds in dom) {
          final domain = _normalizeDomain(
            (ds[DbSchema.cDomSumDomain] ?? '').toString(),
          );
          if (domainTotals.containsKey(domain)) {
            domainTotals[domain] = (domainTotals[domain] ?? 0) + 1;
          }
        }

        final sum = await db.query(
          DbSchema.tAssessmentSummary,
          columns: [DbSchema.cSumOverallInterpretation],
          where: '${DbSchema.cSumAssessId}=?',
          whereArgs: [assessId],
          limit: 1,
        );
        if (sum.isNotEmpty) {
          final overallLevel =
              (sum.first[DbSchema.cSumOverallInterpretation] ?? '').toString();
          if (levelTotals.containsKey(overallLevel)) {
            levelTotals[overallLevel] = (levelTotals[overallLevel] ?? 0) + 1;
          }
        }
      }
    }

    return TeacherHistoricalSnapshot(
      classCount: classIds.length,
      assessedLearnerCount: assessedLearners,
      levelTotals: levelTotals,
      domainTotals: domainTotals,
    );
  }

  Future<Map<String, Map<String, List<TopSkill>>>>
  top3MostLeastByDomainForTeacherSchoolYear({
    required int teacherId,
    required String schoolYear,
    required String assessmentType, // pre|post
    required EccdLanguage language,
  }) async {
    final db = AppDb.instance.db;
    final classes = await db.query(
      DbSchema.tClasses,
      columns: [DbSchema.cClassId],
      where: '${DbSchema.cClassTeacherId}=? AND ${DbSchema.cClassSchoolYear}=?',
      whereArgs: [teacherId, schoolYear],
    );

    final classIds = classes.map((e) => e[DbSchema.cClassId] as int).toList();
    if (classIds.isEmpty) return {};

    final totalLearners = <String, int>{for (final d in _domains) d: 0};
    final checked = <String, Map<int, int>>{for (final d in _domains) d: {}};

    for (final classId in classIds) {
      final learners = await db.query(
        DbSchema.tLearners,
        columns: [DbSchema.cLearnerId],
        where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
        whereArgs: [classId, 'active'],
      );

      for (final l in learners) {
        final learnerId = l[DbSchema.cLearnerId] as int;
        final assess = await db.query(
          DbSchema.tAssessments,
          columns: [DbSchema.cAssessId],
          where:
              '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
          whereArgs: [learnerId, classId, assessmentType],
          limit: 1,
        );
        if (assess.isEmpty) continue;
        final assessId = assess.first[DbSchema.cAssessId] as int;

        for (final d in _domains) {
          totalLearners[d] = (totalLearners[d] ?? 0) + 1;
        }

        final ans = await db.query(
          DbSchema.tAnswers,
          where: '${DbSchema.cAnsAssessId}=?',
          whereArgs: [assessId],
        );

        for (final a in ans) {
          final domain = _normalizeDomain(a[DbSchema.cAnsDomain] as String);
          if (!_domains.contains(domain)) continue;
          final idx = a[DbSchema.cAnsIndex] as int;
          final val = a[DbSchema.cAnsValue] as int;
          if (val == 1) {
            checked[domain]![idx] = (checked[domain]![idx] ?? 0) + 1;
          }
        }
      }
    }

    final out = <String, Map<String, List<TopSkill>>>{};
    for (final domain in _domains) {
      final questions = EccdQuestions.get(domain, language);
      final list = <TopSkill>[];
      for (int i = 0; i < questions.length; i++) {
        list.add(
          TopSkill(
            domain: domain,
            skillIndex: i,
            skillText: questions[i],
            checkedCount: checked[domain]![i] ?? 0,
            totalLearners: totalLearners[domain] ?? 0,
          ),
        );
      }

      list.sort((a, b) => b.pct.compareTo(a.pct));
      final most = list.take(3).toList();
      final leastList = [...list]..sort((a, b) => a.pct.compareTo(b.pct));
      final least = leastList.take(3).toList();

      out[domain] = {'most': most, 'least': least};
    }
    return out;
  }

  /// Builds class summary matrix:
  /// rows = levels (SSDD..SHAD), columns = domains with M/F/TOTAL, plus GRAND TOTAL
  /// Matching the reference layout. :contentReference[oaicite:3]{index=3}
  Future<List<ClassSummaryRow>> buildClassLevelMatrix({
    required int classId,
    required String assessmentType, // pre|post
  }) async {
    final db = AppDb.instance.db;

    // Active learners only
    final learners = await db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [classId, 'active'],
    );

    // init
    final rows = <ClassSummaryRow>[
      for (final lvl in _levels)
        ClassSummaryRow(
          level: lvl,
          perDomain: {for (final d in _domains) d: DomainGenderCounts()},
        ),
    ];

    // For each learner, fetch domain interpretations and count them
    for (final l in learners) {
      final learnerId = l[DbSchema.cLearnerId] as int;
      final gender = (l[DbSchema.cLearnerGender] as String).toUpperCase();

      final assess = await db.query(
        DbSchema.tAssessments,
        columns: [DbSchema.cAssessId],
        where:
            '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
        whereArgs: [learnerId, classId, assessmentType],
        limit: 1,
      );
      if (assess.isEmpty) continue; // incomplete learner -> not counted

      final assessId = assess.first[DbSchema.cAssessId] as int;
      final dom = await db.query(
        DbSchema.tDomainSummary,
        where: '${DbSchema.cDomSumAssessId}=?',
        whereArgs: [assessId],
      );

      for (final ds in dom) {
        final domain = _normalizeDomain(ds[DbSchema.cDomSumDomain] as String);
        final level = ds[DbSchema.cDomSumInterp] as String;
        if (!_domains.contains(domain)) continue;

        final row = rows.firstWhere(
          (r) => r.level == level,
          orElse: () => rows.first,
        );
        final counts = row.perDomain[domain]!;
        if (gender == 'M') {
          counts.m += 1;
        } else if (gender == 'F') {
          counts.f += 1;
        }
      }
    }

    return rows;
  }

  /// Teacher Top 3 most/least learned per domain for a class.
  /// Uses answer frequency: checkedCount / totalLearners.
  Future<Map<String, Map<String, List<TopSkill>>>>
  top3MostLeastByDomainForClass({
    required int classId,
    required String assessmentType, // pre|post
    required EccdLanguage language,
  }) async {
    final db = AppDb.instance.db;

    final learners = await db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [classId, 'active'],
    );

    // For each domain and skill index -> checked count
    final totalLearners = <String, int>{for (final d in _domains) d: 0};
    final checked = <String, Map<int, int>>{for (final d in _domains) d: {}};

    for (final l in learners) {
      final learnerId = l[DbSchema.cLearnerId] as int;

      final assess = await db.query(
        DbSchema.tAssessments,
        columns: [DbSchema.cAssessId],
        where:
            '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
        whereArgs: [learnerId, classId, assessmentType],
        limit: 1,
      );
      if (assess.isEmpty) continue;
      final assessId = assess.first[DbSchema.cAssessId] as int;

      // count this learner towards total for each domain if they have answers
      for (final d in _domains) {
        totalLearners[d] = (totalLearners[d] ?? 0) + 1;
      }

      final ans = await db.query(
        DbSchema.tAnswers,
        where: '${DbSchema.cAnsAssessId}=?',
        whereArgs: [assessId],
      );

      for (final a in ans) {
        final domain = _normalizeDomain(a[DbSchema.cAnsDomain] as String);
        if (!_domains.contains(domain)) continue;
        final idx = a[DbSchema.cAnsIndex] as int;
        final val = a[DbSchema.cAnsValue] as int;
        if (val == 1) {
          checked[domain]![idx] = (checked[domain]![idx] ?? 0) + 1;
        }
      }
    }

    // Build TopSkill lists per domain
    final out = <String, Map<String, List<TopSkill>>>{};

    for (final domain in _domains) {
      final questions = EccdQuestions.get(domain, language);
      final list = <TopSkill>[];

      for (int i = 0; i < questions.length; i++) {
        list.add(
          TopSkill(
            domain: domain,
            skillIndex: i,
            skillText: questions[i],
            checkedCount: checked[domain]![i] ?? 0,
            totalLearners: totalLearners[domain] ?? 0,
          ),
        );
      }

      list.sort((a, b) => b.pct.compareTo(a.pct)); // high -> low
      final most = list.take(3).toList();

      final leastList = [...list]..sort((a, b) => a.pct.compareTo(b.pct));
      final least = leastList.take(3).toList();

      out[domain] = {'most': most, 'least': least};
    }

    return out;
  }
}
