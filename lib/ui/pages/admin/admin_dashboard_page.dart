import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_dialogs.dart';
import '../../../core/constants.dart';
import '../../../services/auth_service.dart';
import '../../../services/csv_service.dart';
import '../../../services/file_export_service.dart';
import '../../../services/xlsx_service.dart';
import '../../../services/scoring_service.dart';
import '../../widgets/section_title.dart';
import 'admin_data_sources_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final ValueChanged<List<String>>? onDirectoryChanged;

  const AdminDashboardPage({super.key, this.onDirectoryChanged});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int tab = 0;
  int _summaryRefreshKey = 0;

  List<String> get _directorySegments => switch (tab) {
    0 => const ['Dashboard', 'My Data Sources'],
    1 => const ['Dashboard', 'My Summary'],
    _ => const ['Dashboard'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onDirectoryChanged?.call(_directorySegments);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      AdminDataSourcesPage(
        onSourceImported: () {
          setState(() {
            tab = 1;
            _summaryRefreshKey++;
          });
          widget.onDirectoryChanged?.call(_directorySegments);
        },
      ),
      _AdminSummaryTab(key: ValueKey(_summaryRefreshKey)),
    ];

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 820;
                  final segmented = SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('My Data Sources')),
                      ButtonSegment(value: 1, label: Text('My Summary')),
                    ],
                    selected: {tab},
                    onSelectionChanged: (v) {
                      setState(() => tab = v.first);
                      widget.onDirectoryChanged?.call(_directorySegments);
                    },
                  );
                  if (!compact) {
                    return Row(
                      children: [
                        const Expanded(child: SectionTitle(title: 'Dashboard')),
                        segmented,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(title: 'Dashboard'),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: segmented,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: IndexedStack(index: tab, children: tabs),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            onPressed: () {
              AppDialogs.showHelpDialog(context);
            },
            backgroundColor: AppColors.maroon,
            foregroundColor: Colors.white,
            elevation: 6,
            highlightElevation: 10,
            shape: const CircleBorder(),
            child: const Text(
              '?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminSummaryTab extends StatefulWidget {
  const _AdminSummaryTab({super.key});

  @override
  State<_AdminSummaryTab> createState() => _AdminSummaryTabState();
}

class _AdminSummaryTabState extends State<_AdminSummaryTab> {
  final _csv = CsvService();
  final _xlsx = XlsxService();
  final _file = FileExportService();

  String assessmentType = 'pre';
  String? schoolYearFilter;
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

  @override
  Widget build(BuildContext context) {
    final adminId = context.watch<AuthService>().session!.userId;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            final controls = SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 110,
                    child: DropdownButton<String>(
                      value: assessmentType,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: 'pre', child: Text('Pre-Test')),
                        DropdownMenuItem(value: 'post', child: Text('Post-Test')),
                      ],
                      onChanged: (v) => setState(() => assessmentType = v ?? 'pre'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 130,
                    child: DropdownButton<String>(
                      value: schoolYearFilter,
                      hint: const Text('School Year'),
                      isExpanded: true,
                      items: _schoolYearOptions()
                          .map((sy) => DropdownMenuItem(value: sy, child: Text(sy)))
                          .toList(),
                      onChanged: (v) => setState(() => schoolYearFilter = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final level = await AppDialogs.showChoiceDialog<String>(
                        context,
                        title: 'Export As',
                        message:
                            'Choose the organization level for this exported rollup file.',
                        options: const [
                          AppDialogOption(
                            value: 'school',
                            title: 'School',
                            subtitle: 'Create a school-level rollup file.',
                            icon: Icons.school_rounded,
                          ),
                          AppDialogOption(
                            value: 'district',
                            title: 'District',
                            subtitle: 'Export a district aggregation.',
                            icon: Icons.location_city_rounded,
                          ),
                          AppDialogOption(
                            value: 'division',
                            title: 'Division',
                            subtitle: 'Export a division-level datasource.',
                            icon: Icons.account_balance_rounded,
                          ),
                          AppDialogOption(
                            value: 'regional',
                            title: 'Regional',
                            subtitle: 'Generate a region-wide rollup.',
                            icon: Icons.map_rounded,
                          ),
                        ],
                      );
                      if (level == null) return;
                      if (!mounted) return;

                      final fmt = await AppDialogs.showChoiceDialog<String>(
                        context,
                        title: 'Export Format',
                        message:
                            'Choose the export format for this consolidated summary.',
                        options: const [
                          AppDialogOption(
                            value: 'csv',
                            title: 'CSV',
                            subtitle: 'Best for sharing and importing.',
                            icon: Icons.table_chart_rounded,
                          ),
                          AppDialogOption(
                            value: 'xlsx',
                            title: 'XLSX',
                            subtitle:
                                'Styled spreadsheet for printing or review.',
                            icon: Icons.grid_on_rounded,
                          ),
                        ],
                      );
                      if (fmt == null) return;
                      if (!mounted) return;

                      final exportName = await _csv.buildAdminRollupFilename(
                        adminId: adminId,
                        orgLevel: level,
                        assessmentType: assessmentType,
                        schoolYear: schoolYearFilter,
                      );

                      if (fmt == 'xlsx') {
                        final bytes = await _xlsx.exportAdminAggregatedRollupXlsx(
                          adminId: adminId,
                          assessmentType: assessmentType,
                          schoolYear: schoolYearFilter,
                        );
                        await _file.saveXlsx(
                          filename: exportName,
                          xlsxBytes: bytes,
                        );
                      } else {
                        final csvText = await _csv.exportAdminAggregatedRollupCsv(
                          adminId: adminId,
                          orgLevel: level,
                          assessmentType: assessmentType,
                          schoolYear: schoolYearFilter,
                        );
                        await _file.saveCsv(
                          filename: exportName,
                          csvText: csvText,
                        );
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Export'),
                  ),
                ],
              ),
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
              _adminMatrixCard(adminId),
              const SizedBox(height: 12),
              _adminTop3Card(adminId),
            ],
          ),
        ),
      ],
    );
  }

  Widget _adminMatrixCard(int adminId) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder(
          future: _csv.aggregateAdminRollup(
            adminId: adminId,
            assessmentType: assessmentType,
            schoolYear: schoolYearFilter,
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
            int rowGrandT(String level) => rowGrandM(level) + rowGrandF(level);
            int colDomM(String domain) =>
                levels.fold(0, (a, l) => a + getCount(domain, 'M', l));
            int colDomF(String domain) =>
                levels.fold(0, (a, l) => a + getCount(domain, 'F', l));
            int colDomT(String domain) => colDomM(domain) + colDomF(domain);

            final totalGrandM = levels.fold(
              0,
              (a, l) => a + getCount('ALL', 'M', l),
            );
            final totalGrandF = levels.fold(
              0,
              (a, l) => a + getCount('ALL', 'F', l),
            );
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
        const Text(
          'Aggregated Summary (Active Data Sources)',
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
                        numCell(
                          '${rowGrandM(lvl)}',
                          cellW,
                          bold: true,
                          textColor: AppColors.maroonDark,
                        ),
                        numCell(
                          '${rowGrandF(lvl)}',
                          cellW,
                          bold: true,
                          textColor: AppColors.maroonDark,
                        ),
                        numCell(
                          '${rowGrandT(lvl)}',
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

  Widget _adminTop3Card(int adminId) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder(
          future: _csv.aggregateAdminSkills(
            adminId: adminId,
            assessmentType: assessmentType,
            schoolYear: schoolYearFilter,
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
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No data available yet.\n'
                        'Top 3 Most/Least Learned will appear once imported sources include SKILL rows.\n'
                        'Teacher exports in this project already include them.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
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
                            color: AppColors.maroon.withValues(alpha: 0.35),
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
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ),
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
                    Expanded(child: _skillList('Most Learned', most)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _skillList(
                        'Least Learned',
                        least.take(3).toList(),
                      ),
                    ),
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
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.maroonDark,
            ),
          ),
          const SizedBox(height: 6),
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${s['skill_text']} (${s['checked_sum']}/${s['total_sum']})',
              ),
            ),
        ],
      ),
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

  List<String> _schoolYearOptions() {
    return schoolYearRangeOptions(startYear: 2020, yearsFromNow: 10);
  }
}
