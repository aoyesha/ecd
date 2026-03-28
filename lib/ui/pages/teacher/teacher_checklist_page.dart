import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/ui_feedback.dart';
import '../../../core/unsaved_guard.dart';
import '../../../data/eccd_questions.dart';
import '../../../db/app_db.dart';
import '../../../db/schema.dart';
import '../../../services/assessment_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/file_export_service.dart';
import '../../../services/learner_service.dart';
import '../../../services/pdf_export_service.dart';
import '../../../services/scoring_service.dart';
import '../../widgets/subpage_shell.dart';

class TeacherChecklistPage extends StatefulWidget {
  final int classId;
  final int learnerId;

  const TeacherChecklistPage({
    super.key,
    required this.classId,
    required this.learnerId,
  });

  @override
  State<TeacherChecklistPage> createState() => _TeacherChecklistPageState();
}

class _TeacherChecklistPageState extends State<TeacherChecklistPage> {
  final _svc = AssessmentService();
  final _pdf = PdfExportService();
  final _file = FileExportService();
  final _learners = LearnerService();
  final _scoring = ScoringService();

  DateTime date = DateTime.now();
  EccdLanguage language = EccdLanguage.english;

  String assessmentUi = 'Pre-Test'; // Pre-Test|Post-Test|Conditional Test
  bool dirty = false;
  bool saving = false;
  bool showMidYear = false;

  int _fallbackAge = 4;
  DateTime? _birthDate;

  late Map<String, List<int>> answers; // 0/1 per question
  String learnerName = ''; // ⭐ ADD

  @override
  void initState() {
    super.initState();
    answers = {
      for (final d in EccdQuestions.domains)
        d: List<int>.filled(EccdQuestions.get(d, language).length, 0),
    };
    _loadInitialData();
    _checkMidYearAvailability(); // ⭐ ADD
  }

  Future<void> _loadInitialData() async {
    await _loadLearnerMeta();
    await _loadSavedAssessment();
  }

  Future<void> _checkMidYearAvailability() async {
    final hasPre = await _svc.hasCompletedAssessment(
      learnerId: widget.learnerId,
      classId: widget.classId,
      assessmentType: 'pre',
    );

    if (!hasPre) {
      setState(() => showMidYear = true);
      return;
    }

    final header = await _svc.getAssessmentHeader(
      learnerId: widget.learnerId,
      classId: widget.classId,
      assessmentType: 'pre',
    );

    if (header == null) {
      setState(() => showMidYear = true);
      return;
    }

    final id = header['id'];
    if (id is! int) return;

    final loaded = await _svc.loadAnswers(assessmentId: id);

    bool isPerfect = true;

    for (final domain in loaded.values) {
      for (final v in domain) {
        if (v != 1) {
          isPerfect = false;
          break;
        }
      }
      if (!isPerfect) break;
    }

    setState(() {
      showMidYear = !isPerfect; // show if NOT perfect
    });
  }

  Future<void> _loadLearnerMeta() async {
    final row = await _learners.getLearner(widget.learnerId);
    if (row == null || !mounted) return;
    final age = row['age'];
    final birthRaw = (row['birth_date'] ?? '').toString();
    setState(() {
      _fallbackAge = age is int ? age : int.tryParse('$age') ?? 4;
      _birthDate = _parseDateFlexible(birthRaw);

      final first = (row['first_name'] ?? '').toString();
      final last = (row['last_name'] ?? '').toString();
      learnerName = '$last, $first'; // ⭐ ADD
    });
  }

  Future<void> _loadSavedAssessment() async {
    final header = await _svc.getAssessmentHeader(
      learnerId: widget.learnerId,
      classId: widget.classId,
      assessmentType: _effectiveType,
    );

    if (!mounted) return;
    if (header == null) {
      setState(() {
        answers = _blankAnswers(language);
      });
      return;
    }

    final id = header['id'];
    if (id is! int) return;

    final loaded = await _svc.loadAnswers(assessmentId: id);
    if (!mounted) return;

    final dateRaw = (header['date_taken'] ?? '').toString();
    final loadedDate = DateTime.tryParse(dateRaw);
    final langRaw = (header['language'] ?? '').toString().toLowerCase();
    final loadedLanguage = langRaw == EccdLanguage.tagalog.name
        ? EccdLanguage.tagalog
        : EccdLanguage.english;

    setState(() {
      language = loadedLanguage;
      date = loadedDate ?? date;
      answers = _normalizeAnswersForLanguage(loaded, language);
      dirty = false;
    });
  }

  String get _effectiveType {
    if (assessmentUi == 'Post-Test') return 'post';
    if (assessmentUi == 'Mid Year Test') return 'conditional';
    return 'pre';
  }

