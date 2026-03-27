import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_dialogs.dart';
import '../../../core/constants.dart';
import '../../../core/ui_feedback.dart';
import '../../../services/auth_service.dart';
import '../../../services/csv_service.dart';
import '../../widgets/subpage_shell.dart';

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
    if (!mounted) return;

    final level = await AppDialogs.showChoiceDialog<String>(
      context,
      title: 'CSV Source Level',
      message: validFiles.length == 1
          ? 'Select the source level of this imported CSV.'
          : 'Select the source level for all ${validFiles.length} imported files.',
      options: const [
        AppDialogOption(
          value: 'teacher',
          title: 'Teacher',
          subtitle: 'Import a class or section rollup exported by a teacher.',
          icon: Icons.class_rounded,
        ),
        AppDialogOption(
          value: 'school',
          title: 'School',
          subtitle: 'Import a consolidated school-level datasource.',
          icon: Icons.school_rounded,
        ),
        AppDialogOption(
          value: 'district',
          title: 'District',
          subtitle: 'Import a district rollup file.',
          icon: Icons.location_city_rounded,
        ),
        AppDialogOption(
          value: 'division',
          title: 'Division',
          subtitle: 'Import a division-level rollup.',
          icon: Icons.account_balance_rounded,
        ),
        AppDialogOption(
          value: 'regional',
          title: 'Regional',
          subtitle: 'Import a region-wide aggregated datasource.',
          icon: Icons.map_rounded,
        ),
      ],
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
        AppFeedback.showSnackBar(
          context,
          msg,
          tone: errors.isEmpty
              ? AppFeedbackTone.success
              : AppFeedbackTone.warning,
        );
        if (imported > 0) Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubpageShell(
      title: 'Add Data Source',
      directorySegments: const ['Dashboard', 'My Data Sources', 'Add Data Source'],
      navIndex: 0,
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
