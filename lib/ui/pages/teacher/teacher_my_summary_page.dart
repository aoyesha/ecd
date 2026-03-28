import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../data/eccd_questions.dart';
import '../../../services/analytics_service.dart';
import '../../../services/class_service.dart';
import '../../../services/scoring_service.dart';
import '../../widgets/section_title.dart';

class TeacherMySummaryPage extends StatefulWidget {
  final int teacherId;

  const TeacherMySummaryPage({super.key, required this.teacherId});

  @override
  State<TeacherMySummaryPage> createState() => _TeacherMySummaryPageState();
}

class _TeacherMySummaryPageState extends State<TeacherMySummaryPage> {
  final _classes = ClassService();
  final _analytics = AnalyticsService();

  String assessmentType = 'pre';
  EccdLanguage language = EccdLanguage.english;
  String? schoolYearFilter;
  int? classIdFilter;
  String topDomainFilter = 'Gross Motor';

  static const _domains = [
    'Gross Motor',
    'Fine Motor',
    'Self Help',
    'Receptive Language',
    'Expressive Language',
    'Cognitive',
    'Social Emotional',
  ];

  Future<List<Map<String, Object?>>> _activeClasses() {
    return _classes.listActiveClasses(
      widget.teacherId,
      schoolYear: schoolYearFilter,
    );
  }

  Future<List<ClassSummaryRow>> _matrix(
    List<Map<String, Object?>> active,
  ) async {
    if (classIdFilter != null) {
      return _analytics.buildClassLevelMatrix(
        classId: classIdFilter!,
        assessmentType: assessmentType,
      );
    }

    final byLevel = <String, ClassSummaryRow>{};
    for (final lvl in DevLevels.ordered) {
      byLevel[lvl] = ClassSummaryRow(
        level: lvl,
        perDomain: {for (final d in _domains) d: DomainGenderCounts()},
      );
    }

    for (final c in active) {
      final classId = c['id'] as int;
      final rows = await _analytics.buildClassLevelMatrix(
        classId: classId,
        assessmentType: assessmentType,
      );
      for (final r in rows) {
        final acc = byLevel[r.level]!;
        for (final d in _domains) {
          acc.perDomain[d]!.m += r.perDomain[d]!.m;
          acc.perDomain[d]!.f += r.perDomain[d]!.f;
        }
      }
    }

    return DevLevels.ordered.map((l) => byLevel[l]!).toList();
  }

  Future<Map<String, DomainGenderCounts>> _overallCounts(
    List<Map<String, Object?>> active,
  ) async {
    final out = <String, DomainGenderCounts>{
      for (final lvl in DevLevels.ordered) lvl: DomainGenderCounts(),
    };

    final classIds = classIdFilter == null
        ? active.map((e) => e['id'] as int)
        : [classIdFilter!];

    for (final classId in classIds) {
      final map = await _analytics.buildClassOverallLevelCounts(
        classId: classId,
        assessmentType: assessmentType,
      );
      for (final lvl in DevLevels.ordered) {
        out[lvl]!.m += map[lvl]?.m ?? 0;
        out[lvl]!.f += map[lvl]?.f ?? 0;
      }
    }
    return out;
  }

