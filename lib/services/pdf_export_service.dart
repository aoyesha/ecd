import 'package:flutter/services.dart';
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
    required String assessmentType,
    required EccdLanguage language,
    int? exportingUserId,
  }) async {
    final doc = pw.Document();
    await _appendLearnerPages(
      doc: doc,
      learnerId: learnerId,
      classId: classId,
      assessmentType: assessmentType,
      language: language,
      exportingUserId: exportingUserId,
    );
    return doc.save();
  }

  Future<Uint8List> buildClassLearnersPdf({
    required int classId,
    required String assessmentType,
    required EccdLanguage language,
    int? exportingUserId,
  }) async {
    final db = AppDb.instance.db;
    final learners = await db.query(
      DbSchema.tLearners,
      columns: [DbSchema.cLearnerId],
      where: '${DbSchema.cLearnerClassId}=? AND ${DbSchema.cLearnerStatus}=?',
      whereArgs: [classId, 'active'],
      orderBy:
          '${DbSchema.cLearnerLastName} ASC, ${DbSchema.cLearnerFirstName} ASC',
    );

    if (learners.isEmpty) {
      throw StateError('There are no active learners in this class to export.');
    }

    final doc = pw.Document();
    int exportedCount = 0;
    for (final learner in learners) {
      final learnerId = learner[DbSchema.cLearnerId] as int;
      try {
        await _appendLearnerPages(
          doc: doc,
          learnerId: learnerId,
          classId: classId,
          assessmentType: assessmentType,
          language: language,
          exportingUserId: exportingUserId,
        );
        exportedCount++;
      } on StateError {
        continue;
      }
    }

    if (exportedCount == 0) {
      throw StateError(
        'No saved ${assessmentTypeDisplay(assessmentType)} assessments were found for the active learners in this class.',
      );
    }

    return doc.save();
  }

  Future<void> _appendLearnerPages({
    required pw.Document doc,
    required int learnerId,
    required int classId,
    required String assessmentType,
    required EccdLanguage language,
    int? exportingUserId,
  }) async {
    final type = assessmentType.trim().toLowerCase();
    final t = _Txt(language);
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
    final teacherRows = await db.query(
      DbSchema.tUsers,
      where: '${DbSchema.cUserId}=?',
      whereArgs: [clazz[DbSchema.cClassTeacherId]],
      limit: 1,
    );
    final teacher = teacherRows.isEmpty
        ? <String, Object?>{}
        : teacherRows.first;
    Map<String, Object?> exportingUser = teacher;
    if (exportingUserId != null) {
      final exportingRows = await db.query(
        DbSchema.tUsers,
        where: '${DbSchema.cUserId}=?',
        whereArgs: [exportingUserId],
        limit: 1,
      );
      if (exportingRows.isNotEmpty) {
        exportingUser = exportingRows.first;
      }
    }

    final snaps = {
      'pre': await _snap(learnerId, classId, 'pre'),
      'post': await _snap(learnerId, classId, 'post'),
      'conditional': await _snap(learnerId, classId, 'conditional'),
    };
    final cur = snaps[type];
    if (cur == null) {
      throw StateError(
        'No saved ${assessmentTypeDisplay(type)} assessment found for this learner.',
      );
    }

    final divLogo = await _img(
      _logoPathForDivision(_v(exportingUser, DbSchema.cUserDivision)),
    );
    final regLogo = await _img('assets/mimaropa_logo.png');
    final kindergartenTop = await _imgAny([
      'assets/kindergarte.png',
      'assets/kindergarten.png',
    ]);
    final kindergartenBottom = await _imgAny([
      'assets/kindergarted_pic.png',
      'assets/pupils.png',
    ]);
    final theme = pw.PageTheme(
      pageFormat: PdfPageFormat.legal.landscape,
      margin: const pw.EdgeInsets.all(12),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    final source = <String, Map<String, Map<int, int>>>{
      'pre': (snaps['pre']?.answersByDomain ?? {}),
      'post': (snaps['post']?.answersByDomain ?? {}),
      'conditional': (snaps['conditional']?.answersByDomain ?? {}),
    };

    doc.addPage(
      pw.Page(
        pageTheme: theme,
        build: (_) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _domain('Social Emotional', language, source, t),
                    pw.SizedBox(height: 4),
                    _domain('Receptive Language', language, source, t),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _summary(snaps, t, learner),
                    pw.SizedBox(height: 5),
                    _interpLines(t),
                    pw.SizedBox(height: 5),
                    _standardScoreInterpretation(t),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _header(
                      clazz,
                      exportingUser,
                      t,
                      divLogo,
                      regLogo,
                      kindergartenTop,
                      kindergartenBottom,
                    ),
                    pw.SizedBox(height: 5),
                    _learnerInfo(learner, clazz, t),
                    pw.SizedBox(height: 5),
                    _forParents(t),
                    pw.SizedBox(height: 6),
                    _sign(teacher, t),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    doc.addPage(
      pw.Page(
        pageTheme: theme,
        build: (_) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _domain('Gross Motor', language, source, t),
                    pw.SizedBox(height: 4),
                    _domain('Fine Motor', language, source, t),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  children: [_domain('Self Help', language, source, t)],
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _domain('Expressive Language', language, source, t),
                    pw.SizedBox(height: 4),
                    _domain('Cognitive', language, source, t),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<_Snap?> _snap(int learnerId, int classId, String type) async {
    final db = AppDb.instance.db;
    final a = await db.query(
      DbSchema.tAssessments,
      where:
          '${DbSchema.cAssessLearnerId}=? AND ${DbSchema.cAssessClassId}=? AND ${DbSchema.cAssessType}=?',
      whereArgs: [learnerId, classId, type],
      limit: 1,
    );
    if (a.isEmpty) return null;
    final aid = a.first[DbSchema.cAssessId] as int;
    final dom = await db.query(
      DbSchema.tDomainSummary,
      where: '${DbSchema.cDomSumAssessId}=?',
      whereArgs: [aid],
    );
    final overall = (await db.query(
      DbSchema.tAssessmentSummary,
      where: '${DbSchema.cSumAssessId}=?',
      whereArgs: [aid],
      limit: 1,
    )).first;
    final ans = await db.query(
      DbSchema.tAnswers,
      where: '${DbSchema.cAnsAssessId}=?',
      whereArgs: [aid],
      orderBy: '${DbSchema.cAnsDomain} ASC, ${DbSchema.cAnsIndex} ASC',
    );

    final byDom = <String, Map<int, int>>{};
    for (final r in ans) {
      final rd = r[DbSchema.cAnsDomain] as String;
      final d = (rd == 'Dressing' || rd == 'Toilet') ? 'Self Help' : rd;
      int i = r[DbSchema.cAnsIndex] as int;
      if (rd == 'Dressing' || rd == 'Toilet')
        i += EccdQuestions.selfHelpCore(EccdLanguage.english).length;
      if (rd == 'Toilet')
        i += EccdQuestions.get('Dressing', EccdLanguage.english).length;
      byDom.putIfAbsent(d, () => {});
      byDom[d]![i] = r[DbSchema.cAnsValue] as int;
    }

    return _Snap(
      type: type,
      assess: a.first,
      overall: overall,
      domRows: {for (final x in dom) (x[DbSchema.cDomSumDomain] as String): x},
      answersByDomain: byDom,
    );
  }

  pw.Widget _header(
    Map<String, Object?> clazz,
    Map<String, Object?> orgUser,
    _Txt t,
    pw.MemoryImage? left,
    pw.MemoryImage? right,
    pw.MemoryImage? topImage,
    pw.MemoryImage? bottomImage,
  ) {
    final region = _v(orgUser, DbSchema.cUserRegion).isEmpty
        ? 'MIMAROPA'
        : _v(orgUser, DbSchema.cUserRegion);
    final division = _v(orgUser, DbSchema.cUserDivision);
    final district = _v(orgUser, DbSchema.cUserDistrict);
    final school = _v(orgUser, DbSchema.cUserSchool);
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _logo(left),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(t.republic, style: const pw.TextStyle(fontSize: 8.7)),
                pw.Text(t.department, style: const pw.TextStyle(fontSize: 8.7)),
                pw.Text(region, style: const pw.TextStyle(fontSize: 8.7)),
                if (division.isNotEmpty)
                  pw.Text(
                    '${t.division}: $division',
                    style: const pw.TextStyle(fontSize: 8.7),
                  ),
                if (district.isNotEmpty)
                  pw.Text(
                    '${t.district}: $district',
                    style: const pw.TextStyle(fontSize: 8.7),
                  ),
                if (school.isNotEmpty)
                  pw.Text(
                    school.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 9.2,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                pw.Text(
                  'S.Y. ${clazz[DbSchema.cClassSchoolYear]}',
                  style: pw.TextStyle(
                    fontSize: 8.9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (topImage != null) ...[
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: pw.Container(
                      height: 56,
                      child: pw.Image(topImage, fit: pw.BoxFit.contain),
                    ),
                  ),
                ],
                pw.SizedBox(height: 2),
                pw.Text(
                  t.checklist,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 9.2,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (bottomImage != null) ...[
                  pw.SizedBox(height: 5),
                  pw.Center(
                    child: pw.Container(
                      height: 60,
                      child: pw.Image(bottomImage, fit: pw.BoxFit.contain),
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(width: 6),
          _logo(right),
        ],
      ),
    );
  }

  pw.Widget _logo(pw.MemoryImage? img) {
    if (img == null) return pw.SizedBox(width: 48, height: 48);
    return pw.SizedBox(
      width: 48,
      height: 48,
      child: pw.Image(img, fit: pw.BoxFit.contain),
    );
  }

  pw.Widget _learnerInfo(
    Map<String, Object?> l,
    Map<String, Object?> c,
    _Txt t,
  ) {
    final sectionRaw = _v(c, DbSchema.cClassSection).isNotEmpty
        ? _v(c, DbSchema.cClassSection)
        : '${c[DbSchema.cClassGrade]}-${c[DbSchema.cClassSection]}';
    final section = sectionRaw
        .replaceAll(
          RegExp(r'\bkindergarten\b\s*[-:]?\s*', caseSensitive: false),
          '',
        )
        .trim();
    final dominantRaw = _v(l, DbSchema.cLearnerDominantHand).toLowerCase();
    final leftChecked =
        dominantRaw.contains('left') || dominantRaw.contains('kaliwa');
    final rightChecked =
        dominantRaw.contains('right') || dominantRaw.contains('kanan');
    final parentName = _v(l, DbSchema.cLearnerParentName);
    final parentOccupation = _v(l, DbSchema.cLearnerParentOccupation);
    final parentEducation = _v(l, DbSchema.cLearnerParentEducation);
    final guardianName = _v(l, DbSchema.cLearnerGuardianName);
    final guardianOccupation = _v(l, DbSchema.cLearnerGuardianOccupation);
    final guardianEducation = _v(l, DbSchema.cLearnerGuardianEducation);
    final motherName = _v(l, DbSchema.cLearnerMotherName);
    final motherOccupation = _v(l, DbSchema.cLearnerMotherOccupation);
    final motherEducation = _v(l, DbSchema.cLearnerMotherEducation);
    final fatherName = _v(l, DbSchema.cLearnerFatherName);
    final fatherOccupation = _v(l, DbSchema.cLearnerFatherOccupation);
    final fatherEducation = _v(l, DbSchema.cLearnerFatherEducation);
    final hasGuardian =
        guardianName.isNotEmpty ||
        guardianOccupation.isNotEmpty ||
        guardianEducation.isNotEmpty;

    pw.Widget line(String label, String value, {double labelWidth = 130}) {
      final v = value.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: labelWidth,
              child: pw.Text(
                '$label:',
                style: const pw.TextStyle(fontSize: 8.8),
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 1),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                  ),
                ),
                child: pw.Text(v, style: const pw.TextStyle(fontSize: 8.8)),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          line(t.lrn, _v(l, DbSchema.cLearnerLrn)),
          line(t.name, _full(l)),
          pw.Row(
            children: [
              pw.Expanded(
                child: line(
                  t.gender,
                  _v(l, DbSchema.cLearnerGender),
                  labelWidth: 62,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: line(t.age, _v(l, DbSchema.cLearnerAge), labelWidth: 40),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                flex: 2,
                child: line(t.section, section, labelWidth: 54),
              ),
            ],
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.SizedBox(
                  width: 130,
                  child: pw.Text(
                    '${t.dominantHand}:',
                    style: const pw.TextStyle(fontSize: 8.8),
                  ),
                ),
                pw.Expanded(
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: _checkboxChoice(t.leftLabel, leftChecked),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: _checkboxChoice(t.rightLabel, rightChecked),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          line(t.address, _v(l, DbSchema.cLearnerBarangay)),
          if (hasGuardian) ...[
            line(t.parent, parentName),
            line(t.parentOcc, parentOccupation),
            line(t.parentEdu, parentEducation),
            line(t.guardian, guardianName),
            line(t.guardianOcc, guardianOccupation),
            line(t.guardianEdu, guardianEducation),
          ] else ...[
            line(t.mother, motherName),
            line(t.motherOcc, motherOccupation),
            line(t.motherEdu, motherEducation),
            line(t.father, fatherName),
            line(t.fatherOcc, fatherOccupation),
            line(t.fatherEdu, fatherEducation),
          ],
          line(t.motherAgeAtBirth, _v(l, DbSchema.cLearnerAgeMotherAtBirth)),
        ],
      ),
    );
  }

  pw.Widget _summary(
    Map<String, _Snap?> snaps,
    _Txt t,
    Map<String, Object?> learner,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          t.summary,
          style: pw.TextStyle(fontSize: 11.2, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.3),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.4),
            3: pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _c(t.domains, b: true),
                _c(t.firstCol, b: true),
                _c(t.secondCol, b: true),
                _c(t.thirdCol, b: true),
              ],
            ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600),
          columnWidths: {
            0: const pw.FlexColumnWidth(2.3),
            1: const pw.FlexColumnWidth(0.7),
            2: const pw.FlexColumnWidth(0.7),
            3: const pw.FlexColumnWidth(0.7),
            4: const pw.FlexColumnWidth(0.7),
            5: const pw.FlexColumnWidth(0.7),
            6: const pw.FlexColumnWidth(0.7),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _c('', b: true),
                _c('RS', b: true),
                _c('SC', b: true),
                _c('RS', b: true),
                _c('SC', b: true),
                _c('RS', b: true),
                _c('SC', b: true),
              ],
            ),
            for (final d in _domains)
              pw.TableRow(
                children: [
                  _c(d),
                  _c(_domainRaw(snaps['pre'], d)),
                  _c(_domainScaled(snaps['pre'], d)),
                  _c(_domainRaw(snaps['post'], d)),
                  _c(_domainScaled(snaps['post'], d)),
                  _c(_domainRaw(snaps['conditional'], d)),
                  _c(_domainScaled(snaps['conditional'], d)),
                ],
              ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.3),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.4),
            3: pw.FlexColumnWidth(1.4),
          },
          children: [
            pw.TableRow(
              children: [
                _c(t.sumScaled),
                _c(_overallScaled(snaps['pre'])),
                _c(_overallScaled(snaps['post'])),
                _c(_overallScaled(snaps['conditional'])),
              ],
            ),
            pw.TableRow(
              children: [
                _c(t.standardScore),
                _c(_overallStandard(snaps['pre'])),
                _c(_overallStandard(snaps['post'])),
                _c(_overallStandard(snaps['conditional'])),
              ],
            ),
            pw.TableRow(
              children: [
                _c(t.dateTested),
                _c(_date(snaps['pre'])),
                _c(_date(snaps['post'])),
                _c(_date(snaps['conditional'])),
              ],
            ),
            pw.TableRow(
              children: [
                _c(t.age),
                _c(_ageYm(snaps['pre'], learner)),
                _c(_ageYm(snaps['post'], learner)),
                _c(_ageYm(snaps['conditional'], learner)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'RS - Raw Score   SC - Scaled Score   UP - Pre   PP - Post   HP - Cond',
          style: const pw.TextStyle(fontSize: 8.8),
        ),
      ],
    );
  }

  pw.Widget _interpLines(_Txt t) {
    pw.Widget b(String x) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$x:',
          style: pw.TextStyle(fontSize: 8.6, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text('_' * 69, style: const pw.TextStyle(fontSize: 8)),
        pw.Text('_' * 69, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Center(
            child: pw.Text(
              t.interpretation,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          b(t.firstAssessment),
          pw.SizedBox(height: 2),
          b(t.secondAssessment),
          pw.SizedBox(height: 2),
          b(t.thirdAssessment),
        ],
      ),
    );
  }

  pw.Widget _standardScoreInterpretation(_Txt t) => pw.Container(
    padding: const pw.EdgeInsets.all(6),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey600),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'INTERPRETATION OF STANDARD SCORE OR',
            style: pw.TextStyle(fontSize: 9.4, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Center(
          child: pw.Text(
            'DEVELOPMENT INDEX',
            style: pw.TextStyle(fontSize: 9.4, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(2.2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _c('STANDARD SCORE', b: true),
                _c('INTERPRETATION', b: true),
              ],
            ),
            pw.TableRow(
              children: [
                _c('130 and above'),
                _c('Suggest Highly Advanced Development (S.H.A.D.)'),
              ],
            ),
            pw.TableRow(
              children: [
                _c('120 - 129'),
                _c('Suggests Slightly Advanced Development(S.S.A.D.)'),
              ],
            ),
            pw.TableRow(
              children: [
                _c('80 - 119'),
                _c('Average Overall Development (A.D.)'),
              ],
            ),
            pw.TableRow(
              children: [
                _c('70 - 79'),
                _c('Suggest Slight Delay In Overall Development(S.S.D.O.D.)'),
              ],
            ),
            pw.TableRow(
              children: [
                _c('69 and below'),
                _c(
                  'Suggest Significant Delay In Overall Development(S.S.O.O.D.)',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  pw.Widget _forParents(_Txt t) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        t.forParents,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Container(
        padding: const pw.EdgeInsets.all(7),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey600),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Text(
          t.parentsBody,
          style: const pw.TextStyle(fontSize: 8.2),
          textAlign: pw.TextAlign.justify,
        ),
      ),
    ],
  );

  pw.Widget _sign(Map<String, Object?> teacher, _Txt t) {
    final tn = _v(teacher, DbSchema.cUserName).toUpperCase();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Column(
        children: [
          pw.Text(
            tn.isEmpty ? '_' * 26 : tn,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(decoration: pw.TextDecoration.underline),
          ),
          pw.Text(
            t.teacher,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 14),
          pw.Text('_' * 26, textAlign: pw.TextAlign.center),
          pw.Text(
            t.principal,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  pw.Widget _domain(
    String d,
    EccdLanguage lang,
    Map<String, Map<String, Map<int, int>>> src,
    _Txt t,
  ) {
    final qs = EccdQuestions.get(d, lang);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '${d.toUpperCase()} ${t.domain}',
          style: pw.TextStyle(fontSize: 10.0, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 1),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FlexColumnWidth(0.9),
            1: pw.FlexColumnWidth(5.4),
            2: pw.FlexColumnWidth(0.7),
            3: pw.FlexColumnWidth(0.7),
            4: pw.FlexColumnWidth(0.7),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _c(t.no, b: true),
                _c(t.items, b: true),
                _c('UP', b: true),
                _c('PP', b: true),
                _c('HP', b: true),
              ],
            ),
            for (int i = 0; i < qs.length; i++)
              pw.TableRow(
                children: [
                  _c('${i + 1}'),
                  _c(qs[i]),
                  _c((src['pre']?[d]?[i] ?? 0) == 1 ? '/' : '', center: true),
                  _c((src['post']?[d]?[i] ?? 0) == 1 ? '/' : '', center: true),
                  _c(
                    (src['conditional']?[d]?[i] ?? 0) == 1 ? '/' : '',
                    center: true,
                  ),
                ],
              ),
          ],
        ),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600),
          columnWidths: const {
            0: pw.FlexColumnWidth(6.3),
            1: pw.FlexColumnWidth(0.7),
            2: pw.FlexColumnWidth(0.7),
            3: pw.FlexColumnWidth(0.7),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                _c(t.scoreRow, b: true),
                _c('${_domainScore(src['pre'], d, qs.length)}', b: true),
                _c('${_domainScore(src['post'], d, qs.length)}', b: true),
                _c(
                  '${_domainScore(src['conditional'], d, qs.length)}',
                  b: true,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  int _domainScore(
    Map<String, Map<int, int>>? answersByDomain,
    String domain,
    int itemCount,
  ) {
    if (answersByDomain == null) return 0;
    int sum = 0;
    for (int i = 0; i < itemCount; i++) {
      sum += (answersByDomain[domain]?[i] ?? 0);
    }
    return sum;
  }

  String _domainRaw(_Snap? snap, String domain) {
    if (snap == null) return '';
    return '${snap.domRows[domain]?[DbSchema.cDomSumRaw] ?? ''}';
  }

  String _domainScaled(_Snap? snap, String domain) {
    if (snap == null) return '';
    return '${snap.domRows[domain]?[DbSchema.cDomSumScaled] ?? ''}';
  }

  String _overallScaled(_Snap? snap) =>
      snap == null ? '' : '${snap.overall[DbSchema.cSumOverallScaled] ?? ''}';

  String _overallStandard(_Snap? snap) =>
      snap == null ? '' : '${snap.overall[DbSchema.cSumStandardScore] ?? ''}';

  String _date(_Snap? snap) =>
      snap == null ? '' : _safe('${snap.assess[DbSchema.cAssessDate] ?? ''}');

  String _age(_Snap? snap) =>
      snap == null ? '' : '${snap.assess[DbSchema.cAssessAgeAt] ?? ''}';

  String _ageYm(_Snap? snap, Map<String, Object?> learner) {
    if (snap == null) return '';
    final birthRaw = _v(learner, DbSchema.cLearnerBirthDate);
    if (birthRaw.isEmpty) return _age(snap);
    final b = DateTime.tryParse(birthRaw);
    final d = DateTime.tryParse('${snap.assess[DbSchema.cAssessDate] ?? ''}');
    if (b == null || d == null) return _age(snap);
    int months = (d.year - b.year) * 12 + (d.month - b.month);
    if (d.day < b.day) months -= 1;
    if (months < 0) months = 0;
    final years = months ~/ 12;
    final rem = months % 12;
    return '$years.$rem';
  }

  pw.Widget _c(String s, {bool b = false, bool center = false}) => pw.Container(
    padding: const pw.EdgeInsets.all(2.0),
    alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
    child: pw.Text(
      s,
      textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
      style: pw.TextStyle(
        fontSize: 8.2,
        fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );

  Future<pw.MemoryImage?> _img(String p) async {
    try {
      final b = await rootBundle.load(p);
      return pw.MemoryImage(b.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  Future<pw.MemoryImage?> _imgAny(List<String> paths) async {
    for (final p in paths) {
      final img = await _img(p);
      if (img != null) return img;
    }
    return null;
  }

  pw.Widget _checkboxChoice(String label, bool checked) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 1),
    child: pw.Text(
      '[${checked ? '/' : ' '}] $label',
      style: const pw.TextStyle(fontSize: 8.8),
    ),
  );

  String _v(Map<String, Object?> r, String k) => (r[k] ?? '').toString().trim();

  String _full(Map<String, Object?> l) => [
    _v(l, DbSchema.cLearnerFirstName),
    _v(l, DbSchema.cLearnerMiddleName),
    _v(l, DbSchema.cLearnerLastName),
  ].where((e) => e.isNotEmpty).join(' ');
  String _safe(String iso) => iso.length >= 10 ? iso.substring(0, 10) : iso;

  String _logoPathForDivision(String division) {
    final d = division.toLowerCase();
    if (d.contains('oriental')) return 'assets/oriental_min_logo.gif';
    if (d.contains('occidental')) return 'assets/occidental_min_logo.png';
    if (d.contains('marinduque')) return 'assets/marinduque_logo.jpg';
    if (d.contains('romblon')) return 'assets/romblon_logo.jpg';
    if (d.contains('palawan')) return 'assets/palawan_logo.png';
    if (d.contains('calapan')) return 'assets/calapan_logo.jpeg';
    if (d.contains('puerto')) return 'assets/puerto_prinsesa.jpg';
    if (d.contains('mimaropa')) return 'assets/mimaropa_logo.png';
    return 'assets/puerto_prinsesa.jpg';
  }
}

class _Snap {
  final String type;
  final Map<String, Object?> assess;
  final Map<String, Object?> overall;
  final Map<String, Map<String, Object?>> domRows;
  final Map<String, Map<int, int>> answersByDomain;
  _Snap({
    required this.type,
    required this.assess,
    required this.overall,
    required this.domRows,
    required this.answersByDomain,
  });
}

class _Txt {
  final String republic = 'Republic of the Philippines';
  final String department = 'Department of Education';
  final String division = 'Division';
  final String district = 'District';
  final String checklist =
      'Early Childhood Care and Development (ECD) Checklist';
  final String lrn;
  final String name;
  final String gender;
  final String age;
  final String section;
  final String dominantHand;
  final String leftLabel;
  final String rightLabel;
  final String address;
  final String parent;
  final String parentOcc;
  final String parentEdu;
  final String guardian;
  final String guardianOcc;
  final String guardianEdu;
  final String mother;
  final String motherOcc;
  final String motherEdu;
  final String father;
  final String fatherOcc;
  final String fatherEdu;
  final String motherAgeAtBirth;
  final String summary = 'SUMMARY OF ASSESSMENT';
  final String interpretation = 'INTERPRETATION';
  final String domain = 'DOMAIN';
  final String domains;
  final String sumScaled = 'Sum of Scaled Scores';
  final String standardScore = 'Standard Score';
  final String dateTested = 'Date Tested';
  final String no = 'No.';
  final String items = 'Items';
  final String firstCol;
  final String secondCol;
  final String thirdCol;
  final String scoreRow;
  final String firstAssessment;
  final String secondAssessment;
  final String thirdAssessment;
  final String forParents = 'For Parents';
  final String parentsBody =
      'The Philippine Early Childhood Checklist (Form 2) contains developmental skills, behavior, and knowledge of children aged 3 to 5.11 years old. Use this as a guide in understanding your child and in providing proper care, teaching, and support for growth and development.';
  final String principal = 'PRINCIPAL';
  final String teacher = 'TEACHER';

  _Txt(EccdLanguage lang)
    : lrn = 'LRN',
      name = lang == EccdLanguage.tagalog ? 'Pangalan' : 'Name',
      gender = lang == EccdLanguage.tagalog ? 'Kasarian' : 'Gender',
      age = lang == EccdLanguage.tagalog ? 'Edad' : 'Age',
      section = lang == EccdLanguage.tagalog ? 'Seksyon' : 'Section',
      dominantHand = lang == EccdLanguage.tagalog
          ? 'Ginagamit na kamay'
          : 'Dominant hand',
      leftLabel = lang == EccdLanguage.tagalog ? 'Kaliwa' : 'Left',
      rightLabel = lang == EccdLanguage.tagalog ? 'Kanan' : 'Right',
      address = lang == EccdLanguage.tagalog ? 'Tirahan' : 'Address',
      parent = lang == EccdLanguage.tagalog ? 'Magulang' : 'Parent',
      parentOcc = lang == EccdLanguage.tagalog
          ? 'Hanapbuhay ng Magulang'
          : 'Parent Occupation',
      parentEdu = lang == EccdLanguage.tagalog
          ? 'Pinakamataas na Natapos na Pag-aaral ng Magulang'
          : 'Parent Highest Educational Attainment',
      guardian = lang == EccdLanguage.tagalog ? 'Tagapag-alaga' : 'Guardian',
      guardianOcc = lang == EccdLanguage.tagalog
          ? 'Hanapbuhay ng Tagapag-alaga'
          : 'Guardian Occupation',
      guardianEdu = lang == EccdLanguage.tagalog
          ? 'Pinakamataas na Natapos na Pag-aaral ng Tagapag-alaga'
          : 'Guardian Highest Educational Attainment',
      mother = lang == EccdLanguage.tagalog ? 'Pangalan ng Ina' : 'Mother Name',
      motherOcc = lang == EccdLanguage.tagalog
          ? 'Hanapbuhay ng Ina'
          : 'Mother Occupation',
      motherEdu = lang == EccdLanguage.tagalog
          ? 'Pinakamataas na Natapos na Pag-aaral ng Ina'
          : 'Mother Highest Educational Attainment',
      father = lang == EccdLanguage.tagalog ? 'Pangalan ng Ama' : 'Father Name',
      fatherOcc = lang == EccdLanguage.tagalog
          ? 'Hanapbuhay ng Ama'
          : 'Father Occupation',
      fatherEdu = lang == EccdLanguage.tagalog
          ? 'Pinakamataas na Natapos na Pag-aaral ng Ama'
          : 'Father Highest Educational Attainment',
      motherAgeAtBirth = lang == EccdLanguage.tagalog
          ? 'Edad ng Ina sa Panganganak'
          : "Mother's Age at Birth",
      firstCol = lang == EccdLanguage.tagalog ? 'Unang Pagtataya' : 'Pre test',
      secondCol = lang == EccdLanguage.tagalog
          ? 'Pangalawang Pagtataya'
          : 'Post test',
      thirdCol = lang == EccdLanguage.tagalog
          ? 'Panghuling Pagtataya'
          : 'Conditional Test',
      scoreRow = lang == EccdLanguage.tagalog ? 'Iskor' : 'Score',
      firstAssessment = lang == EccdLanguage.tagalog
          ? 'Unang Pagtataya'
          : 'First Assessment',
      secondAssessment = lang == EccdLanguage.tagalog
          ? 'Pangalawang Pagtataya'
          : 'Second Assessment',
      thirdAssessment = lang == EccdLanguage.tagalog
          ? 'Panghuling Pagtataya'
          : 'Final Assessment',
      domains = lang == EccdLanguage.tagalog ? 'DOMAINS' : 'DOMAINS';
}
