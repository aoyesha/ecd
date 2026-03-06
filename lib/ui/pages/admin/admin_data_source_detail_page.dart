import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../services/csv_service.dart';
import '../../../services/scoring_service.dart';

class AdminDataSourceDetailPage extends StatefulWidget {
  final int sourceId;
  final String orgLevel;
  final String schoolYear;
  final String label;

  const AdminDataSourceDetailPage({
    super.key,
    required this.sourceId,
    required this.orgLevel,
    required this.schoolYear,
    required this.label,
  });

  @override
  State<AdminDataSourceDetailPage> createState() =>
      _AdminDataSourceDetailPageState();
}

class _AdminDataSourceDetailPageState
    extends State<AdminDataSourceDetailPage> {
  final _csv = CsvService();

  String assessmentType = 'pre';
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

  String _levelFieldLabel(String level) {
    switch (level) {
      case 'teacher': return 'Section:';
      case 'school': return 'School:';
      case 'district': return 'District:';
      case 'division': return 'Division:';
      case 'regional': return 'Region:';
      default: return 'Source:';
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'teacher': return Icons.class_;
      case 'school': return Icons.school;
      case 'district': return Icons.location_city;
      case 'division': return Icons.account_balance;
      case 'regional': return Icons.map;
      default: return Icons.info_outline;
    }
  }

  String _levelLabel(String level) {
    if (level.isEmpty) return 'Unknown';
    return level[0].toUpperCase() + level.substring(1).toLowerCase();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_levelLabel(widget.orgLevel)} · SY ${widget.schoolYear}',
        ),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (widget.label.isNotEmpty)
            Container(
              width: double.infinity,
              color: AppColors.maroon.withValues(alpha: 0.07),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(_levelIcon(widget.orgLevel),
                      size: 18, color: AppColors.maroon),
                  const SizedBox(width: 8),
                  Text(
                    _levelFieldLabel(widget.orgLevel),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.maroon,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Text('Assessment:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: assessmentType,
                  items: const [
                    DropdownMenuItem(value: 'pre', child: Text('Pre-Test')),
                    DropdownMenuItem(value: 'post', child: Text('Post-Test')),
                  ],
                  onChanged: (v) =>
                      setState(() => assessmentType = v ?? 'pre'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _matrixCard(),
                const SizedBox(height: 12),
                _top3Card(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matrixCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder(
          future: _csv.getSingleSourceRollup(
            sourceId: widget.sourceId,
            assessmentType: assessmentType,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final agg = snapshot.data!;
            final levels = DevLevels.ordered;

            int getCount(String domain, String gender, String level) =>
                agg[domain]?[gender]?[level] ?? 0;

            int rowGrandM(String level) => getCount('ALL', 'M', level);
            int rowGrandF(String level) => getCount('ALL', 'F', level);
            int rowGrandT(String level) =>
                rowGrandM(level) + rowGrandF(level);
            int colDomM(String d) =>
                levels.fold(0, (a, l) => a + getCount(d, 'M', l));
            int colDomF(String d) =>
                levels.fold(0, (a, l) => a + getCount(d, 'F', l));
            int colDomT(String d) => colDomM(d) + colDomF(d);
            final totalGrandM =
                levels.fold(0, (a, l) => a + getCount('ALL', 'M', l));
            final totalGrandF =
                levels.fold(0, (a, l) => a + getCount('ALL', 'F', l));
            final totalGrandT = totalGrandM + totalGrandF;

            return _matrixGroupedTable(
              levels: levels,
              getCount: getCount,
              rowGrandM: rowGrandM,
              rowGrandF: rowGrandF,
              rowGrandT: rowGrandT,
              colDomM: colDomM,
              colDomF: colDomF,
              colDomT: colDomT,
              totalGrandM: totalGrandM,
              totalGrandF: totalGrandF,
              totalGrandT: totalGrandT,
            );
          },
        ),
      ),
    );
  }

  Widget _matrixGroupedTable({
    required List<String> levels,
    required int Function(String, String, String) getCount,
    required int Function(String) rowGrandM,
    required int Function(String) rowGrandF,
    required int Function(String) rowGrandT,
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

    Widget numCell(String text, double w,
            {bool bold = false, Color textColor = Colors.black87}) =>
        SizedBox(
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
        const Text(
          'Source Summary',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
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
                      headCell('M', cellW),
                      headCell('F', cellW),
                      headCell('T', cellW),
                    ],
                  ),
                ),
                const Divider(height: 1),
                for (final lvl in levels) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Tooltip(
                          message: _levelLegendText(lvl),
                          child: numCell(lvl, levelW, bold: true),
                        ),
                        for (final d in _domains) ...[
                          numCell('${getCount(d, 'M', lvl)}', cellW),
                          numCell('${getCount(d, 'F', lvl)}', cellW),
                          numCell(
                            '${getCount(d, 'M', lvl) + getCount(d, 'F', lvl)}',
                            cellW,
                            bold: true,
                            textColor: AppColors.maroonDark,
                          ),
                          if (d != _domains.last) vSep(),
                        ],
                        vSep(),
                        numCell('${rowGrandM(lvl)}', cellW,
                            bold: true, textColor: AppColors.maroonDark),
                        numCell('${rowGrandF(lvl)}', cellW,
                            bold: true, textColor: AppColors.maroonDark),
                        numCell('${rowGrandT(lvl)}', cellW,
                            bold: true, textColor: AppColors.maroonDark),
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
                      numCell('TOTAL', levelW,
                          bold: true, textColor: Colors.white),
                      for (final d in _domains) ...[
                        numCell('${colDomM(d)}', cellW,
                            bold: true, textColor: Colors.white),
                        numCell('${colDomF(d)}', cellW,
                            bold: true, textColor: Colors.white),
                        numCell('${colDomT(d)}', cellW,
                            bold: true, textColor: Colors.white),
                        if (d != _domains.last) vSep(color: Colors.white38),
                      ],
                      vSep(color: Colors.white38),
                      numCell('$totalGrandM', cellW,
                          bold: true, textColor: Colors.white),
                      numCell('$totalGrandF', cellW,
                          bold: true, textColor: Colors.white),
                      numCell('$totalGrandT', cellW,
                          bold: true, textColor: Colors.white),
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

  Widget _top3Card() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder(
          future: _csv.getSingleSourceSkills(
            sourceId: widget.sourceId,
            assessmentType: assessmentType,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final map = snapshot.data!;
            if (map.isEmpty) {
              return const Text(
                'No skill data available for this source.',
              );
            }

            final selectedDomain = map.containsKey(topDomainFilter)
                ? topDomainFilter
                : map.keys.first;
            final rows = [...map[selectedDomain]!];
            rows.sort((a, b) {
              final ap = (a['total_sum'] as int) == 0
                  ? 0.0
                  : (a['checked_sum'] as int) / (a['total_sum'] as int);
              final bp = (b['total_sum'] as int) == 0
                  ? 0.0
                  : (b['checked_sum'] as int) / (b['total_sum'] as int);
              return bp.compareTo(ap);
            });
            final most = rows.take(3).toList();
            final least = [...rows]
              ..sort((a, b) {
                final ap = (a['total_sum'] as int) == 0
                    ? 0.0
                    : (a['checked_sum'] as int) / (a['total_sum'] as int);
                final bp = (b['total_sum'] as int) == 0
                    ? 0.0
                    : (b['checked_sum'] as int) / (b['total_sum'] as int);
                return ap.compareTo(bp);
              });

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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.maroon.withValues(alpha: 0.35),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedDomain,
                          dropdownColor: Colors.white,
                          items: _domains
                              .where(map.containsKey)
                              .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => topDomainFilter = v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(selectedDomain,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _skillList('Most Learned', most)),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            _skillList('Least Learned', least.take(3).toList())),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _skillList(String title, List<Map<String, Object?>> list) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6E6E6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.maroonDark)),
          const SizedBox(height: 6),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                  '${s['skill_text']} (${s['checked_sum']}/${s['total_sum']})'),
            ),
        ],
      ),
    );
  }
}
