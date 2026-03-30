import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/ui_feedback.dart';
import '../../../core/unsaved_guard.dart';
import '../../../core/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_service.dart';
import '../../../services/learner_service.dart';
import '../../widgets/subpage_shell.dart';
import '../../widgets/section_title.dart';

class TeacherAddClassPage extends StatefulWidget {
  const TeacherAddClassPage({super.key});

  @override
  State<TeacherAddClassPage> createState() => _TeacherAddClassPageState();
}

class _TeacherAddClassPageState extends State<TeacherAddClassPage> {
  final formKey = GlobalKey<FormState>();
  final gradeCtrl = TextEditingController();
  final sectionCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    gradeCtrl.text = 'Kindergarten';
  }

  String? schoolYear;
  bool dirty = false;

  PlatformFile? csvFile;

  final _classService = ClassService();
  final _learnerService = LearnerService();

  @override
  void dispose() {
    gradeCtrl.dispose();
    sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        csvFile = res.files.first;
        dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    if (schoolYear == null) {
      AppFeedback.showSnackBar(
        context,
        'School Year is required',
        tone: AppFeedbackTone.warning,
      );
      return;
    }

    final teacherId = context.read<AuthService>().session!.userId;

    final classId = await _classService.createClass(
      teacherId: teacherId,
      grade: gradeCtrl.text,
      section: sectionCtrl.text,
      schoolYear: schoolYear!,
    );

    if (csvFile != null && csvFile!.path != null) {
      try {
        final text = await File(csvFile!.path!).readAsString();
        final importResult = await _importLearnersFromCsv(classId, text);
        if (!importResult) return;
      } catch (e) {
        if (!mounted) return;
        AppFeedback.showSnackBar(
          context,
          'Failed to read CSV file',
          tone: AppFeedbackTone.error,
          duration: const Duration(seconds: 5),
        );
        return;
      }
    }

    if (!mounted) return;
    AppFeedback.showSnackBar(
      context,
      'Class created successfully',
      tone: AppFeedbackTone.success,
    );
    setState(() => dirty = false);
    Navigator.pop(context);
  }

  Future<bool> _importLearnersFromCsv(int classId, String csvText) async {
    if (csvText.trim().isEmpty) {
      if (!mounted) return false;
      AppFeedback.showSnackBar(
        context,
        'CSV file is empty',
        tone: AppFeedbackTone.error,
      );
      return false;
    }

    List<List<dynamic>> rows;
    try {
      rows = const CsvToListConverter(
        shouldParseNumbers: false,
      ).convert(csvText);
    } catch (e) {
      if (!mounted) return false;
      AppFeedback.showSnackBar(
        context,
        'Invalid CSV format. Please use a valid CSV file',
        tone: AppFeedbackTone.error,
      );
      return false;
    }

    if (rows.isEmpty) {
      if (!mounted) return false;
      AppFeedback.showSnackBar(
        context,
        'CSV file has no data rows',
        tone: AppFeedbackTone.error,
      );
      return false;
    }

    // Validate that header row has at least some content
    if (rows.first.isEmpty) {
      if (!mounted) return false;
      AppFeedback.showSnackBar(
        context,
        'CSV header row is empty',
        tone: AppFeedbackTone.error,
      );
      return false;
    }

    final header = rows.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList(growable: false);
    final col = <String, int>{
      for (int i = 0; i < header.length; i++) header[i]: i,
    };

    // Check if file has any recognizable columns
    final requiredColumnPatterns = [
      'name',
      'gender',
      'sex',
      'birthdate',
      'birthday',
      'birth',
      'dob',
      'given',
      'surname',
      'first',
      'last',
    ];
    final hasRecognizedColumns = header.any(
      (h) => requiredColumnPatterns.any(
        (pattern) => h.contains(pattern.toLowerCase()),
      ),
    );
    if (!hasRecognizedColumns) {
      if (!mounted) return false;
      AppFeedback.showSnackBar(
        context,
        'Expected columns like: Name, Gender, Birthdate, etc.',
        tone: AppFeedbackTone.error,
      );
      return false;
    }

    String cell(List<dynamic> row, List<String> keys) {
      for (final k in keys) {
        final idx = col[k];
        if (idx == null || idx >= row.length) continue;
        final v = row[idx].toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final errors = <String>[];
    int importedCount = 0;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final fullName = cell(row, const [
        'full_name',
        'full name',
        'fullname',
        'name',
      ]);
      final given = cell(row, const ['given_name', 'given name', 'first_name']);
      final middle = cell(row, const ['middle_name', 'middle name']);
      final surname = cell(row, const ['surname', 'last_name', 'last name']);
      final lrn = cell(row, const ['lrn']);

      final genderRaw = cell(row, const ['gender', 'sex']);
      final birthRaw = cell(row, const [
        'birthdate',
        'birthday',
        'date_of_birth',
        'dob',
      ]);
      final birthOrder = cell(row, const ['birth_order', 'birth order']);
      final numberOfSiblings = cell(row, const [
        'number_of_siblings',
        'number of siblings',
        'siblings',
      ]);
      final province = cell(row, const ['province']);
      final city = cell(row, const ['city', 'municipality', 'town']);
      final barangay = cell(row, const ['barangay', 'brgy']);
      final parentName = cell(row, const [
        'parent_name',
        'parent name',
        'parent/guardian_name',
        'parent/guardian name',
        'guardian_name',
        'guardian name',
      ]);
      final parentOccupation = cell(row, const [
        'parent_occupation',
        'parent occupation',
        'parent/guardian_occupation',
        'parent/guardian occupation',
        'guardian_occupation',
        'guardian occupation',
      ]);
      final parentEducation = cell(row, const [
        'parent_education',
        'parent education',
        'parent_highest_educational_attainment',
        'guardian_education',
        'guardian education',
      ]);
      final motherName = cell(row, const ['mother_name', 'mother name']);
      final motherOccupation = cell(row, const [
        'mother_occupation',
        'mother occupation',
      ]);
      final motherEducation = cell(row, const [
        'mother_education',
        'mother education',
        'mother_highest_educational_attainment',
      ]);
      final fatherName = cell(row, const ['father_name', 'father name']);
      final fatherOccupation = cell(row, const [
        'father_occupation',
        'father occupation',
      ]);
      final fatherEducation = cell(row, const [
        'father_education',
        'father education',
        'father_highest_educational_attainment',
      ]);
      final ageMotherAtBirth = cell(row, const [
        'age_mother_at_birth',
        'age mother at birth',
      ]);
      final spouseOccupation = cell(row, const [
        'spouse_occupation',
        'spouse occupation',
      ]);

      final nameText = fullName.isNotEmpty
          ? fullName
          : [
              surname,
              given,
              middle,
            ].where((e) => e.isNotEmpty).join(' ').trim();
      if (nameText.isEmpty || genderRaw.isEmpty || birthRaw.isEmpty) {
        errors.add(
          'Row ${i + 1}: Missing required fields (name, gender, birthdate)',
        );
        continue;
      }

      final parsedGender = _normalizeGender(genderRaw);
      final birthDate = _parseDateFlexible(birthRaw);
      if (parsedGender == null || birthDate == null) {
        errors.add('Row ${i + 1}: Invalid gender or birthdate format');
        continue;
      }

      final age = _deriveAge(birthDate);
      if (age < 3) {
        errors.add('Row ${i + 1}: Age must be at least 3 years');
        continue;
      }

      // Check for duplicate LRN
      if (lrn.isNotEmpty) {
        final exists = await _learnerService.lrnExists(lrn);
        if (exists) {
          errors.add(
            'Row ${i + 1}: The LRN "$lrn" is already registered in the system.',
          );
          continue;
        }
      }

      final parsed = _splitName(nameText);
      try {
        await _learnerService.addLearner(
          classId: classId,
          firstName: parsed.$1,
          lastName: parsed.$2,
          gender: parsedGender,
          age: age,
          middleName: middle,
          lrn: lrn,
          birthDate:
              '${birthDate.year.toString().padLeft(4, '0')}-'
              '${birthDate.month.toString().padLeft(2, '0')}-'
              '${birthDate.day.toString().padLeft(2, '0')}',
          birthOrder: birthOrder,
          numberOfSiblings: numberOfSiblings,
          province: province,
          city: city,
          barangay: barangay,
          parentName: parentName,
          parentOccupation: parentOccupation,
          parentEducation: parentEducation,
          motherName: motherName,
          motherOccupation: motherOccupation,
          motherEducation: motherEducation,
          fatherName: fatherName,
          fatherOccupation: fatherOccupation,
          fatherEducation: fatherEducation,
          ageMotherAtBirth: ageMotherAtBirth,
          spouseOccupation: spouseOccupation,
        );
        importedCount++;
      } catch (e) {
        errors.add('Row ${i + 1}: Failed to import - $e');
      }
    }

    if (!mounted) return true;

    if (importedCount == 0 && errors.isNotEmpty) {
      AppFeedback.showSnackBar(
        context,
        'No learners imported. Check the errors and try again.',
        tone: AppFeedbackTone.error,
        duration: const Duration(seconds: 6),
      );
      return false;
    }

    if (errors.isNotEmpty) {
      final errorSummary = errors.isEmpty
          ? 'Import completed but with errors.'
          : 'Import completed with ${errors.length} error(s).';
      AppFeedback.showSnackBar(
        context,
        '$errorSummary Imported $importedCount learner(s).',
        tone: AppFeedbackTone.warning,
        duration: const Duration(seconds: 10),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedGuard(
      hasUnsavedChanges: dirty,
      child: SubpageShell(
        title: 'Add Class',
        directorySegments: const ['Dashboard', 'My Classes', 'Add Class'],
        navIndex: 0,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                  maxWidth: 820,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle(title: 'Class Details'),
                    const SizedBox(height: 12),
                    Form(
                      key: formKey,
                      onChanged: () => setState(() => dirty = true),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextFormField(
                              controller: gradeCtrl,
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'Grade',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  Validators.required(v, label: 'Grade'),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextFormField(
                              controller: sectionCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Section',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  Validators.required(v, label: 'Section'),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: DropdownButtonFormField<String>(
                              initialValue: schoolYear,
                              items: _schoolYearOptions()
                                  .map(
                                    (sy) => DropdownMenuItem(
                                      value: sy,
                                      child: Text(sy),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() {
                                schoolYear = v;
                                dirty = true;
                              }),
                              decoration: const InputDecoration(
                                labelText: 'School Year',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v == null ? 'School Year is required' : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE6E6E6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Optional: Import Learners CSV',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Required columns: Name (or Surname + Given), Gender/Sex, Birthdate/Birthday.\n'
                              'Age is auto-calculated from birthdate. Other columns are optional.\n'
                              'Ensure the file is a valid CSV with a header row.',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickCsv,
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Choose CSV'),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    csvFile?.name ?? 'No file selected',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.maroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      onPressed: _save,
                      child: const Text('Save Class'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<String> _schoolYearOptions() {
    final now = DateTime.now();

    int startYear = now.month >= 6 ? now.year : now.year - 1;

    final currentSY = '$startYear-${startYear + 1}';
    final nextSY = '${startYear + 1}-${startYear + 2}';

    return [nextSY, currentSY];
  }

  String? _normalizeGender(String raw) {
    final g = raw.trim().toLowerCase();
    if (g == 'm' || g == 'male') return 'M';
    if (g == 'f' || g == 'female') return 'F';
    return null;
  }

  DateTime? _parseDateFlexible(String input) {
    final s = input.trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);

    final slash = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
    if (slash != null) {
      final a = int.parse(slash.group(1)!);
      final b = int.parse(slash.group(2)!);
      final y = int.parse(slash.group(3)!);
      if (a <= 12 && b <= 31) return DateTime(y, a, b);
      if (a <= 31 && b <= 12) return DateTime(y, b, a);
    }
    return null;
  }

  int _deriveAge(DateTime birthDate) {
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    final hadBirthday =
        (today.month > birthDate.month) ||
        (today.month == birthDate.month && today.day >= birthDate.day);
    if (!hadBirthday) age -= 1;
    return age;
  }

  (String, String) _splitName(String fullName) {
    final s = fullName.trim();
    if (s.contains(',')) {
      final p = s.split(',');
      final last = p.first.trim();
      final first = p.skip(1).join(' ').trim();
      return (
        first.isEmpty ? 'Unknown' : first,
        last.isEmpty ? 'Unknown' : last,
      );
    }
    final parts = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.length == 1) return (parts.first, 'Unknown');
    final last = parts.removeLast();
    final first = parts.join(' ');
    return (first, last);
  }
}
