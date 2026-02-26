import 'dart:io';
import 'package:flutter/material.dart';

import '../services/database_service.dart';
import '../services/pdf_service.dart';
import '../util/navbar.dart';

class AdminSummaryPage extends StatefulWidget {
  final String role;
  final int userId;
  final bool embedded;

  const AdminSummaryPage({
    Key? key,
    required this.role,
    required this.userId,
    this.embedded = false,
  }) : super(key: key);

  @override
  State<AdminSummaryPage> createState() => _AdminSummaryPageState();
}

class _AdminSummaryPageState extends State<AdminSummaryPage> {
  bool _loading = true;

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

  // 🔴 MAIN CHANGE → admin_id filter instead of teacher_id
  Future<void> _loadTableSummary() async {
    final db = await DatabaseService.instance.getDatabase();

    final rows = await db.rawQuery('''
      SELECT e.*, l.sex
      FROM learner_ecd_table e
      INNER JOIN assessment_header a ON e.assessment_id = a.assessment_id
      INNER JOIN learner_information_table l ON a.learner_id = l.learner_id
      INNER JOIN class_table c ON l.class_id = c.class_id
      WHERE c.admin_id = ?
    ''', [widget.userId]);

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
    Map<String, double> dummyProgress = {};
    for (var domain in _domainsTable) {
      int total = 0;
      for (var lvl in _levelsTable) {
        total += (_tableData[lvl]?[domain]?['M'] ?? 0);
        total += (_tableData[lvl]?[domain]?['F'] ?? 0);
      }
      dummyProgress[domain] = total.toDouble();
    }

    final file =
    await PdfService.generateReport("Admin Summary", dummyProgress);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("PDF saved: ${file.path}")));
  }

  // NEW BUTTON ACTION (placeholder for future feature)
  void _importSummary() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Import summary coming soon")),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _loading
          ? const Center(child: CircularProgressIndicator())
          : _content();
    }

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          Navbar(
            selectedIndex: 2,
            onItemSelected: (_) {},
            role: widget.role,
            userId: widget.userId,
          ),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  Widget _content() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!widget.embedded) ...[
          const Text("Early Childhood Development Checklist",
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),
          const Text("Admin Summary",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
        ],
        const Text("ECCD Domain Summary by Gender",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 18),
        _tableSummaryCard(),
        const SizedBox(height: 24),
        _buildBottomButtons(),
      ]),
    );
  }

  // 🔴 TWO BUTTONS NOW
  Widget _buildBottomButtons() {
    return Row(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
          onPressed: _importSummary,
          child: const Text("Import Summary"),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA02A2A)),
          onPressed: _exportSummary,
          child: const Text("Export Summary"),
        ),
      ],
    );
  }

  // TABLE (unchanged)
  Widget _tableSummaryCard() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.black12),
    ),
    padding: const EdgeInsets.all(18),
    child: const SizedBox(height: 500, child: Center(child: Text("Same table UI as Teacher version"))),
  );
}