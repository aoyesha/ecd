import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/unsaved_guard.dart';
import '../../../core/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_service.dart';
import '../../../services/learner_service.dart';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a School Year')));
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
      final text = await File(csvFile!.path!).readAsString();
      await _importLearnersFromCsv(classId, text);
    }

    if (!mounted) return;
    setState(() => dirty = false);
    Navigator.pop(context);
  }

  Future<void> _importLearnersFromCsv(int classId, String csvText) async {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csvText);
    if (rows.isEmpty) return;

    final header = rows.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList(growable: false);
    final col = <String, int>{
      for (int i = 0; i < header.length; i++) header[i]: i,
    };

    String cell(List<dynamic> row, List<String> keys) {
      for (final k in keys) {
        final idx = col[k];
        if (idx == null || idx >= row.length) continue;
        final v = row[idx].toString().trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

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
      final motherName = cell(row, const ['mother_name', 'mother name']);
      final motherOccupation = cell(row, const [
        'mother_occupation',
        'mother occupation',
      ]);
      final fatherName = cell(row, const ['father_name', 'father name']);
      final fatherOccupation = cell(row, const [
        'father_occupation',
        'father occupation',
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
      if (nameText.isEmpty || genderRaw.isEmpty || birthRaw.isEmpty) continue;

      final parsedGender = _normalizeGender(genderRaw);
      final birthDate = _parseDateFlexible(birthRaw);
      if (parsedGender == null || birthDate == null) continue;

      final age = _deriveAge(birthDate);
      if (age < 3 || age > 5) continue;

      final parsed = _splitName(nameText);
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
        motherName: motherName,
        motherOccupation: motherOccupation,
        fatherName: fatherName,
        fatherOccupation: fatherOccupation,
        ageMotherAtBirth: ageMotherAtBirth,
        spouseOccupation: spouseOccupation,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return UnsavedGuard(
      hasUnsavedChanges: dirty,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Class'),
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
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
                      children: [
                        SizedBox(
                          width: 260,
                          child: TextFormField(
                            controller: gradeCtrl,
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
                            value: schoolYear,
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
                            'Required fields: Full Name (or Surname + Given Name), Gender/Sex, Birthdate/Birthday.\n'
                            'Age is auto-derived from birthdate. Other columns are optional.',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _pickCsv,
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Choose CSV'),
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
                    ),
                    onPressed: _save,
                    child: const Text('Save Class'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<String> _schoolYearOptions() {
    return schoolYearRangeOptions(startYear: 2020, yearsFromNow: 10);
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