  Future<Map<String, Map<String, List<TopSkill>>>> _top3(
    List<Map<String, Object?>> active,
  ) async {
    final sum = <String, Map<String, TopSkill>>{};
    for (final d in _domains) {
      sum[d] = {};
    }

    final classIds = classIdFilter == null
        ? active.map((e) => e['id'] as int)
        : [classIdFilter!];

    for (final classId in classIds) {
      final map = await _analytics.top3MostLeastByDomainForClass(
        classId: classId,
        assessmentType: assessmentType,
        language: language,
      );
      for (final d in _domains) {
        final all = map[d]!['most']!;
        for (final s in all) {
          final key = '${s.skillIndex}|${s.skillText}';
          final prev = sum[d]![key];
          if (prev == null) {
            sum[d]![key] = TopSkill(
              domain: d,
              skillIndex: s.skillIndex,
              skillText: s.skillText,
              checkedCount: s.checkedCount,
              totalLearners: s.totalLearners,
            );
          } else {
            sum[d]![key] = TopSkill(
              domain: d,
              skillIndex: s.skillIndex,
              skillText: s.skillText,
              checkedCount: prev.checkedCount + s.checkedCount,
              totalLearners: prev.totalLearners + s.totalLearners,
            );
          }
        }
      }
    }

    final out = <String, Map<String, List<TopSkill>>>{};

for (final d in _domains) {
  final list = sum[d]!.values.toList();

  // 🔽 MOST (highest percentage first)
  list.sort((a, b) => b.pct.compareTo(a.pct));
  final most = list.take(3).toList();

  // 🔽 REMOVE overlap from MOST
  final remaining = list.where((e) => !most.contains(e)).toList();

  // 🔽 LEAST (lowest percentage from remaining only)
  remaining.sort((a, b) => a.pct.compareTo(b.pct));
  final least = remaining.take(3).toList();

  out[d] = {
    'most': most,
    'least': least,
  };
}

return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _activeClasses(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final classes = snap.data!;
        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 1080;
                final controls = Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      value: assessmentType,
                      items: const [
                        DropdownMenuItem(value: 'pre', child: Text('Pre-Test')),
                        DropdownMenuItem(
                          value: 'post',
                          child: Text('Post-Test'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => assessmentType = v ?? 'pre'),
                    ),
                    DropdownButton<EccdLanguage>(
                      value: language,
                      items: const [
                        DropdownMenuItem(
                          value: EccdLanguage.english,
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: EccdLanguage.tagalog,
                          child: Text('Tagalog'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => language = v ?? EccdLanguage.english),
                    ),
                    DropdownButton<String>(
                      value: schoolYearFilter,
                      hint: const Text('School Year'),
                      items: _schoolYearOptions()
                          .map(
                            (sy) =>
                                DropdownMenuItem(value: sy, child: Text(sy)),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          schoolYearFilter = v;
                          classIdFilter = null;
                        });
                      },
                    ),
                    DropdownButton<int?>(
                      value: classIdFilter,
                      hint: const Text('Class'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Active'),
                        ),
                        ...classes.map(
                          (c) => DropdownMenuItem<int?>(
                            value: c['id'] as int,
                            child: Text('G${c['grade']} ${c['section']}'),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => classIdFilter = v),
                    ),
                  ],
                );
                if (!compact) {
                  return Row(
                    children: [
                      const Expanded(child: SectionTitle(title: 'My Summary')),
                      controls,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(title: 'My Summary'),
                    const SizedBox(height: 10),
                    controls,
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  FutureBuilder<List<Object>>(
                    future: Future.wait<Object>([
                      _matrix(classes),
                      _overallCounts(classes),
                    ]),
                    builder: (context, mSnap) {
                      if (!mSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _matrixCard(
                        mSnap.data![0] as List<ClassSummaryRow>,
                        mSnap.data![1] as Map<String, DomainGenderCounts>,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder(
                    future: _top3(classes),
                    builder: (context, tSnap) {
                      if (!tSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _top3Card(tSnap.data!);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _matrixCard(
    List<ClassSummaryRow> rows,
    Map<String, DomainGenderCounts> overallByLevel,
  ) {
    int rowGrandM(ClassSummaryRow r) => overallByLevel[r.level]?.m ?? 0;
    int rowGrandF(ClassSummaryRow r) => overallByLevel[r.level]?.f ?? 0;
    int rowGrandT(ClassSummaryRow r) => rowGrandM(r) + rowGrandF(r);
    int colDomM(String d) => rows.fold(0, (a, r) => a + r.perDomain[d]!.m);
    int colDomF(String d) => rows.fold(0, (a, r) => a + r.perDomain[d]!.f);
    int colDomT(String d) => colDomM(d) + colDomF(d);
    final totalGrandM = DevLevels.ordered.fold(
      0,
      (a, l) => a + (overallByLevel[l]?.m ?? 0),
    );
    final totalGrandF = DevLevels.ordered.fold(
      0,
      (a, l) => a + (overallByLevel[l]?.f ?? 0),
    );
    final totalGrandT = totalGrandM + totalGrandF;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _matrixGroupedTable(
          rows: rows,
          rowGrandM: rowGrandM,
          rowGrandF: rowGrandF,
          rowGrandT: rowGrandT,
          colDomM: colDomM,
          colDomF: colDomF,
          colDomT: colDomT,
          totalGrandM: totalGrandM,
          totalGrandF: totalGrandF,
          totalGrandT: totalGrandT,
        ),
      ),
    );
  }

  Widget _matrixGroupedTable({
    required List<ClassSummaryRow> rows,
    required int Function(ClassSummaryRow) rowGrandM,
    required int Function(ClassSummaryRow) rowGrandF,
    required int Function(ClassSummaryRow) rowGrandT,
    required int Function(String) colDomM,
    required int Function(String) colDomF,
    required int Function(String) colDomT,
    required int totalGrandM,
    required int totalGrandF,
    required int totalGrandT,
  }) {
    const levelW = 110.0;
    const cellW = 72.0;
    const sepW = 12.0;

    Widget headCell(String text, double w) => SizedBox(
      width: w,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );

    Widget numCell(
      String text,
      double w, {
      bool bold = false,
      Color textColor = Colors.black87,
    }) => SizedBox(
      width: w,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: textColor,
        ),
        textAlign: TextAlign.center,
      ),
    );

    Widget vSep({Color color = const Color(0xFFB9B9B9)}) => SizedBox(
      width: sepW,
      child: Center(child: Container(width: 1, height: 30, color: color)),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            color: const Color(0xFFF0F0F0),
            child: Column(
              children: [
                Container(
                  color: AppColors.maroon,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      headCell('Level', levelW),
                      for (int i = 0; i < _domains.length; i++) ...[
                        headCell(_domains[i], cellW * 3),
                        if (i != _domains.length - 1)
                          vSep(color: Colors.white38),
                      ],
                      vSep(color: Colors.white38),
                      headCell('Grand Total', cellW * 3),
                    ],
                  ),
                ),
                Container(
                  color: const Color(0xFFB0898B),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(width: levelW),
                      for (int i = 0; i < _domains.length; i++) ...[
                        headCell('M', cellW),
                        headCell('F', cellW),
                        headCell('T', cellW),
                        if (i != _domains.length - 1)
                          vSep(color: Colors.white38),
                      ],
                      vSep(color: Colors.white38),
                      ...[
                        headCell('M', cellW),
                        headCell('F', cellW),
                        headCell('T', cellW),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (final r in rows) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Tooltip(
                          message: _levelLegendText(r.level),
                          child: numCell(r.level, levelW, bold: true),
                        ),
                        for (final d in _domains) ...[
                          numCell('${r.perDomain[d]!.m}', cellW),
                          numCell('${r.perDomain[d]!.f}', cellW),
                          numCell(
                            '${r.perDomain[d]!.total}',
                            cellW,
                            bold: true,
                            textColor: AppColors.maroonDark,
                          ),
                          if (d != _domains.last) vSep(),
                        ],
                        vSep(),
                        numCell(
                          '${rowGrandM(r)}',
                          cellW,
                          bold: true,
                          textColor: AppColors.maroonDark,
                        ),
                        numCell(
                          '${rowGrandF(r)}',
                          cellW,
                          bold: true,
                          textColor: AppColors.maroonDark,
                        ),
                        numCell(
                          '${rowGrandT(r)}',
                          cellW,
                          bold: true,
                          textColor: AppColors.maroonDark,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
                Container(
                  color: AppColors.maroonDark,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      numCell(
                        'TOTAL',
                        levelW,
                        bold: true,
                        textColor: Colors.white,
                      ),
                      for (final d in _domains) ...[
                        numCell(
                          '${colDomM(d)}',
                          cellW,
                          bold: true,
                          textColor: Colors.white,
                        ),
                        numCell(
                          '${colDomF(d)}',
                          cellW,
                          bold: true,
                          textColor: Colors.white,
                        ),
                        numCell(
                          '${colDomT(d)}',
                          cellW,
                          bold: true,
                          textColor: Colors.white,
                        ),
                        if (d != _domains.last) vSep(color: Colors.white38),
                      ],
                      vSep(color: Colors.white38),
                      numCell(
                        '$totalGrandM',
                        cellW,
                        bold: true,
                        textColor: Colors.white,
                      ),
                      numCell(
                        '$totalGrandF',
                        cellW,
                        bold: true,
                        textColor: Colors.white,
                      ),
                      numCell(
                        '$totalGrandT',
                        cellW,
                        bold: true,
                        textColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _levelLegendText(String code) {
    switch (code) {
      case 'SSDD':
        return 'Suggest Significant Delay in Development';
      case 'SSLDD':
        return 'Suggest Slight Delay in Development';
      case 'AD':
        return 'Average Development';
      case 'SSAD':
        return 'Suggest Slightly Advanced Development';
      case 'SHAD':
        return 'Suggest Highly Advanced Development';
      default:
        return code;
    }
  }

  Widget _top3Card(Map<String, Map<String, List<TopSkill>>> map) {
    if (map.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE6E6E6)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('No top/least learned data available yet.'),
        ),
      );
    }
    final selectedDomain = map.containsKey(topDomainFilter)
        ? topDomainFilter
        : map.keys.first;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Top 3 Most / Least Learned',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.maroon.withOpacity(0.35),
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedDomain,
                        dropdownColor: Colors.white,
                        focusColor: Colors.transparent,
                        items: _domains
                            .where(map.containsKey)
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => topDomainFilter = v);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selectedDomain,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _topList(
                    'Most Learned',
                    map[selectedDomain]!['most']!,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _topList(
                    'Least Learned',
                    map[selectedDomain]!['least']!,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topList(String title, List<TopSkill> list) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.maroon.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.maroonDark,
            ),
          ),
          const SizedBox(height: 8),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${s.skillText} (${s.checkedCount}/${s.totalLearners})',
                style: const TextStyle(height: 1.3),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _schoolYearOptions() {
    return schoolYearRangeOptions(startYear: 2020, yearsFromNow: 10);
  }
}
