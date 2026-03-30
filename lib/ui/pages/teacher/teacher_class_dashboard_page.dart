import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_dialogs.dart';
import '../../../core/constants.dart';
import '../../../core/nav_no_transition.dart';
import '../../../core/responsive.dart';
import '../../../core/ui_feedback.dart';
import '../../../data/eccd_questions.dart';
import '../../../db/app_db.dart';
import '../../../db/schema.dart';
import '../../../services/analytics_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_service.dart';
import '../../../services/csv_service.dart';
import '../../../services/file_export_service.dart';
import '../../../services/xlsx_service.dart';
import '../../../services/learner_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/scoring_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_title.dart';
import '../../widgets/subpage_shell.dart';
import 'teacher_add_learner_page.dart';
import 'teacher_learner_profile_page.dart';
import 'teacher_checklist_page.dart';

class TeacherClassDashboardPage extends StatefulWidget {
  final int classId;
  final String grade;
  final String section;
  final String schoolYear;

  const TeacherClassDashboardPage({
    super.key,
    required this.classId,
    required this.grade,
    required this.section,
    required this.schoolYear,
  });

  @override
  State<TeacherClassDashboardPage> createState() =>
      _TeacherClassDashboardPageState();
}

class _TeacherClassDashboardPageState extends State<TeacherClassDashboardPage> {
  int tab = 0;

  final _classService = ClassService();

  String get _currentTabLabel => switch (tab) {
    0 => 'View Class',
    1 => 'Class Summary',
    2 => 'Teacher Report',
    3 => 'Dropped Pupils',
    _ => 'View Class',
  };

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _ViewClassTab(classId: widget.classId),
      _ClassSummaryTab(
        classId: widget.classId,
        grade: widget.grade,
        section: widget.section,
        schoolYear: widget.schoolYear,
      ),
      _TeacherReportTab(classId: widget.classId),
      _DroppedTab(classId: widget.classId),
    ];

    return SubpageShell(
      title: 'Class - Grade ${widget.grade} ${widget.section}',
      directorySegments: [
        'Dashboard',
        'My Classes',
        '${widget.grade} ${widget.section}',
        _currentTabLabel,
      ],
      navIndex: 0,
      actions: [
        IconButton(
          tooltip: 'Archive class',
          onPressed: () async {
            await _classService.archiveClass(widget.classId);
            if (!context.mounted) return;
            Navigator.pop(context);
          },
          icon: const Icon(Icons.archive),
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final segmented = SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('View Class')),
                    ButtonSegment(value: 1, label: Text('Class Summary')),
                    ButtonSegment(value: 2, label: Text('Teacher Report')),
                    ButtonSegment(value: 3, label: Text('Dropped Pupils')),
                  ],
                  selected: {tab},
                  onSelectionChanged: (v) => setState(() => tab = v.first),
                );
                if (!compact) {
                  return Row(
                    children: [
                      Expanded(
                        child: SectionTitle(
                          title: 'School Year: ${widget.schoolYear}',
                        ),
                      ),
                      segmented,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(title: 'School Year: ${widget.schoolYear}'),
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
            Expanded(child: tabs[tab]),
          ],
        ),
      ),
    );
  }
}

class _ViewClassTab extends StatefulWidget {
  final int classId;
  const _ViewClassTab({required this.classId});

  @override
  State<_ViewClassTab> createState() => _ViewClassTabState();
}

class _ViewClassTabState extends State<_ViewClassTab> {
  final _learners = LearnerService();

  String progressFilter = 'All'; // All|In Progress|Completed
  int _reloadTick = 0;

  Future<bool> _hasAssessment(int learnerId, String type) async {
    final db = AppDb.instance.db;

    final rows = await db.rawQuery(
      '''
    SELECT s.${DbSchema.cSumAssessId}
    FROM ${DbSchema.tAssessments} a
    JOIN ${DbSchema.tAssessmentSummary} s
      ON s.${DbSchema.cSumAssessId} = a.${DbSchema.cAssessId}
    WHERE a.${DbSchema.cAssessLearnerId} = ?
      AND a.${DbSchema.cAssessClassId} = ?
      AND a.${DbSchema.cAssessType} = ?
    LIMIT 1
  ''',
      [learnerId, widget.classId, type],
    );

    return rows.isNotEmpty;
  }

