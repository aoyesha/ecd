import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants.dart';
import '../data/eccd_questions.dart';
import '../db/app_db.dart';
import '../db/schema.dart';

class PdfExportService {
  static const _domains = [
    'Gross Motor',
    'Fine Motor',
    'Self Help',
    'Receptive Language',
    'Expressive Language',
    'Cognitive',
    'Social Emotional',
  ];

  Future<Uint8List> buildLearnerPdf({
    required int learnerId,
    required int classId,
    required String assessmentType, // pre|post
    required EccdLanguage language,
  }) async {
    final db = AppDb.instance.db;

    final learner = (await db.query(
      DbSchema.tLearners,
      where: '${DbSchema.cLearnerId}=?',
      whereArgs: [learnerId],
      limit: 1,
    )).first;

    final clazz = (await db.query(
      DbSchema.tClasses,
      where: '${DbSchema.cClassId}=?',
      whereArgs: [classId],
      limit: 1,
    )).first;

    final assess = await db.query(
      DbSchema.tAssessments,
      where:
          '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
      whereArgs: [learnerId, classId, assessmentType],
      limit: 1,
    );
    if (assess.isEmpty) {
      throw StateError(
        'No saved ${assessmentTypeDisplay(assessmentType)} assessment found for this learner.',
      );
    }
    final assessRow = assess.first;
    final assessId = assessRow[DbSchema.cAssessId] as int;

    final domainSummaries = await db.query(
      DbSchema.tDomainSummary,
      where: '${DbSchema.cDomSumAssessId}=?',
      whereArgs: [assessId],
    );

    final overall = (await db.query(
      DbSchema.tAssessmentSummary,
      where: '${DbSchema.cSumAssessId}=?',
      whereArgs: [assessId],
      limit: 1,
    )).first;

    final answers = await db.query(
      DbSchema.tAnswers,
      where: '${DbSchema.cAnsAssessId}=?',
      whereArgs: [assessId],
      orderBy: '${DbSchema.cAnsDomain} ASC, ${DbSchema.cAnsIndex} ASC',
    );

    final answersByDomain = <String, Map<int, int>>{};
    for (final a in answers) {
      final rawDomain = a[DbSchema.cAnsDomain] as String;
      final domain = (rawDomain == 'Dressing' || rawDomain == 'Toilet')
          ? 'Self Help'
          : rawDomain;
      int idx = a[DbSchema.cAnsIndex] as int;
      if (rawDomain == 'Dressing' || rawDomain == 'Toilet') {
        idx += EccdQuestions.selfHelpCore(EccdLanguage.english).length;
      }
      if (rawDomain == 'Toilet') {
        idx += EccdQuestions.get('Dressing', EccdLanguage.english).length;
      }
      answersByDomain.putIfAbsent(domain, () => {});
      answersByDomain[domain]![idx] = a[DbSchema.cAnsValue] as int;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(28),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (_) => [
          _headerBlock(clazz),
          pw.SizedBox(height: 10),
          _learnerInfoBlock(learner, clazz),
          pw.SizedBox(height: 14),
          _summaryTableBlock(
            assessmentType: assessmentType,
            domainSummaries: domainSummaries,
            overallScaled: overall[DbSchema.cSumOverallScaled] as int,
            standardScore: overall[DbSchema.cSumStandardScore] as int,
            overallInterp:
                overall[DbSchema.cSumOverallInterpretation] as String,
            dateIso: assessRow[DbSchema.cAssessDate] as String,
            ageAt: assessRow[DbSchema.cAssessAgeAt] as int,
          ),
          pw.SizedBox(height: 12),
          _interpretationLegendBlock(),
          pw.SizedBox(height: 14),
          _perDomainChecklistBlock(
            language: language,
            answersByDomain: answersByDomain,
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _headerBlock(Map<String, Object?> clazz) {
    // Mirrors the official header region/school-year block style. :contentReference[oaicite:6]{index=6}
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Republic of the Philippines',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Department of Education',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text('Region IV-MIMAROPA', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 6),
        pw.Text(
          'S.Y. ${clazz[DbSchema.cClassSchoolYear]}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _learnerInfoBlock(
    Map<String, Object?> learner,
    Map<String, Object?> clazz,
  ) {
    // Matches learner fields region in template. :contentReference[oaicite:7]{index=7}
    final name =
        '${learner[DbSchema.cLearnerLastName]}, ${learner[DbSchema.cLearnerFirstName]}';
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'LEARNER PROFILE',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Name: $name'),
          pw.Text('Gender: ${learner[DbSchema.cLearnerGender]}'),
          pw.Text('Age: ${learner[DbSchema.cLearnerAge]}'),
          pw.Text(
            'Section: ${clazz[DbSchema.cClassSection]}   Grade: ${clazz[DbSchema.cClassGrade]}',
          ),
        ],
      ),
    );
  }

  pw.Widget _summaryTableBlock({
    required String assessmentType,
    required List<Map<String, Object?>> domainSummaries,
    required int overallScaled,
    required int standardScore,
    required String overallInterp,
    required String dateIso,
    required int ageAt,
  }) {
    // Mirrors “SUMMARY OF ASSESSMENT” block. :contentReference[oaicite:8]{index=8}
    final rows = <List<String>>[
      ['DOMAIN', 'RS', 'SC', 'INTERPRETATION'],
    ];

    for (final d in _domains) {
      final match = domainSummaries.where((x) {
        final raw = (x[DbSchema.cDomSumDomain] ?? '').toString();
        final normalized = (raw == 'Dressing' || raw == 'Toilet')
            ? 'Self Help'
            : raw;
        return normalized == d;
      }).toList();
      if (match.isEmpty) continue;
      final m = match.first;
      rows.add([
        d,
        '${m[DbSchema.cDomSumRaw]}',
        '${m[DbSchema.cDomSumScaled]}',
        '${m[DbSchema.cDomSumInterp]}',
      ]);
    }

    rows.add(['Sum of Scaled Scores', '', '$overallScaled', '']);
    rows.add(['Standard Score', '', '$standardScore', overallInterp]);
    rows.add(['Date Tested', '', _safeDate(dateIso), '']);
    rows.add(['Age', '', '$ageAt', '']);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SUMMARY OF ASSESSMENT (${assessmentTypeDisplay(assessmentType).toUpperCase()})',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Table.fromTextArray(
          headers: rows.first,
          data: rows.skip(1).toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(3.2),
            1: const pw.FlexColumnWidth(0.7),
            2: const pw.FlexColumnWidth(0.7),
            3: const pw.FlexColumnWidth(1.6),
          },
          border: pw.TableBorder.all(color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'RS – Raw Score   SC – Scaled Score',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  pw.Widget _interpretationLegendBlock() {
    // Standard score interpretation legend. :contentReference[oaicite:9]{index=9}
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'INTERPRETATION OF STANDARD SCORE / DEVELOPMENT INDEX',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '130 and above  — Suggest Highly Advanced Development (S.H.A.D.)',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '120 - 129       — Suggest Slightly Advanced Development (S.S.A.D.)',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '80  - 119       — Average Overall Development (A.D.)',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '70  - 79        — Suggest Slight Delay in Overall Development (S.S.D.O.D.)',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            '69 and below    — Suggest Significant Delay in Overall Development (S.S.O.O.D.)',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  pw.Widget _perDomainChecklistBlock({
    required EccdLanguage language,
    required Map<String, Map<int, int>> answersByDomain,
  }) {
    final blocks = <pw.Widget>[];
    for (final domain in _domains) {
      final a = answersByDomain[domain] ?? {};
      if (domain == 'Self Help') {
        final core = EccdQuestions.selfHelpCore(language);
        final sections = EccdQuestions.selfHelpSections(language);
        int offset = 0;
        blocks.add(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 10),
              pw.Text(
                'SELF HELP DOMAIN',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey600),
                columnWidths: {
                  0: const pw.FlexColumnWidth(0.7),
                  1: const pw.FlexColumnWidth(5),
                  2: const pw.FlexColumnWidth(0.9),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      _cell('No.', bold: true),
                      _cell('Item', bold: true),
                      _cell('âœ“', bold: true),
                    ],
                  ),
                  for (int i = 0; i < core.length; i++)
                    pw.TableRow(
                      children: [
                        _cell('${i + 1}'),
                        _cell(core[i]),
                        _cell((a[i] ?? 0) == 1 ? 'âœ“' : ''),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
        offset = core.length;
        for (final entry in sections.entries) {
          final qs = entry.value;
          blocks.add(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(height: 10),
                pw.Text(
                  'SELF HELP - ${entry.key.toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey600),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.7),
                    1: const pw.FlexColumnWidth(5),
                    2: const pw.FlexColumnWidth(0.9),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        _cell('No.', bold: true),
                        _cell('Item', bold: true),
                        _cell('âœ“', bold: true),
                      ],
                    ),
                    for (int i = 0; i < qs.length; i++)
                      pw.TableRow(
                        children: [
                          _cell('${i + 1}'),
                          _cell(qs[i]),
                          _cell((a[offset + i] ?? 0) == 1 ? 'âœ“' : ''),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          );
          offset += qs.length;
        }
        continue;
      }

      final qs = EccdQuestions.get(domain, language);
      blocks.add(
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 10),
            pw.Text(
              '$domain DOMAIN',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey600),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.7),
                1: const pw.FlexColumnWidth(5),
                2: const pw.FlexColumnWidth(0.9),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _cell('No.', bold: true),
                    _cell('Item', bold: true),
                    _cell('✓', bold: true),
                  ],
                ),
                for (int i = 0; i < qs.length; i++)
                  pw.TableRow(
                    children: [
                      _cell('${i + 1}'),
                      _cell(qs[i]),
                      _cell((a[i] ?? 0) == 1 ? '✓' : ''),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return pw.Column(children: blocks);
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _safeDate(String iso) {
    // Minimal display; keeps it stable without extra deps
    return iso.length >= 10 ? iso.substring(0, 10) : iso;
  }
}
