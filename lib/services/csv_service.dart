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

  // ──────────────────────────────────────────────────────────────────────────
  // VISUAL CSV HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Creates a 30-element row with given values at specific column positions.
  List<dynamic> _r30(Map<int, dynamic> vals) {
    final row = List<dynamic>.filled(30, '');
    vals.forEach((i, v) => row[i] = v);
    return row;
  }

  /// Compute Top-3 most/least skill texts from raw skill frequency maps.
  Map<String, Map<String, List<String>>> _computeTop3Skills({
    required Map<String, Map<int, int>> skillChecked,
    required Map<String, int> skillTotalLearners,
    required EccdLanguage language,
  }) {
    final out = <String, Map<String, List<String>>>{};
    for (final domain in _domains) {
      final qs = EccdQuestions.get(domain, language);
      final total = skillTotalLearners[domain] ?? 0;

      final ranked = List.generate(qs.length, (i) {
        final checked = skillChecked[domain]?[i] ?? 0;
        final pct = total == 0 ? 0.0 : checked / total;
        return MapEntry(i, pct);
      })..sort((a, b) => b.value.compareTo(a.value));

      final most = ranked.take(3).map((e) => qs[e.key]).toList();

      final leastRanked = [...ranked]
        ..sort((a, b) => a.value.compareTo(b.value));
      final least = leastRanked.take(3).map((e) => qs[e.key]).toList();

      out[domain] = {'most': most, 'least': least};
    }
    return out;
  }

  /// Compute Top-3 most/least skill texts from aggregated admin skill rows.
  Map<String, Map<String, List<String>>> _computeTop3SkillsFromAggregated(
    Map<String, List<Map<String, Object?>>> aggregated,
  ) {
    final out = <String, Map<String, List<String>>>{};
    for (final domain in _domains) {
      final rows = aggregated[domain] ?? [];
      if (rows.isEmpty) {
        out[domain] = {'most': [], 'least': []};
        continue;
      }

      double pct(Map<String, Object?> r) {
        final t = (r['total_sum'] as int?) ?? 0;
        final c = (r['checked_sum'] as int?) ?? 0;
        return t == 0 ? 0.0 : c / t;
      }

      final sorted = [...rows]..sort((a, b) => pct(b).compareTo(pct(a)));
      final most = sorted
          .take(3)
          .map((r) => r['skill_text'].toString())
          .toList();
      final leastSorted = [...rows]..sort((a, b) => pct(a).compareTo(pct(b)));
      final least = leastSorted
          .take(3)
          .map((r) => r['skill_text'].toString())
          .toList();
      out[domain] = {'most': most, 'least': least};
    }
    return out;
  }

  /// Build the 30-column visual CSV section matching the DepEd BOSY/EOSY form.
  List<List<dynamic>> _buildVisualRows({
    required String assessmentType,
    required String schoolYear,
    required String region,
    required String division,
    required Map<String, Map<String, Map<String, int>>> counts,
    required Map<String, Map<String, List<String>>> top3Skills,
  }) {
    final rows = <List<dynamic>>[];

    final label = assessmentType == 'pre'
        ? 'BEGINNING OF THE SCHOOL YEAR (BOSY) EARLY CHILDHOOD DEVELOPMENT ASSESSMENT'
        : 'END OF THE SCHOOL YEAR (EOSY) EARLY CHILDHOOD DEVELOPMENT ASSESSMENT';

    final regionLabel = region.isNotEmpty ? region.toUpperCase() : 'REGION';
    final divisionLabel = division.isNotEmpty
        ? division.toUpperCase()
        : 'SCHOOLS DIVISION OFFICE';

    // ── Header ──
    rows.add(List.filled(30, ''));
    rows.add(_r30({0: 'Department of Education'}));
    rows.add(_r30({0: regionLabel}));
    rows.add(_r30({0: divisionLabel}));
    rows.add(_r30({0: label}));
    rows.add(_r30({0: 'SY $schoolYear'}));
    rows.add(List.filled(30, ''));

    // ── "Summary" label (at column 10) ──
    rows.add(_r30({10: 'Summary '}));

    // ── Domain column headers ──
    rows.add(
      _r30({
        0: 'Level of Development',
        2: 'GROSS MOTOR',
        5: 'FINE MOTOR',
        8: 'SELF-HELP',
        11: 'RECEPTIVE LANGUAGE',
        14: 'EXPRESSIVE LANGUAGE',
        17: 'COGNITIVE',
        20: 'SOCIO EMOTIONAL',
        25: 'GRAND TOTAL',
      }),
    );

    // ── M / F / TOTAL sub-header ──
    // SE has a blank at col 22; GT has blanks at 26 and 28.
    rows.add(
      _r30({
        2: 'M', 3: 'F', 4: 'TOTAL',
        5: 'M', 6: 'F', 7: 'TOTAL',
        8: 'M', 9: 'F', 10: 'TOTAL',
        11: 'M', 12: 'F', 13: 'TOTAL',
        14: 'M', 15: 'F', 16: 'TOTAL',
        17: 'M', 18: 'F', 19: 'TOTAL',
        20: 'M', 21: 'F', 23: 'TOTAL', // col 22 intentionally blank
        25: 'M', 27: 'F', 29: 'TOTAL', // cols 26,28 intentionally blank
      }),
    );

    // Standard domain → starting M column (M, F, Total in consecutive cols)
    const stdDomainCol = {
      'Gross Motor': 2,
      'Fine Motor': 5,
      'Self Help': 8,
      'Receptive Language': 11,
      'Expressive Language': 14,
      'Cognitive': 17,
    };

    const levelFullNames = {
      'SSDD': 'Suggested Significant Delay in Overall Development (SSDD)',
      'SSLDD': 'Suggested Slight Delay in Overall Development (SSLDD)',
      'AD': 'Average Development (AD)',
      'SSAD': 'Suggest Slightly Advance Development (SSAD)',
      'SHAD': 'Suggest Highly Advanced Development (SHAD)',
    };

    // ── Level data rows ──
    for (final level in _levels) {
      final vals = <int, dynamic>{0: levelFullNames[level] ?? level};

      for (final e in stdDomainCol.entries) {
        final m = counts[e.key]?['M']?[level] ?? 0;
        final f = counts[e.key]?['F']?[level] ?? 0;
        vals[e.value] = m;
        vals[e.value + 1] = f;
        vals[e.value + 2] = m + f;
      }

      final seM = counts['Social Emotional']?['M']?[level] ?? 0;
      final seF = counts['Social Emotional']?['F']?[level] ?? 0;
      vals[20] = seM;
      vals[21] = seF;
      vals[23] = seM + seF; // col 22 blank

      final gtM = counts['ALL']?['M']?[level] ?? 0;
      final gtF = counts['ALL']?['F']?[level] ?? 0;
      vals[25] = gtM; // col 26 blank
      vals[27] = gtF; // col 28 blank
      vals[29] = gtM + gtF;

      rows.add(_r30(vals));
    }

    // ── TOTAL row ──
    final totVals = <int, dynamic>{0: 'TOTAL'};
    for (final e in stdDomainCol.entries) {
      final m = _levels.fold(0, (a, l) => a + (counts[e.key]?['M']?[l] ?? 0));
      final f = _levels.fold(0, (a, l) => a + (counts[e.key]?['F']?[l] ?? 0));
      totVals[e.value] = m;
      totVals[e.value + 1] = f;
      totVals[e.value + 2] = m + f;
    }
    final seMT = _levels.fold(
      0,
      (a, l) => a + (counts['Social Emotional']?['M']?[l] ?? 0),
    );
    final seFT = _levels.fold(
      0,
      (a, l) => a + (counts['Social Emotional']?['F']?[l] ?? 0),
    );
    totVals[20] = seMT;
    totVals[21] = seFT;
    totVals[23] = seMT + seFT;
    final gtMT = _levels.fold(0, (a, l) => a + (counts['ALL']?['M']?[l] ?? 0));
    final gtFT = _levels.fold(0, (a, l) => a + (counts['ALL']?['F']?[l] ?? 0));
    totVals[25] = gtMT;
    totVals[27] = gtFT;
    totVals[29] = gtMT + gtFT;
    rows.add(_r30(totVals));

    // ── Gap before skills sections ──
    for (int i = 0; i < 5; i++) rows.add(List.filled(30, ''));

    // Domain column positions in the skills section (each domain uses 3 cols)
    const skillCol = {
      'Gross Motor': 0,
      'Fine Motor': 3,
      'Self Help': 6,
      'Receptive Language': 9,
      'Expressive Language': 12,
      'Cognitive': 15,
      'Social Emotional': 18,
    };
    const skillDisplayName = {
      'Gross Motor': 'Gross Motor',
      'Fine Motor': 'Fine Motor',
      'Self Help': 'Self-Help',
      'Receptive Language': 'Receptive Language',
      'Expressive Language': 'Expressive Language',
      'Cognitive': 'Cognitive Domain',
      'Social Emotional': 'Social Emotional',
    };

    // ── Most Learned section ──
    final mostHdr = <int, dynamic>{};
    final leastHdr = <int, dynamic>{};
    for (final d in _domains) {
      final c = skillCol[d]!;
      mostHdr[c] =
          'What are the Three Most Learned Skills in ${skillDisplayName[d]}? ';
      leastHdr[c] =
          'What are the Three Least Mastered Skills in ${skillDisplayName[d]}? ';
    }
    rows.add(_r30(mostHdr));
    for (int i = 0; i < 3; i++) {
      final r = <int, dynamic>{};
      for (final d in _domains) {
        final c = skillCol[d]!;
        final list = top3Skills[d]?['most'] ?? [];
        r[c] = i < list.length ? list[i] : '';
      }
      rows.add(_r30(r));
    }
    for (int i = 0; i < 6; i++) rows.add(List.filled(30, ''));

    // ── Least Mastered section ──
    rows.add(_r30(leastHdr));
    for (int i = 0; i < 3; i++) {
      final r = <int, dynamic>{};
      for (final d in _domains) {
        final c = skillCol[d]!;
        final list = top3Skills[d]?['least'] ?? [];
        r[c] = i < list.length ? list[i] : '';
      }
      rows.add(_r30(r));
    }
    for (int i = 0; i < 6; i++) rows.add(List.filled(30, ''));

    // ── Signature section 2 ──
    rows.add(_r30({1: 'Prepared:', 9: 'Verified:', 17: 'NOTED:'}));
    for (int i = 0; i < 2; i++) rows.add(List.filled(30, ''));
    rows.add(
      _r30({
        1: ' Kindergarten Teacher',
        9: 'Master Teacher/ Kindergarten Coordinator',
        17: 'School Head',
      }),
    );

    return rows;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TEACHER EXPORT
  // ──────────────────────────────────────────────────────────────────────────

  /// Gather all data needed for a teacher class rollup export.
  /// Shared by both CSV and XLSX teacher export methods.
  Future<
    ({
      Map<String, Map<String, Map<String, int>>> counts,
      Map<String, Map<String, List<String>>> top3Skills,
      Map<String, Map<int, int>> skillChecked,
      Map<String, int> skillTotalLearners,
      String schoolYear,
      String school,
      String district,
      String division,
      String region,
      String grade,
      String section,
    })
  >
  gatherTeacherRollupData({
    required int teacherId,
    required int classId,
    required String assessmentType,
    required EccdLanguage languageForSkills,
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

    final learners = await db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [classId, 'active'],
    );

    final counts = <String, Map<String, Map<String, int>>>{};
    for (final domain in _allDomainsPlusAll()) {
      counts[domain] = {
        'M': _levelMapZero(),
        'F': _levelMapZero(),
        'ALL': _levelMapZero(),
      };
    }

    final skillChecked = <String, Map<int, int>>{
      for (final d in _domains) d: {},
    };
    final skillTotalLearners = <String, int>{for (final d in _domains) d: 0};

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
          'Cannot export: not all learners have saved ${assessmentTypeDisplay(assessmentType)} assessments.',
        );
      }

      final assessId = assess.first[DbSchema.cAssessId] as int;

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
        if ((a[DbSchema.cAnsValue] as int) == 1) {
          skillChecked[domain]![idx] = (skillChecked[domain]![idx] ?? 0) + 1;
        }
      }
    }

    final top3 = _computeTop3Skills(
      skillChecked: skillChecked,
      skillTotalLearners: skillTotalLearners,
      language: languageForSkills,
    );

    return (
      counts: counts,
      top3Skills: top3,
      skillChecked: skillChecked,
      skillTotalLearners: skillTotalLearners,
      schoolYear: (classRow[DbSchema.cClassSchoolYear] ?? '').toString(),
      school: (teacherRow[DbSchema.cUserSchool] ?? '').toString(),
      district: (teacherRow[DbSchema.cUserDistrict] ?? '').toString(),
      division: (teacherRow[DbSchema.cUserDivision] ?? '').toString(),
      region: (teacherRow[DbSchema.cUserRegion] ?? '').toString(),
      grade: (classRow[DbSchema.cClassGrade] ?? '').toString(),
      section: (classRow[DbSchema.cClassSection] ?? '').toString(),
    );
  }

  /// Teacher: export class rollup summary as hybrid CSV.
  ///
  /// The file contains:
  ///   1. Visual section — matches the DepEd BOSY/EOSY form layout.
  ///   2. Machine-readable section — META / DATA / SKILL rows appended at the
  ///      end, enabling admins to import and consolidate without re-typing.
  Future<String> exportTeacherClassRollupCsv({
    required int teacherId,
    required int classId,
    required String assessmentType, // pre|post
    required EccdLanguage languageForSkills,
  }) async {
    final rd = await gatherTeacherRollupData(
      teacherId: teacherId,
      classId: classId,
      assessmentType: assessmentType,
      languageForSkills: languageForSkills,
    );

    // ── Visual section ──
    final visualRows = _buildVisualRows(
      assessmentType: assessmentType,
      schoolYear: rd.schoolYear,
      region: rd.region,
      division: rd.division,
      counts: rd.counts,
      top3Skills: rd.top3Skills,
    );

    // ── Machine-readable META block ──
    final meta = <List<dynamic>>[
      [RollupCsvSchema.metaMarker, 'ORG_LEVEL', 'teacher'],
      [RollupCsvSchema.metaMarker, 'SCHOOL_YEAR', rd.schoolYear],
      [RollupCsvSchema.metaMarker, 'SCHOOL', rd.school],
      [RollupCsvSchema.metaMarker, 'DISTRICT', rd.district],
      [RollupCsvSchema.metaMarker, 'DIVISION', rd.division],
      [RollupCsvSchema.metaMarker, 'REGION', rd.region],
      [RollupCsvSchema.metaMarker, 'GRADE', rd.grade],
      [RollupCsvSchema.metaMarker, 'SECTION', rd.section],
      [
        RollupCsvSchema.metaMarker,
        'DATE_GENERATED',
        DateTime.now().toIso8601String(),
      ],
    ];

    // ── Machine-readable DATA block ──
    final dataBlock = <List<dynamic>>[
      [RollupCsvSchema.dataMarker, ...RollupCsvSchema.dataHeader],
    ];
    for (final domain in _allDomainsPlusAll()) {
      for (final gender in const ['M', 'F', 'ALL']) {
        for (final level in _levels) {
          final c = rd.counts[domain]![gender]![level] ?? 0;
          dataBlock.add([
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

    // ── Machine-readable SKILL block ──
    final skillBlock = <List<dynamic>>[
      [RollupCsvSchema.skillMarker, ...RollupCsvSchema.skillHeader],
    ];
    for (final domain in _domains) {
      final qs = EccdQuestions.get(domain, languageForSkills);
      final total = rd.skillTotalLearners[domain] ?? 0;
      for (int i = 0; i < qs.length; i++) {
        final checked = rd.skillChecked[domain]![i] ?? 0;
        skillBlock.add([
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

    return _conv.convert([...visualRows, ...meta, ...dataBlock, ...skillBlock]);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ADMIN IMPORT
  // ──────────────────────────────────────────────────────────────────────────

  /// Admin: ingest canonical rollup csv as a new data source (active).
  /// Supports both DATA and SKILL blocks.
  /// Visual rows (DepEd form layout) are automatically ignored by the parser.
  String _sourceLabelFromMeta(String level, Map<String, String> meta) {
    String v(String key) => meta[key] ?? '';
    switch (level) {
      case 'teacher':
        final grade = v('GRADE');
        final section = v('SECTION');
        if (grade.isNotEmpty && section.isNotEmpty) return '$grade - $section';
        if (section.isNotEmpty) return section;
        if (grade.isNotEmpty) return grade;
        return '';
      case 'school':
        return v('SCHOOL');
      case 'district':
        return v('DISTRICT');
      case 'division':
        return v('DIVISION');
      case 'regional':
        return v('REGION');
      default:
        return '';
    }
  }

  Future<void> ingestRollupCsv({
    required int adminId,
    required String orgLevel, // teacher|school|district|division|regional
    required String csvText,
  }) async {
    final db = AppDb.instance.db;

    final rows = _parser.convert(csvText);
    if (rows.isEmpty) throw FormatException('CSV is empty');

    String? schoolYear;
    final meta = <String, String>{};

    // Parse META block
    for (final r in rows) {
      if (r.isEmpty) continue;
      if (r[0]?.toString() != RollupCsvSchema.metaMarker) continue;
      final key = r.length > 1 ? r[1].toString().trim() : '';
      final val = r.length > 2 ? r[2].toString().trim() : '';
      meta[key] = val;
      if (key == 'SCHOOL_YEAR') schoolYear = val;
    }
    if (schoolYear == null || schoolYear.trim().isEmpty) {
      throw FormatException('CSV missing SCHOOL_YEAR');
    }
    schoolYear = schoolYear.trim();

    final level = orgLevel.trim();
    final label = _sourceLabelFromMeta(level, meta);

    final sourceId = await db.insert(DbSchema.tRollupSources, {
      DbSchema.cSrcAdminId: adminId,
      DbSchema.cSrcSchoolYear: schoolYear,
      DbSchema.cSrcStatus: 'active',
      DbSchema.cSrcLevel: level,
      DbSchema.cSrcLabel: label,
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
      if (sy.isEmpty || seen.contains(sy) || !_isAllowedSchoolYear(sy)) {
        continue;
      }
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

  /// Single source: aggregate rollup rows for one data source.
  Future<Map<String, Map<String, Map<String, int>>>> getSingleSourceRollup({
    required int sourceId,
    required String assessmentType,
  }) async {
    final db = AppDb.instance.db;
    final rows = await db.rawQuery(
      '''
SELECT ${DbSchema.cRowDomain} as domain,
       ${DbSchema.cRowGender} as gender,
       ${DbSchema.cRowLevel} as level,
       SUM(${DbSchema.cRowCount}) as total
FROM ${DbSchema.tRollupRows}
WHERE ${DbSchema.cRowSourceId} = ? AND ${DbSchema.cRowAssessmentType} = ?
GROUP BY domain, gender, level
''',
      [sourceId, assessmentType],
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

  /// Single source: aggregate skill rows for one data source.
  Future<Map<String, List<Map<String, Object?>>>> getSingleSourceSkills({
    required int sourceId,
    required String assessmentType,
  }) async {
    final db = AppDb.instance.db;
    final rows = await db.rawQuery(
      '''
SELECT ${DbSchema.cSkillRowDomain} as domain,
       ${DbSchema.cSkillRowSkillIndex} as skill_index,
       ${DbSchema.cSkillRowSkillText} as skill_text,
       SUM(${DbSchema.cSkillRowCheckedCount}) as checked_sum,
       SUM(${DbSchema.cSkillRowTotalLearners}) as total_sum
FROM ${DbSchema.tRollupSkillRows}
WHERE ${DbSchema.cSkillRowSourceId} = ? AND ${DbSchema.cSkillRowAssessmentType} = ?
GROUP BY domain, skill_index, skill_text
''',
      [sourceId, assessmentType],
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

  // ──────────────────────────────────────────────────────────────────────────
  // ADMIN EXPORT
  // ──────────────────────────────────────────────────────────────────────────

  /// Admin: export aggregated rollup as hybrid CSV (visual + machine-readable).
  Future<String> exportAdminAggregatedRollupCsv({
    required int adminId,
    required String orgLevel, // school|district|division|regional
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

    // aggregate skills across sources
    final skills = await aggregateAdminSkills(
      adminId: adminId,
      assessmentType: assessmentType,
      schoolYear: schoolYear,
    );

    // ── Compute top-3 for visual section ──
    final top3 = _computeTop3SkillsFromAggregated(skills);

    // ── Visual section ──
    final visualRows = _buildVisualRows(
      assessmentType: assessmentType,
      schoolYear: resolvedSchoolYear,
      region: (adminRow[DbSchema.cUserRegion] ?? '').toString(),
      division: (adminRow[DbSchema.cUserDivision] ?? '').toString(),
      counts: agg,
      top3Skills: top3,
    );

    // ── Machine-readable META block ──
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

    // ── Machine-readable DATA block ──
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

    // ── Machine-readable SKILL block ──
    final skillBlock = <List<dynamic>>[
      [RollupCsvSchema.skillMarker, ...RollupCsvSchema.skillHeader],
    ];

    for (final domain in _domains) {
      final rows = skills[domain] ?? [];
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

    return _conv.convert([...visualRows, ...meta, ...data, ...skillBlock]);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

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

  bool _isAllowedSchoolYear(String schoolYear) {
    final match = RegExp(r'^(\d{4})-\d{4}$').firstMatch(schoolYear.trim());
    if (match == null) return false;
    final startYear = int.tryParse(match.group(1)!);
    if (startYear == null) return false;
    return startYear >= 2020 && startYear <= DateTime.now().year;
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
