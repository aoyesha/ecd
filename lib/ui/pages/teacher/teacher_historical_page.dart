import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/responsive.dart';
import '../../../data/eccd_questions.dart';
import '../../../services/analytics_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/scoring_service.dart';
import '../../widgets/section_title.dart';

class TeacherHistoricalPage extends StatefulWidget {
  const TeacherHistoricalPage({super.key});

  @override
  State<TeacherHistoricalPage> createState() => _TeacherHistoricalPageState();
}

class _TeacherHistoricalPageState extends State<TeacherHistoricalPage> {
  final _analytics = AnalyticsService();

  String assessmentType = 'pre';
  EccdLanguage language = EccdLanguage.english;
  String? leftYear;
  String? rightYear;
  String topDomain = 'Gross Motor';
  String? leftAssessment;
  String? rightAssessment;

  @override
  Widget build(BuildContext context) {
    final teacherId = context.watch<AuthService>().session!.userId;
    final sideBySide =
        isDesktop(context) || MediaQuery.of(context).size.width >= 1050;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<String>>(
        future: _analytics.listTeacherSchoolYears(teacherId),
        builder: (context, yearsSnap) {
          if (!yearsSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final years = yearsSnap.data!;
          if (years.isEmpty) {
            return const Column(
              children: [
                SectionTitle(title: 'Historical Data Analysis'),
                SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: Text(
                      'No class history yet. Add classes and save assessments first.',
                    ),
                  ),
                ),
              ],
            );
          }

          leftYear ??= years.first;
          rightYear ??= years.length > 1 ? years[1] : years.first;

          if (!years.contains(leftYear)) {
            leftYear = years.first;
          }
          if (!years.contains(rightYear)) {
            rightYear = years.length > 1 ? years[1] : years.first;
          }

          return Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 900;
                  final controls = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
            DropdownButton<String>(
                        value: assessmentType,
                        items: const [
                          DropdownMenuItem(
                            value: 'pre',
                            child: Text('Pre-Test'),
                          ),
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
                        onChanged: (v) => setState(
                          () => language = v ?? EccdLanguage.english,
                        ),
                      ),
                    ],
                  );
                  if (!compact) {
                    return Row(
                      children: [
                        const Expanded(
                          child: SectionTitle(
                            title: 'Historical Data Analysis',
                          ),
                        ),
                        controls,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Historical Data Analysis'),
                      const SizedBox(height: 10),
                      controls,
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: sideBySide
                    ? Row(
                        children: [
                          Expanded(child: _yearPanel(teacherId, years, true, leftAssessment ?? assessmentType)),
                          const SizedBox(width: 12),
                          Expanded(child: _yearPanel(teacherId, years, false, rightAssessment ?? assessmentType)),
                        ],
                      )
                    : ListView(
                        children: [
                          SizedBox(
                            height: 640,
                            child: _yearPanel(teacherId, years, true, leftAssessment ?? assessmentType),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 640,
                            child: _yearPanel(teacherId, years, false, rightAssessment ?? assessmentType),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _yearPanel(int teacherId, List<String> years, bool left, String selectedAssessment) {
    final selectedYear = left ? leftYear! : rightYear!;

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
                Text(
                  left ? 'Comparison A' : 'Comparison B',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: selectedYear,
                  items: years
                      .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    if (left) {
                      leftYear = v ?? selectedYear;
                    } else {
                      rightYear = v ?? selectedYear;
                    }
                  }),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Assessment Type:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedAssessment,
                  items: const [
                    DropdownMenuItem(
                      value: 'pre',
                      child: Text('Pre-Test'),
                    ),
                    DropdownMenuItem(
                      value: 'post',
                      child: Text('Post-Test'),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    if (left) {
                      leftAssessment = v;
                    } else {
                      rightAssessment = v;
                    }
                  }),
                ),
              ],
            ),
            const Divider(height: 18),
            Expanded(
              child: FutureBuilder<TeacherHistoricalSnapshot>(
                future: _analytics.buildTeacherHistoricalSnapshot(
                  teacherId: teacherId,
                  schoolYear: selectedYear,
                  assessmentType: selectedAssessment,
                ),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final s = snap.data!;
                  final maxLevel = _maxOrOne(s.levelTotals.values);
                  final maxDomain = _maxOrOne(s.domainTotals.values);

                  return ListView(
                    children: [
                      _metricRow('School Year', selectedYear),
                      _metricRow('Assessment Type', selectedAssessment == 'pre' ? 'Pre-Test' : 'Post-Test'),
                      _metricRow(
                        'Classes',
                        '${s.classCount}',
                      ),
                      _metricRow(
                        'Assessed Learners',
                        '${s.assessedLearnerCount}',
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Level Distribution',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      ...DevLevels.ordered.map(
                        (lvl) => _barRow(
                          label: lvl,
                          value: s.levelTotals[lvl] ?? 0,
                          maxValue: maxLevel,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Domain Coverage',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      ...const [
                        'Gross Motor',
                        'Fine Motor',
                        'Self Help',
                        'Receptive Language',
                        'Expressive Language',
                        'Cognitive',
                        'Social Emotional',
                      ].map(
                        (d) => _barRow(
                          label: d,
                          value: s.domainTotals[d] ?? 0,
                          maxValue: maxDomain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FutureBuilder<Map<String, Map<String, List<TopSkill>>>>(
                        future: _analytics.top3MostLeastByDomainForTeacherSchoolYear(
                          teacherId: teacherId,
                          schoolYear: selectedYear,
                          assessmentType: selectedAssessment,
                          language: language,
                        ),
                        builder: (context, skillSnap) {
                          // ✅ Match behavior with other page (centered empty state)
                          if (s.classCount == 0 || s.assessedLearnerCount == 0) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'No data available yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          }

                          if (!skillSnap.hasData || skillSnap.data!.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'No data available yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            );
                          }

                          final map = skillSnap.data!;
                          final selectedDomain = map.containsKey(topDomain)
                              ? topDomain
                              : map.keys.first;

                          return Column(
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
                                  DropdownButton<String>(
                                    value: selectedDomain,
                                    items: map.keys
                                        .map(
                                          (d) => DropdownMenuItem(
                                        value: d,
                                        child: Text(d),
                                      ),
                                    )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => topDomain = v ?? selectedDomain),
                                  ),
                                ],
                              ),
                              _skillList(
                                'Most Learned',
                                map[selectedDomain]!['most']!,
                              ),
                              const SizedBox(height: 8),
                              _skillList(
                                'Least Learned',
                                map[selectedDomain]!['least']!,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _barRow({
    required String label,
    required int value,
    required int maxValue,
  }) {
    final factor = maxValue <= 0 ? 0.0 : value / maxValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: factor,
                minHeight: 10,
                backgroundColor: const Color(0xFFE9E9E9),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.maroon,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text('$value', textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _skillList(String title, List<TopSkill> list) {
    final filteredList = list.where((s) => s.checkedCount > 0).toList();
    final noData = filteredList.isEmpty;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          if (noData)
            const Text(
              'No data available yet.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            )
          else
            for (final s in filteredList)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${s.skillText} (${s.checkedCount}/${s.totalLearners})',
                ),
              ),
        ],
      ),
    );
  }

  int _maxOrOne(Iterable<int> values) {
    if (values.isEmpty) return 1;
    int m = 0;
    for (final v in values) {
      if (v > m) m = v;
    }
    return m <= 0 ? 1 : m;
  }
}
