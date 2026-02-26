import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/csv_import_service.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';
import 'admin_landing_page.dart';

class AdminNewDataSourcePage extends StatefulWidget {
  final String role;
  final int userId;

  const AdminNewDataSourcePage({
    Key? key,
    required this.role,
    required this.userId,
  }) : super(key: key);

  @override
  State<AdminNewDataSourcePage> createState() =>
      _AdminNewDataSourcePageState();
}

class _AdminNewDataSourcePageState extends State<AdminNewDataSourcePage> {
  final _formKey = GlobalKey<FormState>();

  final institutionController = TextEditingController();
  final startYearController = TextEditingController();
  final endYearController = TextEditingController();

  File? selectedCsvFile;

  @override
  void dispose() {
    institutionController.dispose();
    startYearController.dispose();
    endYearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      drawer: isMobile
          ? Navbar(
        selectedIndex: 1,
        onItemSelected: (_) {},
        role: widget.role,
        userId: widget.userId,
      )
          : null,
      appBar: isMobile
          ? AppBar(
        title: const Text("Create Data Source"),
        backgroundColor: const Color(0xFFE64843),
      )
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: isMobile ? _mobileLayout() : _desktopLayout(),
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

  // DESKTOP
  Widget _desktopLayout() {
    return Row(
      children: [
        Navbar(
          selectedIndex: 1,
          onItemSelected: (_) {},
          role: widget.role,
          userId: widget.userId,
        ),
        Expanded(
          child: Column(
            children: [
              _desktopHeader(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: SizedBox(width: 520, child: _form()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopHeader() {
    return Container(
      color: const Color(0xFFF7F4F6),
      padding: const EdgeInsets.fromLTRB(80, 14, 16, 10),
      child: const Row(
        children: [
          Text(
            "Create Data Source",
            style: TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // MOBILE
  Widget _mobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: _form(),
    );
  }

  // FORM
  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "Create Data Source",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 32),

          _field("Institution *", institutionController),

          Row(
            children: [
              Expanded(child: _yearField("Start Year", startYearController)),
              const SizedBox(width: 12),
              Expanded(child: _yearField("End Year", endYearController)),
            ],
          ),

          const SizedBox(height: 20),
          _csvPicker(),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE64843),
              ),
              onPressed: _saveDataSource,
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _csvPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Import Learners (CSV optional)",
            style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickCsv,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedCsvFile?.path.split(Platform.pathSeparator).last ??
                        "Select .csv file",
                    style: TextStyle(
                      color:
                      selectedCsvFile == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
                const Icon(Icons.upload_file),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => selectedCsvFile = File(result.files.single.path!));
    }
  }

  Future<void> _saveDataSource() async {
    if (!_formKey.currentState!.validate()) return;

    final start = int.tryParse(startYearController.text.trim());
    final end = int.tryParse(endYearController.text.trim());

    if (start == null || end == null || start >= end) {
      _snack("Invalid school year range");
      return;
    }

    final db = await DatabaseService.instance.getDatabase();

    final classId = await db.insert('class_table', {
      'class_level': institutionController.text.trim(),
      'class_section': '',
      'start_school_year': start.toString(),
      'end_school_year': end.toString(),
      'teacher_id': null,
      'admin_id': widget.userId,
      'status': 'active',
    });

    if (selectedCsvFile != null) {
      try {
        await CsvImportService.importLearnersFromCsv(
          file: selectedCsvFile!,
          classId: classId,
        );
      } catch (e) {
        _snack("CSV import failed: $e");
        return;
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdminLandingPage(
          role: widget.role,
          userId: widget.userId,
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
        decoration: _decoration(label),
      ),
    );
  }

  Widget _yearField(String label, TextEditingController c) {
    return TextFormField(
      controller: c,
      keyboardType: TextInputType.number,
      validator: (v) =>
      v == null || !RegExp(r'^\d{4}$').hasMatch(v) ? "YYYY" : null,
      decoration: _decoration(label),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.black));
  }
}