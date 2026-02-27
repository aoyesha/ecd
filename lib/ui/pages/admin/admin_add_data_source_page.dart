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
    );
    if (picked == null || picked.files.isEmpty) return;

    final f = picked.files.first;
    if (f.path == null) return;

    final level = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('CSV Source Level'),
        content: const Text('Select the source level of this imported CSV.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'teacher'),
            child: const Text('Teacher'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'principal'),
            child: const Text('Principal'),
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
    try {
      final text = await File(f.path!).readAsString();
      await _csv.ingestRollupCsv(
        adminId: adminId,
        orgLevel: level,
        csvText: text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
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
                    'Use exported summary CSV files from teachers or lower admin levels.',
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
