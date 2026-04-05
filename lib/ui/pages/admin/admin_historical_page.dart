import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/responsive.dart';
import '../../../services/auth_service.dart';
import '../../../services/csv_service.dart';
import '../../../services/scoring_service.dart';
import '../../widgets/section_title.dart';

class AdminHistoricalPage extends StatefulWidget {
  const AdminHistoricalPage({super.key});

  @override
  State<AdminHistoricalPage> createState() => _AdminHistoricalPageState();
}

class _AdminHistoricalPageState extends State<AdminHistoricalPage> {
  final _csv = CsvService();

  String assessmentType = 'pre';
  String? leftYear;
  String? rightYear;
  String topDomain = 'Gross Motor';

  @override
  Widget build(BuildContext context) {
    final adminId = context.watch<AuthService>().session!.userId;
    final sideBySide =
        isDesktop(context) || MediaQuery.of(context).size.width >= 1050;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<List<String>>(
        future: _csv.listAdminSchoolYears(adminId),
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
                      'No imported data sources yet. Add CSV data sources first.',
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
                  final compact = constraints.maxWidth < 760;
                  final controls = DropdownButton<String>(
                    value: assessmentType,
                    items: const [
                      DropdownMenuItem(value: 'pre', child: Text('Pre-Test')),
                      DropdownMenuItem(value: 'post', child: Text('Post-Test')),
                    ],
                    onChanged: (v) =>
                        setState(() => assessmentType = v ?? 'pre'),
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
                          Expanded(child: _yearPanel(adminId, years, true)),
                          const SizedBox(width: 12),
                          Expanded(child: _yearPanel(adminId, years, false)),
                        ],
                      )
                    : ListView(
                        children: [
                          SizedBox(
                            height: 640,
                            child: _yearPanel(adminId, years, true),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 640,
                            child: _yearPanel(adminId, years, false),
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

  Widget _yearPanel(int adminId, List<String> years, bool left) {
    final selectedYear = left ? leftYear! : rightYear!;
    const domains = [
      'Gross Motor',
      'Fine Motor',
      'Self Help',
      'Receptive Language',
      'Expressive Language',
      'Cognitive',
      'Social Emotional',
    ];

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
            const Divider(height: 18),
            Expanded(
              child: FutureBuilder<List<Object>>(
                future: Future.wait([
                  _csv.aggregateAdminRollup(
                    adminId: adminId,
                    assessmentType: assessmentType,
                    schoolYear: selectedYear,
                  ),
                  _csv.aggregateAdminSkills(
                    adminId: adminId,
                    assessmentType: assessmentType,
                    schoolYear: selectedYear,
                  ),
                  _csv.listAdminSources(
                    adminId,
                    archived: false,
                    schoolYear: selectedYear,
                  ),
                ]),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final agg =
                      snap.data![0]
                          as Map<String, Map<String, Map<String, int>>>;
                  final skills =
                      snap.data![1] as Map<String, List<Map<String, Object?>>>;
                  final sources = snap.data![2] as List<Map<String, Object?>>;

                  final levelTotals = <String, int>{
                    for (final l in DevLevels.ordered) l: 0,
                  };
                  final domainTotals = <String, int>{
                    for (final d in domains) d: 0,
                  };
                  for (final d in domains) {
                    for (final l in DevLevels.ordered) {
                      final m = agg[d]?['M']?[l] ?? 0;
                      final f = agg[d]?['F']?[l] ?? 0;
                      domainTotals[d] = (domainTotals[d] ?? 0) + m + f;
                    }
                  }
                  for (final l in DevLevels.ordered) {
                    final m = agg['ALL']?['M']?[l] ?? 0;
                    final f = agg['ALL']?['F']?[l] ?? 0;
                    levelTotals[l] = m + f;
                  }

                  final maxLevel = _maxOrOne(levelTotals.values);
                  final maxDomain = _maxOrOne(domainTotals.values);
                  final selectedDomain = skills.containsKey(topDomain)
                      ? topDomain
                      : (skills.keys.isEmpty ? '' : skills.keys.first);

                  final most = _topSkills(
                    skills[selectedDomain] ?? const [],
                    desc: true,
                  );
                  final least = _topSkills(
                    skills[selectedDomain] ?? const [],
                    desc: false,
                  );

                  return ListView(
                    children: [
                      _metricRow('School Year', selectedYear),
                      _metricRow('Active Data Sources', '${sources.length}'),
                      _metricRow(
                        'Total Records (all domains)',
                        '${domainTotals.values.fold<int>(0, (a, b) => a + b)}',
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
                          value: levelTotals[lvl] ?? 0,
                          maxValue: maxLevel,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Domain Coverage',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      ...domains.map(
                        (d) => _barRow(
                          label: d,
                          value: domainTotals[d] ?? 0,
                          maxValue: maxDomain,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (skills.isEmpty)
                        const Text(
                          'No Top 3 skill data yet for this school year.',
                        )
                      else ...[
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
                              items: skills.keys
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(
                                () => topDomain = v ?? selectedDomain,
                              ),
                            ),
                          ],
                        ),
                        _skillList('Most Learned', most),
                        const SizedBox(height: 8),
                        _skillList('Least Learned', least),
                      ],
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

  List<Map<String, Object?>> _topSkills(
    List<Map<String, Object?>> rows, {
    required bool desc,
  }) {
    final list = [...rows];
    list.sort((a, b) {
      final aTotal = _toInt(a['total_sum']);
      final bTotal = _toInt(b['total_sum']);
      final aPct = aTotal == 0 ? 0.0 : (_toInt(a['checked_sum']) / aTotal);
      final bPct = bTotal == 0 ? 0.0 : (_toInt(b['checked_sum']) / bTotal);
      return desc ? bPct.compareTo(aPct) : aPct.compareTo(bPct);
    });
    return list.take(3).toList();
  }

  Widget _skillList(String title, List<Map<String, Object?>> list) {
    final filteredList = list.where((s) => _toInt(s['checked_sum']) > 0).toList();
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
                  '- ${(s['skill_text'] ?? '').toString()} '
                  '(${_toInt(s['checked_sum'])}/${_toInt(s['total_sum'])})',
                ),
              ),
        ],
      ),
    );
  }

  int _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
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
