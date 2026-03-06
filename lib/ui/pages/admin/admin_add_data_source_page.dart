import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../services/auth_service.dart';
import '../../../services/csv_service.dart';

class AdminAddDataSourcePage extends StatefulWidget {
  const AdminAddDataSourcePage({super.key});

  @override
  State<AdminAddDataSourcePage> createState() => _AdminAddDataSourcePageState();
}

class _AdminAddDataSourcePageState extends State<AdminAddDataSourcePage> {
  final _csv = CsvService();
  bool _loading = false;

  Future<void> _pickAndImport() async {
    final adminId = context.read<AuthService>().session!.userId;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final validFiles = picked.files.where((f) => f.path != null).toList();
    if (validFiles.isEmpty) return;

    final level = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CSV Source Level'),
        content: Text(
          validFiles.length == 1
              ? 'Select the source level of this imported CSV.'
              : 'Select the source level for all ${validFiles.length} imported files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'teacher'),
            child: const Text('Teacher'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'school'),
            child: const Text('School'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'district'),
            child: const Text('District'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'division'),
            child: const Text('Division'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'regional'),
            child: const Text('Regional'),
          ),
        ],
      ),
    );

    if (level == null) return;

    setState(() => _loading = true);
    int imported = 0;
    final errors = <String>[];
    try {
      for (final f in validFiles) {
        try {
          final text = await File(f.path!).readAsString();
          await _csv.ingestRollupCsv(
            adminId: adminId,
            orgLevel: level,
            csvText: text,
          );
          imported++;
        } catch (e) {
          errors.add('${f.name}: $e');
        }
      }
      if (!mounted) return;
      if (errors.isEmpty) {
        Navigator.pop(context, true);
      } else {
        final msg = imported > 0
            ? '$imported file(s) imported. ${errors.length} failed:\n${errors.join('\n')}'
            : 'All imports failed:\n${errors.join('\n')}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 6)),
        );
        if (imported > 0) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Data Source'),
        backgroundColor: AppColors.maroon,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Card(
            margin: const EdgeInsets.all(16),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE6E6E6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Import Rollup CSV',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select one or more exported summary CSV files from teachers or lower admin levels. '
                    'All files will be merged into the consolidated summary.',
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _loading ? null : _pickAndImport,
                    icon: const Icon(Icons.upload_file),
                    label: Text(_loading ? 'Importing...' : 'Choose CSV'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
