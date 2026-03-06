import 'dart:typed_data';
import 'package:excel/excel.dart';

import '../data/eccd_questions.dart';
import '../db/app_db.dart';
import '../db/schema.dart';
import 'csv_service.dart';
import 'scoring_service.dart';

class XlsxService {
  final _csv = CsvService();
  final _levels = DevLevels.ordered;

  static const _domains = [
    'Gross Motor',
    'Fine Motor',
    'Self Help',
    'Receptive Language',
    'Expressive Language',
    'Cognitive',
    'Social Emotional',
  ];

  // Domain display names for column headers
  static const _domainDisplayNames = {
    'Gross Motor': 'GROSS MOTOR',
    'Fine Motor': 'FINE MOTOR',
    'Self Help': 'SELF-HELP',
    'Receptive Language': 'RECEPTIVE LANGUAGE',
    'Expressive Language': 'EXPRESSIVE LANGUAGE',
    'Cognitive': 'COGNITIVE',
    'Social Emotional': 'SOCIO EMOTIONAL',
  };

  // Domain start columns (M column, 0-indexed) in summary table
  static const _domainStartCols = {
    'Gross Motor': 2,
    'Fine Motor': 5,
    'Self Help': 8,
    'Receptive Language': 11,
    'Expressive Language': 14,
    'Cognitive': 17,
    'Social Emotional': 20,
  };

  // Background colors per domain (ARGB hex, no '#')
  static const _domainColors = {
    'Gross Motor': 'FFDEEAF6',
    'Fine Motor': 'FFFEF2CB',
    'Self Help': 'FFE7E6E6',
    'Receptive Language': 'FFFBE4D5',
    'Expressive Language': 'FFDEEAF6',
    'Cognitive': 'FFD6DCE4',
    'Social Emotional': 'FFD8D8D8',
  };

  static const _levelColor = 'FFE2EFD9';
  static const _gtColor = 'FFF4B083';
  static const _gtStartCol = 23;

  static const _levelFullNames = {
    'SSDD': 'Suggested Significant Delay in Overall Development (SSDD)',
    'SSLDD': 'Suggested Slight Delay in Overall Development (SSLDD)',
    'AD': 'Average Development (AD)',
    'SSAD': 'Suggest Slightly Advance Development (SSAD)',
    'SHAD': 'Suggest Highly Advanced Development (SHAD)',
  };

  // Skills section: 3 cols per domain (0-indexed start col)
  static const _skillDomainStartCols = {
    'Gross Motor': 0,
    'Fine Motor': 3,
    'Self Help': 6,
    'Receptive Language': 9,
    'Expressive Language': 12,
    'Cognitive': 15,
    'Social Emotional': 18,
  };

  static const _skillDisplayNames = {
    'Gross Motor': 'Gross Motor',
    'Fine Motor': 'Fine Motor',
    'Self Help': 'Self-Help',
    'Receptive Language': 'Receptive Language',
    'Expressive Language': 'Expressive Language',
    'Cognitive': 'Cognitive Domain',
    'Social Emotional': 'Social Emotional',
  };

  // ── TEACHER EXPORT ──────────────────────────────────────────────────────────

  Future<Uint8List> exportTeacherClassRollupXlsx({
    required int teacherId,
    required int classId,
    required String assessmentType,
    required EccdLanguage languageForSkills,
  }) async {
    final rd = await _csv.gatherTeacherRollupData(
      teacherId: teacherId,
      classId: classId,
      assessmentType: assessmentType,
      languageForSkills: languageForSkills,
    );
    return _buildXlsx(
      assessmentType: assessmentType,
      schoolYear: rd.schoolYear,
      region: rd.region,
      division: rd.division,
      counts: rd.counts,
      top3Skills: rd.top3Skills,
    );
  }

  // ── ADMIN EXPORT ─────────────────────────────────────────────────────────────

