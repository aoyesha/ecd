import 'package:csv/csv.dart';
import '../core/csv_schema.dart';
import '../core/constants.dart';
import '../data/eccd_questions.dart';
import '../db/app_db.dart';
import '../db/schema.dart';
import 'scoring_service.dart';

class CsvService {
  final _conv = const ListToCsvConverter();
  final _parser = const CsvToListConverter(eol: '\n');
  final _levels = DevLevels.ordered;

  static const _domains = [
    'Gross Motor',
    'Fine Motor',
    'Self Help',
    'Receptive Language',
    'Expressive Language',
    'Cognitive',
    'Social Emotional',
  ];

  List<String> _allDomainsPlusAll() => ['ALL', ..._domains];
  String _normalizeDomain(String domain) {
    final d = domain.trim();
    if (d == 'Dressing' || d == 'Toilet') return 'Self Help';
    return d;
  }

  int _normalizeSelfHelpSkillIndex(String rawDomain, int idx) {
    final d = rawDomain.trim();
    final coreLen = EccdQuestions.selfHelpCore(EccdLanguage.english).length;
    final dressingLen = EccdQuestions.get(
      'Dressing',
      EccdLanguage.english,
    ).length;
    if (d == 'Dressing') {
      return coreLen + idx;
    }
    if (d == 'Toilet') {
      return coreLen + dressingLen + idx;
    }
    return idx;
  }

  Map<String, int> _levelMapZero() => {for (final l in _levels) l: 0};

  /// Teacher: export class rollup summary in canonical schema
  /// Includes:
  /// - DATA rows (domain×gender×level counts)
  /// - SKILL rows (per domain skill frequency) to enable Admin Top3.
  Future<String> exportTeacherClassRollupCsv({
    required int teacherId,
    required int classId,
    required String assessmentType, // pre|post
    required EccdLanguage languageForSkills, // used to embed skill text
  }) async {
    final db = AppDb.instance.db;

    final classRow = (await db.query(
      DbSchema.tClasses,
      where: '${DbSchema.cClassId}=?',
      whereArgs: [classId],
      limit: 1,
    )).first;
    final teacherRow = (await db.query(
      DbSchema.tUsers,
      where: '${DbSchema.cUserId}=?',
      whereArgs: [teacherId],
      limit: 1,
    )).first;

    // Only ACTIVE learners
    final learners = await db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [classId, 'active'],
    );

    // Build counts: domain x gender x level
    final counts = <String, Map<String, Map<String, int>>>{};
    for (final domain in _allDomainsPlusAll()) {
      counts[domain] = {
        'M': _levelMapZero(),
        'F': _levelMapZero(),
        'ALL': _levelMapZero(),
      };
    }

    // Skill frequency: domain -> index -> checkedCount, and total learners counted
    final skillChecked = <String, Map<int, int>>{
      for (final d in _domains) d: {},
    };
    final skillTotalLearners = <String, int>{for (final d in _domains) d: 0};

    // Ensure all learners have saved assessment before exporting
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

      if (assess.isEmpty) {
        throw StateError(
          'Cannot export CSV: not all learners have saved ${assessmentTypeDisplay(assessmentType)} assessments.',
        );
      }

      final assessId = assess.first[DbSchema.cAssessId] as int;

      // Domain-level interpretations (for DATA rows)
      final domainSummaries = await db.query(
        DbSchema.tDomainSummary,
        where: '${DbSchema.cDomSumAssessId}=?',
        whereArgs: [assessId],
      );

      for (final ds in domainSummaries) {
        final rawDomain = ds[DbSchema.cDomSumDomain] as String;
        final domain = _normalizeDomain(rawDomain);
        final level = ds[DbSchema.cDomSumInterp] as String;

        if (counts[domain] == null) continue;
        counts[domain]![gender]![level] =
            (counts[domain]![gender]![level] ?? 0) + 1;
        counts[domain]!['ALL']![level] =
            (counts[domain]!['ALL']![level] ?? 0) + 1;
      }

      final overall = await db.query(
        DbSchema.tAssessmentSummary,
        columns: [DbSchema.cSumOverallInterpretation],
        where: '${DbSchema.cSumAssessId}=?',
        whereArgs: [assessId],
        limit: 1,
      );
      if (overall.isNotEmpty) {
        final finalLevel =
            (overall.first[DbSchema.cSumOverallInterpretation] ?? '')
                .toString();
        counts['ALL']![gender]![finalLevel] =
            (counts['ALL']![gender]![finalLevel] ?? 0) + 1;
        counts['ALL']!['ALL']![finalLevel] =
            (counts['ALL']!['ALL']![finalLevel] ?? 0) + 1;
      }

