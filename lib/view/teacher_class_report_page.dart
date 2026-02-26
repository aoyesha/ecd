import 'package:flutter/material.dart';

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../data/eccd_questions.dart';
import '../services/database_service.dart';
import '../services/assessment_service.dart';
import '../services/pdf_service.dart';
import '../util/navbar.dart';

class TeacherClassReportPage extends StatefulWidget {
  final int userId;
  final String role;
  final int classId;
  final String classTitle;

  const TeacherClassReportPage({
    Key? key,
    required this.userId,
    required this.role,
    required this.classId,
    required this.classTitle,
  }) : super(key: key);

  @override
  State<TeacherClassReportPage> createState() => _TeacherClassReportPageState();
}

class _TeacherClassReportPageState extends State<TeacherClassReportPage> {
  String _assessmentType = 'Pre-Test';
  bool _loading = true;

  final Map<String, Map<String, int>> _counts = {};
  List<_SkillRate> _topMost = [];
  List<_SkillRate> _topLeast = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? _questionText(String domain, int qIndex1Based) {
    final list = EccdQuestions.get(domain, EccdLanguage.english);
    final idx = qIndex1Based - 1;
    if (idx < 0 || idx >= list.length) return null;
    return list[idx];
  }

  List<_SkillRate> _allPossibleSkills() {
    final all = <_SkillRate>[];
    for (final d in EccdQuestions.domains) {
      final list = EccdQuestions.get(d, EccdLanguage.english);
      for (int i = 0; i < list.length; i++) {
        all.add(
          _SkillRate(domain: d, questionIndex: i + 1, text: list[i], rate: 0),
        );
      }
    }
    return all;
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final learners = await DatabaseService.instance.getLearnersByClass(
      widget.classId,
    );

    final domainBuckets = <String, Map<String, int>>{
      'Gross Motor': {},
      'Fine Motor': {},
      'Self-Help': {},
      'Receptive Language': {},
      'Expressive Language': {},
      'Cognitive': {},
      'Socio-Emotional': {},
      'Overall': {},
    };

    final Map<String, int> yesCounts = {};
    int learnersWithAssessment = 0;

    for (final l in learners) {
      final learnerId = l['learner_id'] as int;

      final assessmentId = await AssessmentService.getLatestAssessmentId(
        learnerId: learnerId,
        classId: widget.classId,
        assessmentType: _assessmentType,
      );

      if (assessmentId == null) continue;

      final ecd = await AssessmentService.getEcdSummary(
        assessmentId: assessmentId,
      );
      if (ecd == null) continue;

      learnersWithAssessment++;

      void add(String domain, String? interp) {
        final key = (interp ?? 'No Data').trim();
        domainBuckets[domain]![key] = (domainBuckets[domain]![key] ?? 0) + 1;
      }

      add('Gross Motor', ecd['gmd_interpretation'] as String?);
      add('Fine Motor', ecd['fms_interpretation'] as String?);
      add('Self-Help', ecd['shd_interpretation'] as String?);
      add('Receptive Language', ecd['rl_interpretation'] as String?);
      add('Expressive Language', ecd['el_interpretation'] as String?);
      add('Cognitive', ecd['cd_interpretation'] as String?);
      add('Socio-Emotional', ecd['sed_interpretation'] as String?);
      add('Overall', ecd['interpretation'] as String?);

      final results =
          await AssessmentService.getAssessmentResultsByAssessmentId(
            assessmentId,
          );

      for (final r in results) {
        final ans = int.tryParse(r['answer'].toString()) ?? 0;
        if (ans != 1) continue;
        final domain = (r['domain']?.toString() ?? '').trim();
        final qIndex = int.tryParse(r['question_index'].toString()) ?? 0;
        if (domain.isEmpty || qIndex <= 0) continue;

        final key = '$domain|$qIndex';
        yesCounts[key] = (yesCounts[key] ?? 0) + 1;
      }
    }

    // Most/least
    final allSkillRates = <_SkillRate>[];
    if (learnersWithAssessment > 0) {
      for (final entry in yesCounts.entries) {
        final parts = entry.key.split('|');
        if (parts.length != 2) continue;
        final domain = parts[0];
        final qIndex = int.tryParse(parts[1]) ?? 0;

        final text = _questionText(domain, qIndex);
        if (text == null) continue;

        allSkillRates.add(
          _SkillRate(
            domain: domain,
            questionIndex: qIndex,
            text: text,
            rate: entry.value / learnersWithAssessment,
          ),
        );
      }
    }

    allSkillRates.sort((a, b) => b.rate.compareTo(a.rate));
    final topMost = allSkillRates.take(3).toList();

    final leastList = <_SkillRate>[];
    if (learnersWithAssessment > 0) {
      final possible = _allPossibleSkills();
      final Map<String, double> rateMap = {
        for (final s in allSkillRates) '${s.domain}|${s.questionIndex}': s.rate,
      };
      for (final s in possible) {
        final k = '${s.domain}|${s.questionIndex}';
        leastList.add(
          _SkillRate(
            domain: s.domain,
            questionIndex: s.questionIndex,
            text: s.text,
            rate: rateMap[k] ?? 0.0,
          ),
        );
      }
      leastList.sort((a, b) => a.rate.compareTo(b.rate));
    }

    if (!mounted) return;
    setState(() {
      _counts
        ..clear()
        ..addAll(domainBuckets);

      _topMost = topMost;
      _topLeast = leastList.take(3).toList();
      _loading = false;
    });
  }