  Future<Map<int, _AssessmentProgress>> _completionFlags(
    List<Map<String, Object?>> learners,
  ) async {
    final out = <int, _AssessmentProgress>{};
    for (final l in learners) {
      final id = l['id'] as int;
      final hasPre = await _hasAssessment(id, 'pre');
      final hasPost = await _hasAssessment(id, 'post');
      out[id] = _AssessmentProgress(hasPre: hasPre, hasPost: hasPost);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final filter = DropdownButton<String>(
              value: progressFilter,
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All')),
                DropdownMenuItem(
                  value: 'In Progress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(value: 'Completed', child: Text('Completed')),
              ],
              onChanged: (v) => setState(() => progressFilter = v ?? 'All'),
            );
            final addButton = ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maroon,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await navPushNoTransition(
                  context,
                  TeacherAddLearnerPage(classId: widget.classId),
                );
                setState(() {});
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Add Pupil'),
            );
            if (!compact) {
              return Row(children: [filter, const Spacer(), addButton]);
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [filter, addButton],
            );
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder(
            key: ValueKey(_reloadTick),
            future: _learners.listActiveLearners(widget.classId),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());
              var list = snapshot.data!;
              if (list.isEmpty) {
                return const EmptyState(
                  title: 'No pupils yet',
                  subtitle: 'Add a pupil to start assessments.',
                );
              }

              return FutureBuilder(
                future: _completionFlags(list),
                builder: (context, snap2) {
                  if (!snap2.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final completion = snap2.data!;

                  list = list.where((l) {
                    final id = l['id'] as int;
                    final done = completion[id]?.isComplete ?? false;
                    if (progressFilter == 'Completed') return done;
                    if (progressFilter == 'In Progress') return !done;
                    return true;
                  }).toList();

                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final l = list[i];
                      final id = l['id'] as int;
                      final name = '${l['last_name']}, ${l['first_name']}';
                      final gender = l['gender'] as String;
                      final age = l['age'] as int;
                      final progress =
                          completion[id] ??
                          const _AssessmentProgress(
                            hasPre: false,
                            hasPost: false,
                          );

                      final bool mobile = !isDesktop(context);

                      final ButtonStyle compactButtonStyle =
                          OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: mobile ? 10 : 16,
                              vertical: mobile ? 4 : 12,
                            ),
                            minimumSize: Size(0, mobile ? 30 : 40),
                            tapTargetSize: mobile
                                ? MaterialTapTargetSize.shrinkWrap
                                : MaterialTapTargetSize.padded,
                            visualDensity: mobile
                                ? const VisualDensity(
                                    horizontal: -2,
                                    vertical: -2,
                                  )
                                : null,
                            textStyle: TextStyle(fontSize: mobile ? 12 : 14),
                          );

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE6E6E6)),
                        ),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 350,
                                child: _AssessmentProgressBars(progress: progress),
                              ),
                            ],
                          ),
                          subtitle: Text('Gender: $gender - Age: $age'),
                          trailing: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                OutlinedButton(
                                  style: compactButtonStyle,
                                  onPressed: () async {
                                    await navPushNoTransition(
                                      context,
                                      TeacherLearnerProfilePage(learnerId: id),
                                    );
                                    if (!mounted) return;
                                    setState(() => _reloadTick++);
                                  },
                                  child: const Text('View'),
                                ),
                                OutlinedButton(
                                  style: compactButtonStyle,
                                  onPressed: () async {
                                    await navPushNoTransition(
                                      context,
                                      TeacherChecklistPage(
                                        classId: widget.classId,
                                        learnerId: id,
                                      ),
                                    );
                                    if (!mounted) return;
                                    setState(() => _reloadTick++);
                                  },
                                  child: const Text('Checklist'),
                                ),
                                IconButton(
                                  tooltip: 'Drop',
                                  onPressed: () async {
                                    await _learners.dropLearner(id);
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.person_off),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ClassSummaryTab extends StatefulWidget {
  final int classId;
  final String grade;
  final String section;
  final String schoolYear;

  const _ClassSummaryTab({
    required this.classId,
    required this.grade,
    required this.section,
    required this.schoolYear,
  });

  @override
  State<_ClassSummaryTab> createState() => _ClassSummaryTabState();
}

class _ClassSummaryTabState extends State<_ClassSummaryTab> {
  final _analytics = AnalyticsService();
  final _csv = CsvService();
  final _xlsx = XlsxService();
  final _file = FileExportService();
  final _pdf = PdfExportService();

  String assessmentType = 'pre'; // pre|post|all
  EccdLanguage language = EccdLanguage.english;
  String topDomainFilter = 'Gross Motor';

  Future<void> _exportClassSummary(int teacherId) async {
    final fmt = await AppDialogs.showChoiceDialog<String>(
      context,
      title: 'Export Format',
      message: 'Choose the export format for this class summary.',
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
          subtitle: 'Styled spreadsheet for printing or review.',
          icon: Icons.grid_on_rounded,
        ),
      ],
    );
    if (!mounted || fmt == null) return;

    // If exporting 'all' assessment types, export both pre and post
    final typesToExport = assessmentType == 'all'
        ? ['pre', 'post']
        : [assessmentType];

    try {
      for (final type in typesToExport) {
        final name =
            'teacher_class_${widget.grade}_${widget.section}_${widget.schoolYear}_$type';

        if (fmt == 'xlsx') {
          final bytes = await _xlsx.exportTeacherClassRollupXlsx(
            teacherId: teacherId,
            classId: widget.classId,
            assessmentType: type,
            languageForSkills: language,
          );
          final saved = await _file.saveXlsx(filename: name, xlsxBytes: bytes);
          if (!mounted) return;
          if (!saved) {
            _showActionMessage(
              'Class summary export cancelled.',
              isError: true,
            );
            return;
          }
        } else {
          final csvText = await _csv.exportTeacherClassRollupCsv(
            teacherId: teacherId,
            classId: widget.classId,
            assessmentType: type,
            languageForSkills: language,
          );
          final saved = await _file.saveCsv(filename: name, csvText: csvText);
          if (!mounted) return;
          if (!saved) {
            _showActionMessage(
              'Class summary export cancelled.',
              isError: true,
            );
            return;
          }
        }
      }

      if (!mounted) return;
      final count = typesToExport.length;
      _showActionMessage(
        count > 1
            ? '$count class summary files exported successfully.'
            : 'Class summary exported successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError || e is FormatException
          ? '$e'
                .replaceFirst('Bad state: ', '')
                .replaceFirst('StateError: ', '')
                .replaceFirst('FormatException: ', '')
          : 'Unable to export the class summary right now.';
      _showActionMessage(message, isError: true);
    }
  }

  Future<void> _exportAllLearnerPdfs(int teacherId) async {
    try {
      // If exporting 'all' assessment types, export both pre and post
      final typesToExport = assessmentType == 'all'
          ? ['pre', 'post']
          : [assessmentType];

      for (final type in typesToExport) {
        final bytes = await _pdf.buildClassLearnersPdf(
          classId: widget.classId,
          assessmentType: type,
          language: language,
          exportingUserId: teacherId,
        );
        final filename = _slug(
          '${widget.section}_All_Learners_${assessmentTypeDisplay(type)}',
        );
        final saved = await _file.savePdf(filename: filename, pdfBytes: bytes);
        if (!mounted) return;
        if (!saved) {
          _showActionMessage(
            'Bulk learner export cancelled.',
            isError: true,
          );
          return;
        }
      }

      if (!mounted) return;
      final count = typesToExport.length;
      _showActionMessage(
        count > 1
            ? '$count learner PDF files were exported successfully.'
            : 'All learner PDFs were exported successfully.',
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError
          ? '$e'.replaceFirst('Bad state: ', '')
          : 'Unable to export learner PDFs for this class.';
      _showActionMessage(message, isError: true);
    }
  }

  void _showActionMessage(String message, {bool isError = false}) {
    AppFeedback.showSnackBar(
      context,
      message,
      tone: isError ? AppFeedbackTone.error : AppFeedbackTone.success,
    );
  }

  String _slug(String value) {
    final compact = value.trim().replaceAll(RegExp(r'\s+'), '_');
    final safe = compact.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return safe.isEmpty ? 'export' : safe;
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = context.watch<AuthService>().session!.userId;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 980;
            final controls = Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: assessmentType,
                  items: const [
                    DropdownMenuItem(value: 'pre', child: Text('Pre-Test')),
                    DropdownMenuItem(value: 'post', child: Text('Post-Test')),
                    DropdownMenuItem(value: 'all', child: Text('All Tests')),
                  ],
                  onChanged: (v) => setState(() => assessmentType = v ?? 'pre'),
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
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maroon,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _exportClassSummary(teacherId),
                  icon: const Icon(Icons.download),
                  label: const Text('Export'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _exportAllLearnerPdfs(teacherId),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Export All Learners'),
                ),
              ],
            );
            if (!compact) {
              return Row(
                children: [
                  const Expanded(child: SectionTitle(title: 'Class Summary')),
                  controls,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Class Summary'),
                const SizedBox(height: 10),
                controls,
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // 1) MATRIX TABLE (levels x domains M/F/Total + grand totals)
        Expanded(
          child: ListView(
            children: [_matrixCard(), const SizedBox(height: 12), _top3Card()],
          ),
        ),
      ],
    );
  }

  Widget _matrixCard() {
    // Use pre-test for display when 'all' is selected
    final displayType = assessmentType == 'all' ? 'pre' : assessmentType;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<Object>>(
          future: Future.wait<Object>([
            _analytics.buildClassLevelMatrix(
              classId: widget.classId,
              assessmentType: displayType,
            ),
            _analytics.buildClassOverallLevelCounts(
              classId: widget.classId,
              assessmentType: displayType,
            ),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final rows = snapshot.data![0] as List<ClassSummaryRow>;
            final overallByLevel =
                snapshot.data![1] as Map<String, DomainGenderCounts>;
            if (rows.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No data yet. Save assessments for active pupils to populate summary.',
                ),
              );
            }

            final domains = const [
              'Gross Motor',
              'Fine Motor',
              'Self Help',
              'Receptive Language',
              'Expressive Language',
              'Cognitive',
              'Social Emotional',
            ];

            int rowGrandM(ClassSummaryRow r) => overallByLevel[r.level]?.m ?? 0;
            int rowGrandF(ClassSummaryRow r) => overallByLevel[r.level]?.f ?? 0;
            int rowGrandT(ClassSummaryRow r) => rowGrandM(r) + rowGrandF(r);
            int colDomM(String d) =>
                rows.fold(0, (a, r) => a + r.perDomain[d]!.m);
            int colDomF(String d) =>
                rows.fold(0, (a, r) => a + r.perDomain[d]!.f);
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

            return _matrixGroupedTable(
              rows: rows,
              domains: domains,
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
    required List<ClassSummaryRow> rows,
    required List<String> domains,
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
        const Text(
          'Summary (Level of Development)',
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
                      for (int i = 0; i < domains.length; i++) ...[
                        headCell(domains[i], cellW * 3),
                        if (i != domains.length - 1)
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
                      for (int i = 0; i < domains.length; i++) ...[
                        headCell('M', cellW),
                        headCell('F', cellW),
                        headCell('T', cellW),
                        if (i != domains.length - 1)
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
                        for (final d in domains) ...[
                          numCell('${r.perDomain[d]!.m}', cellW),
                          numCell('${r.perDomain[d]!.f}', cellW),
                          numCell(
                            '${r.perDomain[d]!.total}',
                            cellW,
                            bold: true,
                            textColor: AppColors.maroonDark,
                          ),
                          if (d != domains.last) vSep(),
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
                      for (final d in domains) ...[
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
                        if (d != domains.last) vSep(color: Colors.white38),
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

  Widget _top3Card() {
    // Use pre-test for display when 'all' is selected
    final displayType = assessmentType == 'all' ? 'pre' : assessmentType;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder(
          future: _analytics.top3MostLeastByDomainForClass(
            classId: widget.classId,
            assessmentType: displayType,
            language: language,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            final map = snapshot.data!;
            if (map.isEmpty) {
              return const Text('No top/least learned data available yet.');
            }
            final selectedDomain = map.containsKey(topDomainFilter)
                ? topDomainFilter
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
                            items: map.keys
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
            );
          },
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
                '- ${s.skillText} (${s.checkedCount}/${s.totalLearners})',
                style: const TextStyle(height: 1.3),
              ),
            ),
        ],
      ),
    );
  }
}

class _DroppedTab extends StatefulWidget {
  final int classId;
  const _DroppedTab({required this.classId});

  @override
  State<_DroppedTab> createState() => _DroppedTabState();
}

class _DroppedTabState extends State<_DroppedTab> {
  final _learners = LearnerService();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _learners.listDroppedLearners(widget.classId),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) {
          return const EmptyState(
            title: 'No dropped pupils',
            subtitle: 'Dropped pupils will appear here.',
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final l = list[i];
            final id = l['id'] as int;
            final name = '${l['last_name']}, ${l['first_name']}';
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE6E6E6)),
              ),
              child: ListTile(
                title: Text(name),
                subtitle: Text('Gender: ${l['gender']} - Age: ${l['age']}'),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.maroon,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await _learners.reactivateLearner(id);
                    setState(() {});
                  },
                  child: const Text('Reactivate'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TeacherReportTab extends StatefulWidget {
  final int classId;
  const _TeacherReportTab({required this.classId});

  @override
  State<_TeacherReportTab> createState() => _TeacherReportTabState();
}

class _TeacherReportTabState extends State<_TeacherReportTab> {
  String assessmentType = 'pre';

  static const _domains = [
    'Gross Motor',
    'Fine Motor',
    'Self Help',
    'Receptive Language',
    'Expressive Language',
    'Cognitive',
    'Social Emotional',
  ];

  Future<List<_TeacherReportRow>> _loadRows() async {
    final db = AppDb.instance.db;

    final learners = await db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [widget.classId, 'active'],
      orderBy:
          '${DbSchema.cLearnerLastName} ASC, ${DbSchema.cLearnerFirstName} ASC',
    );

    final rows = <_TeacherReportRow>[];
    int no = 1;

    for (final l in learners) {
      final learnerId = l[DbSchema.cLearnerId] as int;
      final assess = await db.query(
        DbSchema.tAssessments,
        where:
            '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
        whereArgs: [learnerId, widget.classId, assessmentType],
        limit: 1,
      );

      final name =
          '${(l[DbSchema.cLearnerLastName] ?? '').toString()}, ${(l[DbSchema.cLearnerFirstName] ?? '').toString()}';
      final gender = (l[DbSchema.cLearnerGender] ?? '').toString();
      final birth = (l[DbSchema.cLearnerBirthDate] ?? '').toString();

      if (assess.isEmpty) {
        rows.add(
          _TeacherReportRow(
            no: no++,
            learnerName: name,
            gender: gender,
            ageText: _ageDecimalAtDate(birth, DateTime.now()),
            testedDate: '',
            perDomain: {
              for (final d in _domains)
                d: const _DomainScore(raw: 0, scaled: 0, interp: '-'),
            },
            totalRaw: 0,
            sumScaled: 0,
            standardScore: 0,
            overallInterp:
                'No ${assessmentTypeDisplay(assessmentType)} assessment',
          ),
        );
        continue;
      }

      final assessRow = assess.first;
      final assessId = assessRow[DbSchema.cAssessId] as int;
      final testedDateIso = (assessRow[DbSchema.cAssessDate] ?? '').toString();
      final testedDate = DateTime.tryParse(testedDateIso) ?? DateTime.now();

      final domainRows = await db.query(
        DbSchema.tDomainSummary,
        where: '${DbSchema.cDomSumAssessId}=?',
        whereArgs: [assessId],
      );
      final overall = await db.query(
        DbSchema.tAssessmentSummary,
        where: '${DbSchema.cSumAssessId}=?',
        whereArgs: [assessId],
        limit: 1,
      );

      final perDomain = <String, _DomainScore>{
        for (final d in _domains)
          d: const _DomainScore(raw: 0, scaled: 0, interp: '-'),
      };

      for (final d in domainRows) {
        final rawDomain = (d[DbSchema.cDomSumDomain] ?? '').toString();
        final domain = (rawDomain == 'Dressing' || rawDomain == 'Toilet')
            ? 'Self Help'
            : rawDomain;
        if (!perDomain.containsKey(domain)) continue;
        if (domain == 'Self Help' && perDomain[domain]!.raw > 0) {
          // keep single Self Help summary row if legacy rows exist
          continue;
        }
        perDomain[domain] = _DomainScore(
          raw: (d[DbSchema.cDomSumRaw] as int?) ?? 0,
          scaled: (d[DbSchema.cDomSumScaled] as int?) ?? 0,
          interp: (d[DbSchema.cDomSumInterp] ?? '-').toString(),
        );
      }

      final totalRaw = _domains.fold<int>(0, (a, d) => a + perDomain[d]!.raw);
      final sumScaled = overall.isEmpty
          ? _domains.fold<int>(0, (a, d) => a + perDomain[d]!.scaled)
          : (overall.first[DbSchema.cSumOverallScaled] as int? ?? 0);
      final standard = overall.isEmpty
          ? 0
          : (overall.first[DbSchema.cSumStandardScore] as int? ?? 0);
      final overallInterp = overall.isEmpty
          ? '-'
          : (overall.first[DbSchema.cSumOverallInterpretation] ?? '-')
                .toString();

      rows.add(
        _TeacherReportRow(
          no: no++,
          learnerName: name,
          gender: gender,
          ageText: _ageDecimalAtDate(birth, testedDate),
          testedDate: testedDateIso.length >= 10
              ? testedDateIso.substring(0, 10)
              : testedDateIso,
          perDomain: perDomain,
          totalRaw: totalRaw,
          sumScaled: sumScaled,
          standardScore: standard,
          overallInterp: overallInterp,
        ),
      );
    }

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final control = DropdownButton<String>(
              value: assessmentType,
              items: const [
                DropdownMenuItem(value: 'pre', child: Text('Pre-Test')),
                DropdownMenuItem(value: 'post', child: Text('Post-Test')),
              ],
              onChanged: (v) => setState(() => assessmentType = v ?? 'pre'),
            );
            if (!compact) {
              return Row(
                children: [
                  const Expanded(
                    child: SectionTitle(title: 'Teacher Report Sheet'),
                  ),
                  control,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'Teacher Report Sheet'),
                const SizedBox(height: 8),
                control,
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            child: FutureBuilder<List<_TeacherReportRow>>(
              future: _loadRows(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!;
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No active pupils yet for this class.'),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _sheetWidth(),
                    child: Column(
                      children: [
                        _headerGroupRow(),
                        _headerSubRow(),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) => _dataRow(rows[i]),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  double _sheetWidth() {
    const fixed = 56.0 + 250.0 + 70.0 + 70.0 + 110.0;
    const perDomain = 3 * 80.0;
    const totals = 80.0 + 90.0 + 90.0 + 150.0;
    return fixed + (_domains.length * perDomain) + totals;
  }

  Widget _headerGroupRow() {
    return Container(
      color: AppColors.maroon,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _cell('No', 56, bold: true, white: true),
          _cell('Learner', 250, bold: true, white: true),
          _cell('Gender', 70, bold: true, white: true),
          _cell('Age', 70, bold: true, white: true),
          _cell('Date Tested', 110, bold: true, white: true),
          for (final d in _domains) _cell(d, 240, bold: true, white: true),
          _cell('Total Raw', 80, bold: true, white: true),
          _cell('Sum Scaled', 90, bold: true, white: true),
          _cell('Standard', 90, bold: true, white: true),
          _cell('Overall', 150, bold: true, white: true),
        ],
      ),
    );
  }

  Widget _headerSubRow() {
    return Container(
      color: const Color(0xFFB0898B),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _cell('', 56, white: true),
          _cell('', 250, white: true),
          _cell('', 70, white: true),
          _cell('', 70, white: true),
          _cell('', 110, white: true),
          for (int i = 0; i < _domains.length; i++) ...[
            _cell('Raw', 80, bold: true, white: true),
            _cell('Scaled', 80, bold: true, white: true),
            _cell('Interp', 80, bold: true, white: true),
          ],
          _cell('', 80, white: true),
          _cell('', 90, white: true),
          _cell('', 90, white: true),
          _cell('', 150, white: true),
        ],
      ),
    );
  }

  Widget _dataRow(_TeacherReportRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _cell('${r.no}', 56),
          _cell(r.learnerName, 250, align: TextAlign.left),
          _cell(r.gender, 70),
          _cell(r.ageText, 70),
          _cell(r.testedDate, 110),
          for (final d in _domains) ...[
            _cell('${r.perDomain[d]!.raw}', 80),
            _cell('${r.perDomain[d]!.scaled}', 80),
            _cell(r.perDomain[d]!.interp, 80, bold: true),
          ],
          _cell('${r.totalRaw}', 80, bold: true),
          _cell('${r.sumScaled}', 90, bold: true),
          _cell('${r.standardScore}', 90, bold: true),
          _cell(r.overallInterp, 150, bold: true),
        ],
      ),
    );
  }

  Widget _cell(
    String text,
    double width, {
    bool bold = false,
    bool white = false,
    TextAlign align = TextAlign.center,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: align,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: white ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  String _ageDecimalAtDate(String birthIso, DateTime atDate) {
    final birth = DateTime.tryParse(birthIso);
    if (birth == null) return '-';
    int months = (atDate.year - birth.year) * 12 + (atDate.month - birth.month);
    if (atDate.day < birth.day) months -= 1;
    if (months < 0) months = 0;
    return '${months ~/ 12}.${months % 12}';
  }
}

class _TeacherReportRow {
  final int no;
  final String learnerName;
  final String gender;
  final String ageText;
  final String testedDate;
  final Map<String, _DomainScore> perDomain;
  final int totalRaw;
  final int sumScaled;
  final int standardScore;
  final String overallInterp;

  const _TeacherReportRow({
    required this.no,
    required this.learnerName,
    required this.gender,
    required this.ageText,
    required this.testedDate,
    required this.perDomain,
    required this.totalRaw,
    required this.sumScaled,
    required this.standardScore,
    required this.overallInterp,
  });
}

class _DomainScore {
  final int raw;
  final int scaled;
  final String interp;

  const _DomainScore({
    required this.raw,
    required this.scaled,
    required this.interp,
  });
}

class _AssessmentProgress {
  final bool hasPre;
  final bool hasPost;

  const _AssessmentProgress({required this.hasPre, required this.hasPost});

  bool get isComplete => hasPre && hasPost;

  String get statusLabel {
    if (hasPre && hasPost) {
      return 'Pre-Test and Post-Test accomplished';
    }
    if (hasPre) {
      return 'Pre-Test accomplished - Post-Test pending';
    }
    if (hasPost) {
      return 'Post-Test accomplished - Pre-Test pending';
    }
    return 'Pre-Test and Post-Test pending';
  }
}

class _AssessmentProgressBars extends StatelessWidget {
  final _AssessmentProgress progress;

  const _AssessmentProgressBars({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProgressPill(
            label: 'Pre',
            complete: progress.hasPre,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ProgressPill(
            label: 'Post',
            complete: progress.hasPost,
          ),
        ),
      ],
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final String label;
  final bool complete;

  const _ProgressPill({
    required this.label,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = complete
        ? const Color(0xFF2E7D4F) // Green for complete
        : const Color(0xFFFF9800); // Orange for pending

    final backgroundColor = activeColor.withOpacity(0.12);
    final borderColor = activeColor.withOpacity(0.28);
    final textColor = activeColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: complete ? 1.0 : 0.0,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            complete ? 'Done' : 'Pending',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}


