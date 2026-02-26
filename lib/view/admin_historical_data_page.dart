import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';

class AdminHistoricalPage extends StatefulWidget {
  final String role;
  final int userId;

  const AdminHistoricalPage({
    Key? key,
    required this.role,
    required this.userId,
  }) : super(key: key);

  @override
  State<AdminHistoricalPage> createState() => _AdminHistoricalPageState();
}

class _AdminHistoricalPageState extends State<AdminHistoricalPage> {
  bool _loading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  File? importedFile;

  final List<String> _domainsTable = const [
    "GROSS MOTOR",
    "FINE MOTOR",
    "SELF HELP",
    "RECEPTIVE\nLANGUAGE",
    "EXPRESSIVE\nLANGUAGE",
    "COGNITIVE",
    "SOCIO-EMOTIONAL",
  ];

  final List<String> _levelsTable = const [
    "SSDD",
    "SSLDD",
    "AD",
    "SSAD",
    "SHAD",
    "TOTAL",
  ];

  final Map<String, String> _levelDescriptions = const {
    "SSDD": "Suggested Significant Delay in Overall Development",
    "SSLDD": "Suggested Slight Delay in Overall Development",
    "AD": "Average Development",
    "SSAD": "Suggested Slightly Advanced Development",
    "SHAD": "Suggested Highly Advanced Development",
    "TOTAL": "TOTAL",
  };

  final Map<String, String> _domainToColumn = {
    "GROSS MOTOR": "gmd_interpretation",
    "FINE MOTOR": "fms_interpretation",
    "SELF HELP": "shd_interpretation",
    "RECEPTIVE\nLANGUAGE": "rl_interpretation",
    "EXPRESSIVE\nLANGUAGE": "el_interpretation",
    "COGNITIVE": "cd_interpretation",
    "SOCIO-EMOTIONAL": "sed_interpretation",
  };

  Map<String, Map<String, Map<String, int>>> _tableData = {};

  @override
  void initState() {
    super.initState();
    _loadTableSummary();
  }

  Future<void> _loadTableSummary() async {
    final db = await DatabaseService.instance.getDatabase();

    final rows = await db.rawQuery('''
      SELECT e.*, l.sex
      FROM learner_ecd_table e
      INNER JOIN assessment_header a ON e.assessment_id = a.assessment_id
      INNER JOIN learner_information_table l ON a.learner_id = l.learner_id
      INNER JOIN class_table c ON l.class_id = c.class_id
    ''');

    Map<String, Map<String, Map<String, int>>> data = {};

    for (var lvl in _levelsTable) {
      data[lvl] = {};
      for (var domain in [..._domainsTable, "GRAND_TOTAL"]) {
        data[lvl]![domain] = {'M': 0, 'F': 0};
      }
    }

    for (var row in rows) {
      String gender =
      row['sex'].toString().toUpperCase().startsWith('F') ? 'F' : 'M';

      for (var domain in _domainsTable) {
        final col = _domainToColumn[domain]!;
        final interp = row[col]?.toString();
        if (!_levelsTable.contains(interp)) continue;

        data[interp]![domain]![gender] =
            (data[interp]![domain]![gender] ?? 0) + 1;
      }

      final overall = row['interpretation'];
      if (_levelsTable.contains(overall)) {
        data[overall]!['GRAND_TOTAL']![gender] =
            (data[overall]!['GRAND_TOTAL']![gender] ?? 0) + 1;
      }
    }

    setState(() {
      _tableData = data;
      _loading = false;
    });
  }

  Future<void> _exportSummary() async {
    final file =
    await PdfService.generateReport("Admin Historical Data", {});
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("PDF saved: ${file.path}")));
  }

  Future<void> _importFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() => importedFile = File(result.files.single.path!));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("File imported")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF7F4F6),
      drawer: isMobile
          ? Navbar(
        selectedIndex: 2,
        onItemSelected: (_) {},
        role: widget.role,
        userId: widget.userId,
      )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
                if (!isMobile)
                  Navbar(
                    selectedIndex: 2,
                    onItemSelected: (_) {},
                    role: widget.role,
                    userId: widget.userId,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(isMobile),
                      Expanded(
                        child: _loading
                            ? const Center(child: CircularProgressIndicator())
                            : _content(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 285,
              child: const NavbarBackButton(),
            ),
        ],
      ),
    );
  }

  /// SAME UI BELOW — ONLY BUTTON ROW CHANGED
  Widget _topBar(bool isMobile) {
    if (!isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: const Column(
          children: [
            Text("Historical Data",
                style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
            SizedBox(height: 14),
          ],
        ),
      );
    }

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            left: 64,
            right: 64,
            child: Center(
              child: Text("Historical Data",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ),
          Positioned(
            left: 12,
            top: 6,
            bottom: 6,
            child: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState!.openDrawer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _tableSummaryCard(),
          const SizedBox(height: 24),

          /// 🔴 ADMIN BUTTON ROW
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700),
                onPressed: _importFile,
                child: const Text("Import Data",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA02A2A)),
                onPressed: _exportSummary,
                child: const Text("Export Summary",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- TABLE (UNCHANGED) ----------
  Widget _tableSummaryCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(
              children: [
                _tableTopHeader(),
                _tableGenderHeader(),
                const Divider(height: 0),
                ..._levelsTable.map(_tableRow),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tableTopHeader() {
    return Row(children: [
      _headerCell("LEVEL", width: 260),
      for (var d in _domainsTable) _headerCell(d, width: 160),
      _headerCell("GRAND TOTAL", width: 160),
    ]);
  }

  Widget _tableGenderHeader() {
    return Row(children: [
      _subHeaderCell("", width: 260),
      for (var _ in _domainsTable) ...[
        _subHeaderCell("M", width: 80),
        _subHeaderCell("F", width: 80),
      ],
      _subHeaderCell("M", width: 80),
      _subHeaderCell("F", width: 80),
    ]);
  }

  Widget _tableRow(String level) {
    final desc = _levelDescriptions[level] ?? level;
    return Row(children: [
      _cell(desc, width: 260),
      for (var d in _domainsTable) ...[
        _cell("${_tableData[level]?[d]?['M'] ?? 0}", width: 80),
        _cell("${_tableData[level]?[d]?['F'] ?? 0}", width: 80),
      ],
      _cell("${_tableData[level]?['GRAND_TOTAL']?['M'] ?? 0}", width: 80),
      _cell("${_tableData[level]?['GRAND_TOTAL']?['F'] ?? 0}", width: 80),
    ]);
  }

  Widget _headerCell(String text, {double width = 100}) => Container(
    width: width,
    height: 60,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      border: Border.all(color: Colors.grey.shade400),
    ),
    child: Text(text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  Widget _subHeaderCell(String text, {double width = 60}) => Container(
    width: width,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  Widget _cell(String text, {double width = 60}) => Container(
    width: width,
    height: 46,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      color: Colors.white,
    ),
    child: Text(text, style: const TextStyle(fontSize: 15)),
  );
}