  Future<Uint8List> exportAdminAggregatedRollupXlsx({
    required int adminId,
    required String assessmentType,
    String? schoolYear,
  }) async {
    final db = AppDb.instance.db;
    final adminRow = (await db.query(
      DbSchema.tUsers,
      where: '${DbSchema.cUserId}=?',
      whereArgs: [adminId],
      limit: 1,
    )).first;

    final resolvedSy = await _resolveSchoolYear(
      adminId: adminId,
      selectedSchoolYear: schoolYear,
    );

    final agg = await _csv.aggregateAdminRollup(
      adminId: adminId,
      assessmentType: assessmentType,
      schoolYear: schoolYear,
    );

    final skills = await _csv.aggregateAdminSkills(
      adminId: adminId,
      assessmentType: assessmentType,
      schoolYear: schoolYear,
    );

    final top3 = _computeTop3FromAggregated(skills);

    return _buildXlsx(
      assessmentType: assessmentType,
      schoolYear: resolvedSy,
      region: (adminRow[DbSchema.cUserRegion] ?? '').toString(),
      division: (adminRow[DbSchema.cUserDivision] ?? '').toString(),
      counts: agg,
      top3Skills: top3,
    );
  }

  // ── XLSX BUILDER ─────────────────────────────────────────────────────────────

