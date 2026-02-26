import 'package:flutter/material.dart';
import '../data/eccd_questions.dart';
import '../services/assessment_service.dart';
import '../services/pdf_service.dart';
import '../util/domain.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';

class TeacherChecklistViewPage extends StatefulWidget {
  final String role;
  final int userId;
  final int classId;
  final int learnerId;
  final String learnerName;

  const TeacherChecklistViewPage({
    Key? key,
    required this.role,
    required this.userId,
    required this.classId,
    required this.learnerId,
    required this.learnerName,
  }) : super(key: key);

  @override
  State<TeacherChecklistViewPage> createState() =>
      _TeacherChecklistViewPageState();
}

class _TeacherChecklistViewPageState
    extends State<TeacherChecklistViewPage> {

  String selectedLanguage = "English";
  String selectedAssessment = "Pre-Test";

  String? selectedDomain;
  DateTime? selectedDate;
  final TextEditingController _dateController = TextEditingController();

  final List<String> domains = EccdQuestions.domains;
  final Map<String, bool> yesValues = {};

  @override
  void initState() {
    super.initState();
    _loadSavedAssessment();
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAssessment() async {
    selectedDate = null;

    final results = await AssessmentService.getAssessment(
      learnerId: widget.learnerId,
      classId: widget.classId,
      assessmentType: selectedAssessment,
    );

    yesValues.clear();

    for (final row in results) {
      final dbIndex = int.tryParse(row['question_index'].toString()) ?? 1;
      final key = "${row['domain']}-${dbIndex - 1}";
      yesValues[key] = row['answer'].toString() == '1';

      final dateStr = row['date_taken']?.toString();
      if (selectedDate == null && dateStr != null && dateStr.isNotEmpty) {
        selectedDate = DateTime.tryParse(dateStr);
      }
    }

    if (selectedDate != null) {
      _dateController.text =
      "${selectedDate!.month}/${selectedDate!.day}/${selectedDate!.year}";
    }

    if (mounted) setState(() {});
  }

  Color _progressColor(double value) {
    if (value == 0) return Colors.red;
    if (value == 1) return Colors.green;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      drawer: isMobile
          ? Navbar(
        selectedIndex: 0,
        onItemSelected: (_) {},
        role: widget.role,
        userId: widget.userId,
      )
          : null,
      appBar: isMobile
          ? AppBar(
        title: const Text("Checklist View"),
        backgroundColor: const Color(0xFFA02A2A),
        foregroundColor: Colors.white,
      )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
                if (!isMobile)
                  Navbar(
                    selectedIndex: 0,
                    onItemSelected: (_) {},
                    role: widget.role,
                    userId: widget.userId,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (!isMobile) _desktopHeader(),
                      Expanded(
                        child: Stack(
                          children: [
                            SingleChildScrollView(child: _content(isMobile)),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: _stickyBottomBar(isMobile),
                            ),
                          ],
                        ),
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

  Widget _desktopHeader() {
    return Container(
      color: const Color(0xFFF7F4F6),
      padding: const EdgeInsets.fromLTRB(80, 14, 16, 10),
      child: const Row(
        children: [
          Text(
            "Checklist View",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(bool isMobile) {
    final lang = EccdQuestions.fromLabel(selectedLanguage);
    final visibleDomains = selectedDomain == null ? domains : [selectedDomain!];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 34,
        isMobile ? 12 : 34,
        isMobile ? 12 : 34,
        140,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topRow(isMobile),
          const SizedBox(height: 10),

          Text(widget.learnerName,
              style: TextStyle(
                  fontSize: isMobile ? 22 : 42,
                  fontWeight: FontWeight.bold)),

          const SizedBox(height: 8),

          LinearProgressIndicator(
            value: _overallProgress(),
            color: _progressColor(_overallProgress()),
            minHeight: isMobile ? 4 : 5,
          ),

          const SizedBox(height: 14),

          DomainDropdown(
            domains: ["All Domains", ...domains],
            onChanged: (v) =>
                setState(() => selectedDomain = v == "All Domains" ? null : v),
          ),

          const SizedBox(height: 18),

          ...visibleDomains.map((domain) {
            final questions = EccdQuestions.get(domain, lang);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(domain,
                    style: TextStyle(
                        fontSize: isMobile ? 18 : 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),

                LinearProgressIndicator(
                  value: _domainProgress(domain, questions.length),
                  color: _progressColor(
                      _domainProgress(domain, questions.length)),
                  minHeight: isMobile ? 4 : 5,
                ),
                const SizedBox(height: 14),

                ...List.generate(questions.length, (i) {
                  final key = "$domain-$i";
                  final checked = yesValues[key] ?? false;

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isMobile ? 16 : 24,
                          height: isMobile ? 16 : 24,
                          margin: const EdgeInsets.only(right: 12, top: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black, width: 1.5),
                            color: checked ? Colors.black : Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text("${i + 1}. ${questions[i]}",
                              style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  height: 1.5)),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 22),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _topRow(bool isMobile) {

    if (isMobile) {
      return Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedAssessment,
            items: const [
              DropdownMenuItem(value: "Pre-Test", child: Text("Pre-Test")),
              DropdownMenuItem(value: "Post-Test", child: Text("Post-Test")),
              DropdownMenuItem(value: "Conditional Test", child: Text("Conditional Test")),
            ],
            onChanged: (v) async {
              setState(() => selectedAssessment = v!);
              await _loadSavedAssessment();
            },
            decoration: const InputDecoration(labelText: "Assessment"),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedLanguage,
            items: const [
              DropdownMenuItem(value: "English", child: Text("English")),
              DropdownMenuItem(value: "Tagalog", child: Text("Tagalog")),
            ],
            onChanged: (v) => setState(() => selectedLanguage = v!),
            decoration: const InputDecoration(labelText: "Language"),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _dateController,
            readOnly: true,
            decoration: const InputDecoration(labelText: "Date"),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 320,
          child: DropdownButtonFormField<String>(
            value: selectedAssessment,
            items: const [
              DropdownMenuItem(value: "Pre-Test", child: Text("Pre-Test")),
              DropdownMenuItem(value: "Post-Test", child: Text("Post-Test")),
              DropdownMenuItem(value: "Conditional Test", child: Text("Conditional Test")),
            ],
            onChanged: (v) async {
              setState(() => selectedAssessment = v!);
              await _loadSavedAssessment();
            },
            decoration: const InputDecoration(labelText: "Assessment"),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            value: selectedLanguage,
            items: const [
              DropdownMenuItem(value: "English", child: Text("English")),
              DropdownMenuItem(value: "Tagalog", child: Text("Tagalog")),
            ],
            onChanged: (v) => setState(() => selectedLanguage = v!),
            decoration: const InputDecoration(labelText: "Language"),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _dateController,
            readOnly: true,
            decoration: const InputDecoration(labelText: "Date"),
          ),
        ),
      ],
    );
  }

  Widget _stickyBottomBar(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: isMobile ? 36 : 42,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA02A2A),
              ),
              onPressed: _exportSummary,
              child: const Text("Export Summary",
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSummary() async {
    final file = await PdfService.generateReport(
      widget.learnerName,
      _computeProgress(),
    );
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text("PDF saved: ${file.path}")));
  }

  Map<String, double> _computeProgress() {
    final Map<String, List<bool>> map = {};
    yesValues.forEach((k, v) {
      final d = k.split('-').first;
      map.putIfAbsent(d, () => []);
      map[d]!.add(v);
    });

    return map.map((k, v) =>
        MapEntry(k, v.isEmpty ? 0 : v.where((e) => e).length / v.length));
  }

  double _domainProgress(String domain, int questionCount) {
    int yes = 0;
    for (int i = 0; i < questionCount; i++) {
      if (yesValues["$domain-$i"] == true) yes++;
    }
    return questionCount == 0 ? 0 : yes / questionCount;
  }

  double _overallProgress() {
    if (yesValues.isEmpty) return 0;
    return yesValues.values.where((v) => v).length / yesValues.length;
  }
}