      // Skill frequency (for SKILL rows)
      for (final d in _domains) {
        skillTotalLearners[d] = (skillTotalLearners[d] ?? 0) + 1;
      }
      final answers = await db.query(
        DbSchema.tAnswers,
        where: '${DbSchema.cAnsAssessId}=?',
        whereArgs: [assessId],
      );
      for (final a in answers) {
        final rawDomain = a[DbSchema.cAnsDomain] as String;
        final domain = _normalizeDomain(rawDomain);
        if (!_domains.contains(domain)) continue;
        final idx = _normalizeSelfHelpSkillIndex(
          rawDomain,
          a[DbSchema.cAnsIndex] as int,
        );
        final val = a[DbSchema.cAnsValue] as int;
        if (val == 1) {
          skillChecked[domain]![idx] = (skillChecked[domain]![idx] ?? 0) + 1;
        }
      }
    }

    final meta = <List<dynamic>>[
      [RollupCsvSchema.metaMarker, 'ORG_LEVEL', 'teacher'],
      [
        RollupCsvSchema.metaMarker,
        'SCHOOL_YEAR',
        classRow[DbSchema.cClassSchoolYear] as String,
      ],
      [
        RollupCsvSchema.metaMarker,
        'SCHOOL',
        (teacherRow[DbSchema.cUserSchool] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'DISTRICT',
        (teacherRow[DbSchema.cUserDistrict] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'DIVISION',
        (teacherRow[DbSchema.cUserDivision] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'REGION',
        (teacherRow[DbSchema.cUserRegion] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'GRADE',
        (classRow[DbSchema.cClassGrade] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'SECTION',
        (classRow[DbSchema.cClassSection] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'DATE_GENERATED',
        DateTime.now().toIso8601String(),
      ],
    ];

    final data = <List<dynamic>>[
      [RollupCsvSchema.dataMarker, ...RollupCsvSchema.dataHeader],
    ];

    for (final domain in _allDomainsPlusAll()) {
      for (final gender in const ['M', 'F', 'ALL']) {
        for (final level in _levels) {
          final c = counts[domain]![gender]![level] ?? 0;
          data.add([
            RollupCsvSchema.dataMarker,
            assessmentType,
            domain,
            gender,
            level,
            c,
          ]);
        }
      }
    }

    // Skill block (additive, backward compatible)
    final skill = <List<dynamic>>[
      [RollupCsvSchema.skillMarker, ...RollupCsvSchema.skillHeader],
    ];
    for (final domain in _domains) {
      final qs = EccdQuestions.get(domain, languageForSkills);
      final total = skillTotalLearners[domain] ?? 0;
      for (int i = 0; i < qs.length; i++) {
        final checked = skillChecked[domain]![i] ?? 0;
        skill.add([
          RollupCsvSchema.skillMarker,
          assessmentType,
          domain,
          i,
          qs[i],
          checked,
          total,
        ]);
      }
    }

    return _conv.convert([...meta, ...data, ...skill]);
  }

  /// Admin: ingest canonical rollup csv as a new data source (active)
  /// Supports both DATA and SKILL blocks.
  Future<void> ingestRollupCsv({
    required int adminId,
    required String orgLevel, // teacher|principal|district|division|regional
    required String csvText,
  }) async {
    final db = AppDb.instance.db;

    final rows = _parser.convert(csvText);
    if (rows.isEmpty) throw FormatException('CSV is empty');

    String? schoolYear;

    // Parse META block
    for (final r in rows) {
      if (r.isEmpty) continue;
      if (r[0]?.toString() != RollupCsvSchema.metaMarker) continue;
      final key = r.length > 1 ? r[1].toString() : '';
      final val = r.length > 2 ? r[2].toString() : '';
      if (key == 'SCHOOL_YEAR') schoolYear = val;
    }
    if (schoolYear == null || schoolYear.trim().isEmpty) {
      throw FormatException('CSV missing SCHOOL_YEAR');
    }
    schoolYear = schoolYear.trim();

    final sourceId = await db.insert(DbSchema.tRollupSources, {
      DbSchema.cSrcAdminId: adminId,
      DbSchema.cSrcSchoolYear: schoolYear,
      DbSchema.cSrcStatus: 'active',
      DbSchema.cSrcLevel: orgLevel.trim(),
      DbSchema.cSrcCreatedAt: DateTime.now().toIso8601String(),
    });

    bool seenDataHeader = false;
    bool seenSkillHeader = false;

    for (final r in rows) {
      if (r.isEmpty) continue;
      final marker = r[0]?.toString();

      // DATA
      if (marker == RollupCsvSchema.dataMarker) {
        if (!seenDataHeader) {
          seenDataHeader = true;
          continue; // header row
        }
        if (r.length < 6) continue;
        final type = r[1].toString().trim();
        final domain = r[2].toString().trim();
        final gender = r[3].toString().trim();
        final level = r[4].toString().trim();
        final count = int.tryParse(r[5].toString().trim()) ?? 0;

        await db.insert(DbSchema.tRollupRows, {
          DbSchema.cRowSourceId: sourceId,
          DbSchema.cRowAssessmentType: type,
          DbSchema.cRowDomain: domain,
          DbSchema.cRowGender: gender,
          DbSchema.cRowLevel: level,
          DbSchema.cRowCount: count,
        });
        continue;
      }

      // SKILL
      if (marker == RollupCsvSchema.skillMarker) {
        if (!seenSkillHeader) {
          seenSkillHeader = true;
          continue;
        }
        if (r.length < 7) continue;
        final type = r[1].toString().trim();
        final domain = r[2].toString().trim();
        final skillIndex = int.tryParse(r[3].toString().trim()) ?? 0;
        final skillText = r[4].toString().trim();
        final checked = int.tryParse(r[5].toString().trim()) ?? 0;
        final total = int.tryParse(r[6].toString().trim()) ?? 0;

        await db.insert(DbSchema.tRollupSkillRows, {
          DbSchema.cSkillRowSourceId: sourceId,
          DbSchema.cSkillRowAssessmentType: type,
          DbSchema.cSkillRowDomain: domain,
          DbSchema.cSkillRowSkillIndex: skillIndex,
          DbSchema.cSkillRowSkillText: skillText,
          DbSchema.cSkillRowCheckedCount: checked,
          DbSchema.cSkillRowTotalLearners: total,
        });
      }
    }
  }

  Future<List<Map<String, Object?>>> listAdminSources(
    int adminId, {
    bool archived = false,
    String? schoolYear,
  }) async {
    final db = AppDb.instance.db;
    final status = archived ? 'archived' : 'active';

    final where = StringBuffer(
      '${DbSchema.cSrcAdminId}=? AND ${DbSchema.cSrcStatus}=?',
    );
    final args = <Object?>[adminId, status];
    if (schoolYear != null && schoolYear.trim().isNotEmpty) {
      where.write(' AND TRIM(${DbSchema.cSrcSchoolYear})=?');
      args.add(schoolYear.trim());
    }

    return db.query(
      DbSchema.tRollupSources,
      where: where.toString(),
      whereArgs: args,
      orderBy: '${DbSchema.cSrcCreatedAt} DESC',
    );
  }

  Future<List<String>> listAdminSchoolYears(int adminId) async {
    final rows = await listAdminSources(adminId, archived: false);
    final seen = <String>{};
    final out = <String>[];
    for (final r in rows) {
      final sy = (r[DbSchema.cSrcSchoolYear] ?? '').toString().trim();
      if (sy.isEmpty || seen.contains(sy)) continue;
      seen.add(sy);
      out.add(sy);
    }
    out.sort((a, b) => b.compareTo(a));
    return out;
  }

  Future<void> archiveSource(int sourceId) async {
    final db = AppDb.instance.db;
    await db.update(
      DbSchema.tRollupSources,
      {DbSchema.cSrcStatus: 'archived'},
      where: '${DbSchema.cSrcId}=?',
      whereArgs: [sourceId],
    );
  }

  Future<void> unarchiveSource(int sourceId) async {
    final db = AppDb.instance.db;
    await db.update(
      DbSchema.tRollupSources,
      {DbSchema.cSrcStatus: 'active'},
      where: '${DbSchema.cSrcId}=?',
      whereArgs: [sourceId],
    );
  }

  /// Admin: aggregate all ACTIVE sources into domain x gender x level totals
  Future<Map<String, Map<String, Map<String, int>>>> aggregateAdminRollup({
    required int adminId,
    required String assessmentType, // pre|post
    String? schoolYear,
  }) async {
    final db = AppDb.instance.db;

    final sources = await listAdminSources(
      adminId,
      archived: false,
      schoolYear: schoolYear,
    );
    if (sources.isEmpty) return _emptyAgg();

    final sourceIds = sources.map((s) => s[DbSchema.cSrcId] as int).toList();
    final placeholders = List.filled(sourceIds.length, '?').join(',');

    final rows = await db.rawQuery(
      '''
SELECT ${DbSchema.cRowDomain} as domain,
       ${DbSchema.cRowGender} as gender,
       ${DbSchema.cRowLevel} as level,
       SUM(${DbSchema.cRowCount}) as total
FROM ${DbSchema.tRollupRows}
WHERE ${DbSchema.cRowSourceId} IN ($placeholders)
  AND ${DbSchema.cRowAssessmentType} = ?
GROUP BY domain, gender, level
''',
      [...sourceIds, assessmentType],
    );

    final agg = _emptyAgg();

    for (final r in rows) {
      final domain = _normalizeDomain(r['domain'].toString());
      final gender = r['gender'].toString();
      final level = r['level'].toString();
      final total = (r['total'] as int?) ?? 0;
      if (!agg.containsKey(domain)) continue;
      if (!agg[domain]!.containsKey(gender)) continue;
      agg[domain]![gender]![level] = total;
    }

    return agg;
  }

  /// Admin: aggregate skill frequencies across ACTIVE sources
  Future<Map<String, List<Map<String, Object?>>>> aggregateAdminSkills({
    required int adminId,
    required String assessmentType,
    String? schoolYear,
  }) async {
    final db = AppDb.instance.db;
    final sources = await listAdminSources(
      adminId,
      archived: false,
      schoolYear: schoolYear,
    );
    if (sources.isEmpty) return {};

    final sourceIds = sources.map((s) => s[DbSchema.cSrcId] as int).toList();
    final placeholders = List.filled(sourceIds.length, '?').join(',');

    // We sum checked_count and total_learners for same domain+skill_index+skill_text
    final rows = await db.rawQuery(
      '''
SELECT ${DbSchema.cSkillRowDomain} as domain,
       ${DbSchema.cSkillRowSkillIndex} as skill_index,
       ${DbSchema.cSkillRowSkillText} as skill_text,
       SUM(${DbSchema.cSkillRowCheckedCount}) as checked_sum,
       SUM(${DbSchema.cSkillRowTotalLearners}) as total_sum
FROM ${DbSchema.tRollupSkillRows}
WHERE ${DbSchema.cSkillRowSourceId} IN ($placeholders)
  AND ${DbSchema.cSkillRowAssessmentType} = ?
GROUP BY domain, skill_index, skill_text
''',
      [...sourceIds, assessmentType],
    );

    final out = <String, List<Map<String, Object?>>>{};
    for (final r in rows) {
      final domain = _normalizeDomain(r['domain'].toString());
      out.putIfAbsent(domain, () => []);
      out[domain]!.add({
        'domain': domain,
        'skill_index': r['skill_index'],
        'skill_text': r['skill_text'],
        'checked_sum': r['checked_sum'],
        'total_sum': r['total_sum'],
      });
    }
    return out;
  }

  /// Admin: export aggregated rollup to canonical CSV (forward upward)
  /// Includes SKILL block for Top3 at higher levels too.
  Future<String> exportAdminAggregatedRollupCsv({
    required int adminId,
    required String orgLevel, // principal|district|division|regional
    required String assessmentType,
    String? schoolYear,
  }) async {
    final db = AppDb.instance.db;
    final adminRow = (await db.query(
      DbSchema.tUsers,
      where: '${DbSchema.cUserId}=?',
      whereArgs: [adminId],
      limit: 1,
    )).first;

    final resolvedSchoolYear = await _resolveAdminSchoolYearMeta(
      adminId: adminId,
      selectedSchoolYear: schoolYear,
    );

    final agg = await aggregateAdminRollup(
      adminId: adminId,
      assessmentType: assessmentType,
      schoolYear: schoolYear,
    );

    final meta = <List<dynamic>>[
      [RollupCsvSchema.metaMarker, 'ORG_LEVEL', orgLevel.trim()],
      [RollupCsvSchema.metaMarker, 'SCHOOL_YEAR', resolvedSchoolYear],
      [
        RollupCsvSchema.metaMarker,
        'SCHOOL',
        (adminRow[DbSchema.cUserSchool] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'DISTRICT',
        (adminRow[DbSchema.cUserDistrict] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'DIVISION',
        (adminRow[DbSchema.cUserDivision] ?? '').toString(),
      ],
      [
        RollupCsvSchema.metaMarker,
        'REGION',
        (adminRow[DbSchema.cUserRegion] ?? '').toString(),
      ],
      [RollupCsvSchema.metaMarker, 'GRADE', ''],
      [RollupCsvSchema.metaMarker, 'SECTION', ''],
      [
        RollupCsvSchema.metaMarker,
        'DATE_GENERATED',
        DateTime.now().toIso8601String(),
      ],
    ];

    final data = <List<dynamic>>[
      [RollupCsvSchema.dataMarker, ...RollupCsvSchema.dataHeader],
    ];

    for (final domain in _allDomainsPlusAll()) {
      for (final gender in const ['M', 'F', 'ALL']) {
        for (final level in _levels) {
          final c = agg[domain]![gender]![level] ?? 0;
          data.add([
            RollupCsvSchema.dataMarker,
            assessmentType,
            domain,
            gender,
            level,
            c,
          ]);
        }
      }
    }

    // aggregate skills across sources
    final skills = await aggregateAdminSkills(
      adminId: adminId,
      assessmentType: assessmentType,
      schoolYear: schoolYear,
    );

    final skillBlock = <List<dynamic>>[
      [RollupCsvSchema.skillMarker, ...RollupCsvSchema.skillHeader],
    ];

    for (final domain in _domains) {
      final rows = skills[domain] ?? [];
      // if no rows, just skip
      for (final r in rows) {
        skillBlock.add([
          RollupCsvSchema.skillMarker,
          assessmentType,
          domain,
          r['skill_index'],
          r['skill_text'],
          r['checked_sum'],
          r['total_sum'],
        ]);
      }
    }

    return _conv.convert([...meta, ...data, ...skillBlock]);
  }

  // ---------- helpers ----------
  Future<String> buildAdminRollupFilename({
    required int adminId,
    required String orgLevel,
    required String assessmentType,
    String? schoolYear,
  }) async {
    final db = AppDb.instance.db;
    final adminRow = (await db.query(
      DbSchema.tUsers,
      where: '${DbSchema.cUserId}=?',
      whereArgs: [adminId],
      limit: 1,
    )).first;

    final resolvedSchoolYear = await _resolveAdminSchoolYearMeta(
      adminId: adminId,
      selectedSchoolYear: schoolYear,
    );

    final region = _slug((adminRow[DbSchema.cUserRegion] ?? '').toString());
    final division = _slug((adminRow[DbSchema.cUserDivision] ?? '').toString());
    final district = _slug((adminRow[DbSchema.cUserDistrict] ?? '').toString());
    final level = _slug(orgLevel);
    final sy = _slug(resolvedSchoolYear);
    final type = _slug(assessmentType);

    return 'rollup_${level}_${sy}_${region}_${division}_${district}_${type}';
  }

  String _slug(String raw) {
    final x = raw.trim().toLowerCase();
    if (x.isEmpty) return 'na';
    final cleaned = x.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return cleaned
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<String> _resolveAdminSchoolYearMeta({
    required int adminId,
    String? selectedSchoolYear,
  }) async {
    final selected = (selectedSchoolYear ?? '').trim();
    if (selected.isNotEmpty) return selected;

    final active = await listAdminSources(adminId, archived: false);
    final years = <String>{};
    for (final row in active) {
      final sy = (row[DbSchema.cSrcSchoolYear] ?? '').toString().trim();
      if (sy.isNotEmpty) years.add(sy);
    }
    if (years.isEmpty) return 'ALL_ACTIVE';
    final ordered = years.toList()..sort();
    return ordered.join(', ');
  }

  Map<String, Map<String, Map<String, int>>> _emptyAgg() {
    final out = <String, Map<String, Map<String, int>>>{};
    for (final d in _allDomainsPlusAll()) {
      out[d] = {
        'M': _levelMapZero(),
        'F': _levelMapZero(),
        'ALL': _levelMapZero(),
      };
    }
    return out;
  }
}