  Uint8List _buildXlsx({
    required String assessmentType,
    required String schoolYear,
    required String region,
    required String division,
    required Map<String, Map<String, Map<String, int>>> counts,
    required Map<String, Map<String, List<String>>> top3Skills,
  }) {
    final excel = Excel.createExcel();
    // Rename the default sheet
    excel.rename(excel.getDefaultSheet()!, 'ECCD Summary');
    final sheet = excel.sheets['ECCD Summary']!;

    final assessLabel = assessmentType == 'pre'
        ? 'BEGINNING OF THE SCHOOL YEAR (BOSY) EARLY CHILDHOOD DEVELOPMENT ASSESSMENT'
        : 'END OF THE SCHOOL YEAR (EOSY) EARLY CHILDHOOD DEVELOPMENT ASSESSMENT';

    final regionLabel = region.isNotEmpty ? region.toUpperCase() : 'REGION';
    final divisionLabel =
        division.isNotEmpty ? division.toUpperCase() : 'SCHOOLS DIVISION OFFICE';

    // ── Helpers ──────────────────────────────────────────────────────────────

    CellStyle makeStyle({
      String? bgColor,
      bool bold = false,
      bool wrap = false,
      HorizontalAlign halign = HorizontalAlign.Left,
      VerticalAlign valign = VerticalAlign.Top,
      int? fontSize,
    }) {
      return CellStyle(
        backgroundColorHex: bgColor != null
            ? ExcelColor.fromHexString(bgColor)
            : ExcelColor.none,
        bold: bold,
        textWrapping: wrap ? TextWrapping.WrapText : null,
        horizontalAlign: halign,
        verticalAlign: valign,
        fontSize: fontSize,
      );
    }

    void set(int col, int row, dynamic value, {CellStyle? style}) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      );
      if (value is String) {
        cell.value = TextCellValue(value);
      } else if (value is int) {
        cell.value = IntCellValue(value);
      } else if (value is double) {
        cell.value = DoubleCellValue(value);
      }
      if (style != null) cell.cellStyle = style;
    }

    void mergeSet(
      int sc,
      int sr,
      int ec,
      int er,
      dynamic value, {
      CellStyle? style,
    }) {
      set(sc, sr, value, style: style);
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: sc, rowIndex: sr),
        CellIndex.indexByColumnRow(columnIndex: ec, rowIndex: er),
      );
    }

    // ── Column widths ─────────────────────────────────────────────────────────
    sheet.setColumnWidth(0, 28.0); // A
    sheet.setColumnWidth(1, 12.0); // B
    for (int c = 2; c <= 25; c++) {
      sheet.setColumnWidth(c, 9.0);
    }

    // ── Header rows (0-indexed) ───────────────────────────────────────────────
    // Row 0: blank
    // Row 1: Department of Education
    mergeSet(
      0, 1, 25, 1,
      'Department of Education',
      style: makeStyle(bold: true, halign: HorizontalAlign.Center),
    );
    // Row 2: Region
    mergeSet(
      0, 2, 25, 2,
      regionLabel,
      style: makeStyle(bold: true, halign: HorizontalAlign.Center),
    );
    // Row 3: Division
    mergeSet(
      0, 3, 25, 3,
      divisionLabel,
      style: makeStyle(bold: true, halign: HorizontalAlign.Center),
    );
    // Rows 4-5: blank
    // Row 6: BOSY/EOSY label
    mergeSet(
      0, 6, 25, 6,
      assessLabel,
      style: makeStyle(bold: true, halign: HorizontalAlign.Center),
    );
    // Row 7: SY
    mergeSet(
      0, 7, 25, 7,
      'SY $schoolYear',
      style: makeStyle(bold: true, halign: HorizontalAlign.Center),
    );

    // ── "Summary" label (rows 8-9, cols 11-13) ──────────────────────────────
    mergeSet(
      11, 8, 13, 9,
      'Summary',
      style: makeStyle(bold: true, halign: HorizontalAlign.Center),
    );

    // ── Domain headers row 10 ─────────────────────────────────────────────────
    // Level header: A11:B12 (0-indexed: cols 0-1, rows 10-11)
    mergeSet(
      0, 10, 1, 11,
      'Level of Development',
      style: makeStyle(
        bgColor: _levelColor,
        bold: true,
        halign: HorizontalAlign.Center,
        valign: VerticalAlign.Center,
        wrap: true,
      ),
    );

    for (final domain in _domains) {
      final sc = _domainStartCols[domain]!;
      final color = _domainColors[domain]!;
      mergeSet(
        sc, 10, sc + 2, 10,
        _domainDisplayNames[domain]!,
        style: makeStyle(
          bgColor: color,
          bold: true,
          halign: HorizontalAlign.Center,
        ),
      );
    }
    // Grand Total header
    mergeSet(
      _gtStartCol, 10, 25, 10,
      'GRAND TOTAL',
      style: makeStyle(
        bgColor: _gtColor,
        bold: true,
        halign: HorizontalAlign.Center,
      ),
    );

    // ── M/F/TOTAL row 11 ─────────────────────────────────────────────────────
    for (final domain in _domains) {
      final sc = _domainStartCols[domain]!;
      final color = _domainColors[domain]!;
      final sty = makeStyle(
        bgColor: color,
        bold: true,
        halign: HorizontalAlign.Center,
      );
      set(sc, 11, 'M', style: sty);
      set(sc + 1, 11, 'F', style: sty);
      set(sc + 2, 11, 'TOTAL', style: sty);
    }
    final gtSub =
        makeStyle(bgColor: _gtColor, bold: true, halign: HorizontalAlign.Center);
    set(_gtStartCol, 11, 'M', style: gtSub);
    set(_gtStartCol + 1, 11, 'F', style: gtSub);
    set(_gtStartCol + 2, 11, 'TOTAL', style: gtSub);
    // Level label sub-header cell already covered by the merge above
    // but we need to fill the B row-11 cell style
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 11))
        .cellStyle = makeStyle(bgColor: _levelColor);

    // ── Level data rows 12-16 ─────────────────────────────────────────────────
    for (int i = 0; i < _levels.length; i++) {
      final level = _levels[i];
      final row = 12 + i;
      final evenBg = i.isEven ? 'FFF0F0F0' : null;

      mergeSet(
        0, row, 1, row,
        _levelFullNames[level] ?? level,
        style: makeStyle(
          bgColor: evenBg ?? _levelColor,
          halign: HorizontalAlign.Left,
          wrap: true,
        ),
      );

      for (final domain in _domains) {
        final sc = _domainStartCols[domain]!;
        final color = _domainColors[domain]!;
        final m = counts[domain]?['M']?[level] ?? 0;
        final f = counts[domain]?['F']?[level] ?? 0;
        final numSty = makeStyle(bgColor: color, halign: HorizontalAlign.Center);
        set(sc, row, m, style: numSty);
        set(sc + 1, row, f, style: numSty);
        set(sc + 2, row, m + f, style: numSty);
      }

      final gtM = counts['ALL']?['M']?[level] ?? 0;
      final gtF = counts['ALL']?['F']?[level] ?? 0;
      final gtSty = makeStyle(bgColor: _gtColor, halign: HorizontalAlign.Center);
      set(_gtStartCol, row, gtM, style: gtSty);
      set(_gtStartCol + 1, row, gtF, style: gtSty);
      set(_gtStartCol + 2, row, gtM + gtF, style: gtSty);
    }

    // ── TOTAL row 17 ──────────────────────────────────────────────────────────
    const totRow = 17;
    mergeSet(
      0, totRow, 1, totRow,
      'TOTAL',
      style: makeStyle(bold: true, halign: HorizontalAlign.Center),
    );
    for (final domain in _domains) {
      final sc = _domainStartCols[domain]!;
      final color = _domainColors[domain]!;
      final m = _levels.fold(0, (a, l) => a + (counts[domain]?['M']?[l] ?? 0));
      final f = _levels.fold(0, (a, l) => a + (counts[domain]?['F']?[l] ?? 0));
      final sty = makeStyle(bgColor: color, bold: true, halign: HorizontalAlign.Center);
      set(sc, totRow, m, style: sty);
      set(sc + 1, totRow, f, style: sty);
      set(sc + 2, totRow, m + f, style: sty);
    }
    final gtMT = _levels.fold(0, (a, l) => a + (counts['ALL']?['M']?[l] ?? 0));
    final gtFT = _levels.fold(0, (a, l) => a + (counts['ALL']?['F']?[l] ?? 0));
    final gtTotSty =
        makeStyle(bgColor: _gtColor, bold: true, halign: HorizontalAlign.Center);
    set(_gtStartCol, totRow, gtMT, style: gtTotSty);
    set(_gtStartCol + 1, totRow, gtFT, style: gtTotSty);
    set(_gtStartCol + 2, totRow, gtMT + gtFT, style: gtTotSty);

    // ── Most Learned section (5 blank rows after TOTAL at row 17) ────────────
    const mostHdrRow = 23;
    const mostSkill1Row = 24;
    const mostSkill2Row = 25;
    const mostSkill3Row = 26;

    for (final domain in _domains) {
      final sc = _skillDomainStartCols[domain]!;
      final headerText =
          'What are the Three Most Learned Skills in ${_skillDisplayNames[domain]}?';
      mergeSet(sc, mostHdrRow, sc + 2, mostHdrRow, headerText,
          style: makeStyle(bold: true, wrap: true));

      final most = top3Skills[domain]?['most'] ?? [];
      mergeSet(sc, mostSkill1Row, sc + 2, mostSkill1Row,
          most.isNotEmpty ? most[0] : '',
          style: makeStyle(wrap: true, valign: VerticalAlign.Center));
      mergeSet(sc, mostSkill2Row, sc + 2, mostSkill2Row,
          most.length > 1 ? most[1] : '',
          style: makeStyle(wrap: true, valign: VerticalAlign.Center));
      mergeSet(sc, mostSkill3Row, sc + 2, mostSkill3Row,
          most.length > 2 ? most[2] : '',
          style: makeStyle(wrap: true, valign: VerticalAlign.Center));
    }

    for (int r = mostSkill1Row; r <= mostSkill3Row; r++) {
      sheet.setRowHeight(r, 40.0);
    }

    // ── Least Mastered section (6 blank rows after Most Learned) ─────────────
    const leastHdrRow = 33;
    const leastSkill1Row = 34;
    const leastSkill2Row = 35;
    const leastSkill3Row = 36;

    for (final domain in _domains) {
      final sc = _skillDomainStartCols[domain]!;
      final headerText =
          'What are the Three Least Mastered Skills in ${_skillDisplayNames[domain]}?';
      mergeSet(sc, leastHdrRow, sc + 2, leastHdrRow, headerText,
          style: makeStyle(bold: true, wrap: true));

      final least = top3Skills[domain]?['least'] ?? [];
      mergeSet(sc, leastSkill1Row, sc + 2, leastSkill1Row,
          least.isNotEmpty ? least[0] : '',
          style: makeStyle(wrap: true, valign: VerticalAlign.Center));
      mergeSet(sc, leastSkill2Row, sc + 2, leastSkill2Row,
          least.length > 1 ? least[1] : '',
          style: makeStyle(wrap: true, valign: VerticalAlign.Center));
      mergeSet(sc, leastSkill3Row, sc + 2, leastSkill3Row,
          least.length > 2 ? least[2] : '',
          style: makeStyle(wrap: true, valign: VerticalAlign.Center));
    }

    for (int r = leastSkill1Row; r <= leastSkill3Row; r++) {
      sheet.setRowHeight(r, 40.0);
    }

    // ── Signature section (6 blank rows after Least Mastered) ────────────────
    const sigLabelRow = 43;
    const sigRoleRow = 46;
    final sigStyle = makeStyle(bold: true);
    mergeSet(1, sigLabelRow, 4, sigLabelRow, 'Prepared:', style: sigStyle);
    mergeSet(9, sigLabelRow, 12, sigLabelRow, 'Verified:', style: sigStyle);
    mergeSet(17, sigLabelRow, 20, sigLabelRow, 'NOTED:', style: sigStyle);
    mergeSet(1, sigRoleRow, 4, sigRoleRow, 'Kindergarten Teacher');
    mergeSet(9, sigRoleRow, 12, sigRoleRow,
        'Master Teacher/ Kindergarten Coordinator');
    mergeSet(17, sigRoleRow, 20, sigRoleRow, 'School Head');

    // ── Apply borders ─────────────────────────────────────────────────────────
    void applyBorders(int startCol, int startRow, int endCol, int endRow) {
      final thin = Border(borderStyle: BorderStyle.Thin);
      for (int r = startRow; r <= endRow; r++) {
        for (int c = startCol; c <= endCol; c++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          );
          final s = cell.cellStyle;
          cell.cellStyle = CellStyle(
            backgroundColorHex: s?.backgroundColor ?? ExcelColor.none,
            bold: s?.isBold ?? false,
            textWrapping: s?.wrap,
            horizontalAlign: s?.horizontalAlignment ?? HorizontalAlign.Left,
            verticalAlign: s?.verticalAlignment ?? VerticalAlign.Top,
            fontSize: s?.fontSize,
            leftBorder: thin,
            rightBorder: thin,
            topBorder: thin,
            bottomBorder: thin,
          );
        }
      }
    }

    // Summary table: domain headers + M/F/Total row + level rows + TOTAL row
    applyBorders(0, 10, 25, 17);
    // Most Learned section: header + 3 skill rows (7 domains × 3 cols = 21 cols)
    applyBorders(0, mostHdrRow, 20, mostSkill3Row);
    // Least Mastered section: header + 3 skill rows
    applyBorders(0, leastHdrRow, 20, leastSkill3Row);

    // ── Save ──────────────────────────────────────────────────────────────────
    final bytes = excel.save();
    return Uint8List.fromList(bytes!);
  }

  // ── PRIVATE HELPERS ──────────────────────────────────────────────────────────

  Map<String, Map<String, List<String>>> _computeTop3FromAggregated(
    Map<String, List<Map<String, Object?>>> aggregated,
  ) {
    final out = <String, Map<String, List<String>>>{};
    for (final domain in _domains) {
      final rows = aggregated[domain] ?? [];
      if (rows.isEmpty) {
        out[domain] = {'most': [], 'least': []};
        continue;
      }
      double pct(Map<String, Object?> r) {
        final t = (r['total_sum'] as int?) ?? 0;
        final c = (r['checked_sum'] as int?) ?? 0;
        return t == 0 ? 0.0 : c / t;
      }
      final sorted = [...rows]..sort((a, b) => pct(b).compareTo(pct(a)));
      final most = sorted.take(3).map((r) => r['skill_text'].toString()).toList();
      final leastSorted = [...rows]..sort((a, b) => pct(a).compareTo(pct(b)));
      final least =
          leastSorted.take(3).map((r) => r['skill_text'].toString()).toList();
      out[domain] = {'most': most, 'least': least};
    }
    return out;
  }

  Future<String> _resolveSchoolYear({
    required int adminId,
    String? selectedSchoolYear,
  }) async {
    final selected = (selectedSchoolYear ?? '').trim();
    if (selected.isNotEmpty) return selected;
    final active = await _csv.listAdminSources(adminId, archived: false);
    final years = <String>{};
    for (final row in active) {
      final sy = (row[DbSchema.cSrcSchoolYear] ?? '').toString().trim();
      if (sy.isNotEmpty) years.add(sy);
    }
    if (years.isEmpty) return 'ALL_ACTIVE';
    final ordered = years.toList()..sort();
    return ordered.join(', ');
  }
}