  Future<void> _exportCsv() async {
    try {
      if (_loading) return;

      final suggestedName =
          'class_summary_${widget.classId}_${_assessmentType.replaceAll(' ', '_')}.csv';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Class Summary (CSV)',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
      );
      if (path == null) return;

      final rows = <List<dynamic>>[];

      rows.add(['ECCD Checklist - Class Summary']);
      rows.add(['Class', widget.classTitle]);
      rows.add(['Assessment', _assessmentType]);
      rows.add(['Generated', DateTime.now().toIso8601String()]);
      rows.add([]);
      rows.add(['Domain', 'Level', 'Count', 'Percent']);

      for (final domain in _counts.keys) {
        final c = _counts[domain] ?? {};
        final total = c.values.fold<int>(0, (a, b) => a + b);
        final entries = c.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        if (entries.isEmpty) {
          rows.add([domain, 'No Data', 0, 0]);
          continue;
        }

        for (final e in entries) {
          final pct = total == 0 ? 0 : (e.value / total) * 100;
          rows.add([domain, e.key, e.value, pct.toStringAsFixed(0)]);
        }
      }

      rows.add([]);
      rows.add(['Most Mastered Skills (Top 3)']);
      rows.add(['Domain', 'Question #', 'Percent', 'Skill']);
      for (final s in _topMost) {
        rows.add([
          s.domain,
          s.questionIndex,
          (s.rate * 100).toStringAsFixed(0),
          s.text,
        ]);
      }

      rows.add([]);
      rows.add(['Least Mastered Skills (Top 3)']);
      rows.add(['Domain', 'Question #', 'Percent', 'Skill']);
      for (final s in _topLeast) {
        rows.add([
          s.domain,
          s.questionIndex,
          (s.rate * 100).toStringAsFixed(0),
          s.text,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      await File(path).writeAsString(csv);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV saved: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportPdf() async {
    try {
      if (_loading) return;

      final suggestedName =
          'class_summary_${widget.classId}_${_assessmentType.replaceAll(' ', '_')}.pdf';

      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Class Summary (PDF)',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (path == null) return;

      final topMost = _topMost
          .map(
            (s) => {
              'domain': s.domain,
              'questionIndex': s.questionIndex,
              'text': s.text,
              'rate': s.rate,
            },
          )
          .toList();

      final topLeast = _topLeast
          .map(
            (s) => {
              'domain': s.domain,
              'questionIndex': s.questionIndex,
              'text': s.text,
              'rate': s.rate,
            },
          )
          .toList();

      final bytes = await PdfService.buildClassSummaryPdfBytes(
        classTitle: widget.classTitle,
        assessmentType: _assessmentType,
        counts: _counts,
        topMost: topMost,
        topLeast: topLeast,
      );

      await File(path).writeAsBytes(bytes);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF saved: $path')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          Navbar(
            selectedIndex: 0,
            onItemSelected: (_) {},
            userId: widget.userId,
            role: widget.role,
          ),
          Expanded(
            child: Column(
              children: [
                _appBar(context),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _body(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBar(BuildContext context) {
    return Container(
      height: 72,
      color: AppColors.maroon,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Class Summary • ${widget.classTitle}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _assessmentType,
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(value: 'Pre-Test', child: Text('Pre-Test')),
                DropdownMenuItem(value: 'Post-Test', child: Text('Post-Test')),
                DropdownMenuItem(
                  value: 'Conditional',
                  child: Text('Conditional'),
                ),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _assessmentType = v);
                await _load();
              },
            ),
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.table_view, color: Colors.white),
            onPressed: _exportCsv,
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            onPressed: _exportPdf,
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _body() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: ListView(
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Development Level Summary ($_assessmentType)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._counts.keys.map(
                    (domain) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _domainRow(domain, _counts[domain] ?? {}),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _skillsCard(),
        ],
      ),
    );
  }

  Widget _domainRow(String domain, Map<String, int> counts) {
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(domain, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (total == 0)
          const Text(
            'No assessments saved yet.',
            style: TextStyle(color: Colors.black54),
          )
        else
          Column(
            children: entries.map((e) {
              final pct = e.value / total;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 170,
                      child: Text(e.key, overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 10,
                          backgroundColor: Colors.black12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 64,
                      child: Text(
                        '${(pct * 100).toStringAsFixed(0)}% (${e.value})',
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _skillsCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Most / Least Mastered Skills (Top 3)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _skillList(title: 'Most Mastered', items: _topMost),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _skillList(title: 'Least Mastered', items: _topLeast),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _skillList({required String title, required List<_SkillRate> items}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Text('No data.', style: TextStyle(color: Colors.black54))
          else
            ...items.map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${s.domain} • Q${s.questionIndex} • ${(s.rate * 100).toStringAsFixed(0)}%',
                    ),
                    Text(s.text, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SkillRate {
  final String domain;
  final int questionIndex;
  final String text;
  final double rate;

  _SkillRate({
    required this.domain,
    required this.questionIndex,
    required this.text,
    required this.rate,
  });
}