  int _ageAtAssessment() {
    if (_birthDate == null) return _fallbackAge;
    int age = date.year - _birthDate!.year;
    final hadBirthday =
        (date.month > _birthDate!.month) ||
        (date.month == _birthDate!.month && date.day >= _birthDate!.day);
    if (!hadBirthday) age -= 1;
    if (age < 3) return 3;
    return age;
  }

  double _ageValueForScoring() {
    if (_birthDate == null) {
      return _scoring.normalizeAgeValueForScoring(_fallbackAge.toDouble());
    }
    int months =
        (date.year - _birthDate!.year) * 12 + (date.month - _birthDate!.month);
    if (date.day < _birthDate!.day) {
      months -= 1;
    }
    if (months < 0) months = 0;
    final years = months ~/ 12;
    final remMonths = months % 12;
    return _scoring.normalizeAgeValueForScoring(
      double.parse('$years.$remMonths'),
    );
  }

  Future<void> _exportPdf() async {
    if (saving) return;

    if (dirty) {
      _showSnackBar(
        'Please save the checklist before exporting PDF.',
        isError: true,
      );
      return;
    }

    final completed = await _svc.hasCompletedAssessment(
      learnerId: widget.learnerId,
      classId: widget.classId,
      assessmentType: _effectiveType,
    );
    if (!completed) {
      _showSnackBar(
        'Cannot export PDF. No saved checklist found for ${assessmentTypeDisplay(_effectiveType)}.',
        isError: true,
      );
      return;
    }

    try {
      if (!mounted) return;
      final exportingUserId = context.read<AuthService>().session?.userId;
      final bytes = await _pdf.buildLearnerPdf(
        learnerId: widget.learnerId,
        classId: widget.classId,
        assessmentType: _effectiveType,
        language: language,
        exportingUserId: exportingUserId,
      );
      final filename = await _buildLearnerExportFileName();
      final saved = await _file.savePdf(filename: filename, pdfBytes: bytes);
      if (!mounted) return;
      if (saved) {
        _showSnackBar('PDF exported successfully.');
      } else {
        _showSnackBar('PDF export cancelled.');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError
          ? e.message
          : 'PDF export failed. Please try again.';
      _showSnackBar(msg, isError: true);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await _svc.saveAssessment(
        learnerId: widget.learnerId,
        classId: widget.classId,
        assessmentType: _effectiveType,
        dateIso: date.toIso8601String(),
        ageAtAssessment: _ageAtAssessment(),
        ageValueForScoring: _ageValueForScoring(),
        language: language.name,
        answersByDomain: answers,
      );

      if (!mounted) return;
      setState(() {
        saving = false;
        dirty = false;
      });
      _showSnackBar('Checklist saved successfully.');
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      _showSnackBar('Failed to save checklist.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    return UnsavedGuard(
      hasUnsavedChanges: dirty,
      child: SubpageShell(
        title: 'Checklist',
        directorySegments: const ['Dashboard', 'My Classes', 'Checklist'],
        navIndex: 0,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  learnerName.isEmpty ? 'Learner' : learnerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 860;

                  final left = Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _chip(
                        'Date: $dateStr',
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                            initialDate: date,
                          );
                          if (picked != null) {
                            setState(() {
                              date = picked;
                              dirty = true;
                            });
                          }
                        },
                      ),
                      DropdownButton<String>(
                        value: assessmentUi,
                        items: [
                          const DropdownMenuItem(
                            value: 'Pre-Test',
                            child: Text('Pre-Test'),
                          ),
                          const DropdownMenuItem(
                            value: 'Post-Test',
                            child: Text('Post-Test'),
                          ),

                          if (showMidYear)
                            const DropdownMenuItem(
                              value: 'Mid Year Test',
                              child: Text('Mid Year Test'),
                            ),
                        ],
                        onChanged: (v) async {
                          if (v == null) return;
                          setState(() => assessmentUi = v);
                          await _loadSavedAssessment();
                        },
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
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            final prev = answers;
                            language = v;
                            answers = _normalizeAnswersForLanguage(
                              prev,
                              language,
                            );
                            dirty = true;
                          });
                        },
                      ),
                    ],
                  );

                  final right = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _exportPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Export PDF'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.maroon,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: Text(saving ? 'Saving...' : 'Save Checklist'),
                      ),
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        left,
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerRight, child: right),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: left),
                      right,
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: EccdQuestions.domains.length,
                itemBuilder: (context, di) {
                  final domain = EccdQuestions.domains[di];
                  final qs = EccdQuestions.get(domain, language);
                  final a = answers[domain] ?? List<int>.filled(qs.length, 0);

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE6E6E6)),
                    ),
                    child: ExpansionTile(
                      title: Text(
                        domain,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    for (int i = 0; i < a.length; i++) {
                                      a[i] = 1;
                                    }
                                    answers[domain] = a;
                                    dirty = true;
                                  });
                                },
                                child: const Text('Select All'),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    for (int i = 0; i < a.length; i++) {
                                      a[i] = 0;
                                    }
                                    answers[domain] = a;
                                    dirty = true;
                                  });
                                },
                                child: const Text('Unselect All'),
                              ),
                            ],
                          ),
                        ),

                        if (domain == 'Self Help') ...[
                          ..._selfHelpSectionTiles(a),
                        ] else ...[
                          for (int i = 0; i < qs.length; i++)
                            _itemTile(
                              checked: a[i] == 1,
                              title: qs[i],
                              onChanged: (v) {
                                setState(() {
                                  a[i] = (v ?? false) ? 1 : 0;
                                  answers[domain] = a;
                                  dirty = true;
                                });
                              },
                            ),
                        ],
                        const SizedBox(height: 6),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, {VoidCallback? onTap}) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.edit_calendar, size: 18),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  DateTime? _parseDateFlexible(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (slash != null) {
      final a = int.parse(slash.group(1)!);
      final b = int.parse(slash.group(2)!);
      final y = int.parse(slash.group(3)!);
      if (a <= 12 && b <= 31) return DateTime(y, a, b);
      if (a <= 31 && b <= 12) return DateTime(y, b, a);
    }
    return null;
  }

  Map<String, List<int>> _blankAnswers(EccdLanguage lang) {
    return {
      for (final d in EccdQuestions.domains)
        d: List<int>.filled(EccdQuestions.get(d, lang).length, 0),
    };
  }

  Map<String, List<int>> _normalizeAnswersForLanguage(
    Map<String, List<int>> source,
    EccdLanguage lang,
  ) {
    final normalized = <String, List<int>>{};
    for (final d in EccdQuestions.domains) {
      final expectedLen = EccdQuestions.get(d, lang).length;
      final existing = source[d] ?? const <int>[];
      normalized[d] = List<int>.generate(
        expectedLen,
        (i) => i < existing.length ? existing[i] : 0,
      );
    }
    return normalized;
  }

  List<Widget> _selfHelpSectionTiles(List<int> a) {
    final core = EccdQuestions.selfHelpCore(language);
    final sections = EccdQuestions.selfHelpSections(language);
    final widgets = <Widget>[];
    int offset = 0;

    for (int i = 0; i < core.length; i++) {
      widgets.add(
        _itemTile(
          checked: a[i] == 1,
          title: core[i],
          onChanged: (v) {
            setState(() {
              a[i] = (v ?? false) ? 1 : 0;
              answers['Self Help'] = a;
              dirty = true;
            });
          },
        ),
      );
    }
    offset = core.length;

    for (final entry in sections.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Text(
            entry.key,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.maroonDark,
            ),
          ),
        ),
      );
      final items = entry.value;
      for (int i = 0; i < items.length; i++) {
        final idx = offset + i;
        widgets.add(
          _itemTile(
            checked: a[idx] == 1,
            title: items[i],
            onChanged: (v) {
              setState(() {
                a[idx] = (v ?? false) ? 1 : 0;
                answers['Self Help'] = a;
                dirty = true;
              });
            },
          ),
        );
      }
      offset += items.length;
    }
    return widgets;
  }

  Widget _itemTile({
    required bool checked,
    required String title,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      tileColor: checked ? AppColors.maroon.withValues(alpha: 0.08) : null,
      selectedTileColor: AppColors.maroon.withValues(alpha: 0.08),
      value: checked,
      onChanged: onChanged,
      title: Text(title),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    AppFeedback.showSnackBar(
      context,
      message,
      tone: isError ? AppFeedbackTone.error : AppFeedbackTone.success,
    );
  }

  Future<String> _buildLearnerExportFileName() async {
    final learner = await _learners.getLearner(widget.learnerId);
    final classRows = await AppDb.instance.db.query(
      DbSchema.tClasses,
      columns: [DbSchema.cClassSection],
      where: '${DbSchema.cClassId}=?',
      whereArgs: [widget.classId],
      limit: 1,
    );

    final section = classRows.isEmpty
        ? 'Section'
        : (classRows.first[DbSchema.cClassSection] ?? 'Section').toString();
    final lastName = (learner?[DbSchema.cLearnerLastName] ?? 'Learner')
        .toString();
    final firstName = (learner?[DbSchema.cLearnerFirstName] ?? '').toString();
    final lrn = (learner?[DbSchema.cLearnerLrn] ?? '').toString();

    return [
      _slug(section),
      _slug(lastName),
      _slug(firstName),
      _slug(lrn.isEmpty ? 'no_lrn' : lrn),
    ].join('_');
  }

  String _slug(String value) {
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), '_');
    final safe = cleaned.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    return safe.isEmpty ? 'na' : safe;
  }
}
