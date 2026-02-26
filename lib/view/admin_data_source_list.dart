import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/csv_import_service.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';

class AdminDataSourceFilesPage extends StatefulWidget {
  final String role;
  final int userId;
  final int classId;
  final String institution;
  final String startYear;
  final String endYear;

  const AdminDataSourceFilesPage({
    Key? key,
    required this.role,
    required this.userId,
    required this.classId,
    required this.institution,
    required this.startYear,
    required this.endYear,
  }) : super(key: key);

  @override
  State<AdminDataSourceFilesPage> createState() =>
      _AdminDataSourceFilesPageState();
}

class _AdminDataSourceFilesPageState extends State<AdminDataSourceFilesPage> {
  Future<void> _pickAndImportCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);

    try {
      // Parse CSV and insert rows into DB (existing service)
      await CsvImportService.importLearnersFromCsv(
        file: file,
        classId: widget.classId,
      );

      // Save file record in data_source_files table
      await DatabaseService.instance.insertDataSourceFile({
        'class_id': widget.classId,
        'file_name': file.path.split(Platform.pathSeparator).last,
        'date_imported': DateTime.now().toIso8601String(),
        'status': DatabaseService.statusActive,
      });

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      _snack("File import failed: $e");
    }
  }

  void _archiveFile(int fileId) async {
    await DatabaseService.instance.setFileStatus(
      fileId,
      DatabaseService.statusArchived,
    );
    setState(() {});
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F4F6),

      // IMPORT FILE BUTTON
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE64843),
        onPressed: _pickAndImportCsv,
        icon: const Icon(Icons.upload_file),
        label: const Text("Import File"),
      ),

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
                      _header(),
                      Expanded(child: _fileList()),
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

  // HEADER
  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(80, 16, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.institution,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            "School Year ${widget.startYear}-${widget.endYear} • Files",
            style: const TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }

  // FILE LIST
  Widget _fileList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.instance.getFilesByClass(widget.classId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final files = snapshot.data!;
        if (files.isEmpty) {
          return const Center(child: Text("No files uploaded yet"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: files.length,
          itemBuilder: (_, i) {
            final f = files[i];

            return Card(
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(f['file_name']),
                subtitle: Text("Imported ${f['date_imported']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: () => _archiveFile(f['file_id']),
                ),
              ),
            );
          },
        );
      },
    );
  }
}