import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../../../core/unsaved_guard.dart';
import '../../../core/validators.dart';
import '../../../services/learner_service.dart';

class TeacherAddLearnerPage extends StatefulWidget {
  final int classId;
  const TeacherAddLearnerPage({super.key, required this.classId});

  @override
  State<TeacherAddLearnerPage> createState() => _TeacherAddLearnerPageState();
}

class _TeacherAddLearnerPageState extends State<TeacherAddLearnerPage> {
  final formKey = GlobalKey<FormState>();

  // Required
  final lastNameCtrl = TextEditingController();
  final firstNameCtrl = TextEditingController();
  final middleNameCtrl = TextEditingController();
  String gender = 'M';
  DateTime? birthDate;

  // Optional
  final lrnCtrl = TextEditingController();
  final provinceCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final barangayCtrl = TextEditingController();
  final siblingsCtrl = TextEditingController();
  final birthOrderCtrl = TextEditingController();
  final motherNameCtrl = TextEditingController();
  final motherOccupationCtrl = TextEditingController();
  final motherAgeAtBirthCtrl = TextEditingController();
  final fatherNameCtrl = TextEditingController();
  final fatherOccupationCtrl = TextEditingController();
  final guardianNameCtrl = TextEditingController();
  final guardianOccupationCtrl = TextEditingController();

  bool dirty = false;

  final _learners = LearnerService();

  @override
  void dispose() {
    lastNameCtrl.dispose();
    firstNameCtrl.dispose();
    middleNameCtrl.dispose();
    lrnCtrl.dispose();
    provinceCtrl.dispose();
    cityCtrl.dispose();
    barangayCtrl.dispose();
    siblingsCtrl.dispose();
    birthOrderCtrl.dispose();
    motherNameCtrl.dispose();
    motherOccupationCtrl.dispose();
    motherAgeAtBirthCtrl.dispose();
    fatherNameCtrl.dispose();
    fatherOccupationCtrl.dispose();
    guardianNameCtrl.dispose();
    guardianOccupationCtrl.dispose();
    super.dispose();
  }

  String get _ageDecimal {
    if (birthDate == null) return '-';
    final months = _monthsBetween(birthDate!, DateTime.now());
    return '${months ~/ 12}.${months % 12}';
  }

  int get _ageYears {
    if (birthDate == null) return 0;
    final months = _monthsBetween(birthDate!, DateTime.now());
    return months ~/ 12;
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year - 2),
      initialDate: birthDate ?? DateTime(now.year - 4, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      birthDate = picked;
      dirty = true;
    });
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    if (birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Birthday is required')));
      return;
    }

    final age = _ageYears;
    if (age < 3 || age > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Derived age must be between 3 and 5.')),
      );
      return;
    }

    await _learners.addLearner(
      classId: widget.classId,
      firstName: firstNameCtrl.text,
      lastName: lastNameCtrl.text,
      middleName: middleNameCtrl.text,
      gender: gender,
      age: age,
      birthDate:
          '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
      lrn: lrnCtrl.text,
      province: provinceCtrl.text,
      city: cityCtrl.text,
      barangay: barangayCtrl.text,
      numberOfSiblings: siblingsCtrl.text,
      birthOrder: birthOrderCtrl.text,
      motherName: motherNameCtrl.text,
      motherOccupation: motherOccupationCtrl.text,
      ageMotherAtBirth: motherAgeAtBirthCtrl.text,
      fatherName: fatherNameCtrl.text,
      fatherOccupation: fatherOccupationCtrl.text,
      parentName: guardianNameCtrl.text,
      parentOccupation: guardianOccupationCtrl.text,
    );

    if (!mounted) return;
    setState(() => dirty = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final birthdayText = birthDate == null
        ? 'Select birthday'
        : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}';

    return UnsavedGuard(
      hasUnsavedChanges: dirty,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Pupil'),
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Form(
                key: formKey,
                onChanged: () => setState(() => dirty = true),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionCard(
                      'Required Information',
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 620
                              ? 2
                              : 1;
                          final fieldWidth =
                              (constraints.maxWidth - ((columns - 1) * 10)) /
                              columns;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _field(
                                lastNameCtrl,
                                'Last Name',
                                width: fieldWidth,
                                required: true,
                              ),
                              _field(
                                firstNameCtrl,
                                'First Name',
                                width: fieldWidth,
                                required: true,
                              ),
                              _field(
                                middleNameCtrl,
                                'Middle Name',
                                width: fieldWidth,
                                required: true,
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  onPressed: _pickBirthDate,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      birthdayText,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: DropdownButtonFormField<String>(
                                  initialValue: gender,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'M',
                                      child: Text('Male'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'F',
                                      child: Text('Female'),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => gender = v ?? 'M'),
                                  decoration: const InputDecoration(
                                    labelText: 'Gender',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              Container(
                                width: fieldWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Age (derived): $_ageDecimal',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(
                      'Optional Information',
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 900
                              ? 3
                              : constraints.maxWidth >= 620
                              ? 2
                              : 1;
                          final fieldWidth =
                              (constraints.maxWidth - ((columns - 1) * 10)) /
                              columns;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _field(
                                lrnCtrl,
                                'LRN',
                                width: fieldWidth,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _field(
                                provinceCtrl,
                                'Province',
                                width: fieldWidth,
                              ),
                              _field(cityCtrl, 'City', width: fieldWidth),
                              _field(
                                barangayCtrl,
                                'Barangay',
                                width: fieldWidth,
                              ),
                              _field(
                                siblingsCtrl,
                                'Number of Siblings',
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _field(
                                birthOrderCtrl,
                                'Birth Order',
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _field(
                                motherNameCtrl,
                                "Mother's Name",
                                width: fieldWidth,
                              ),
                              _field(
                                motherOccupationCtrl,
                                "Mother's Occupation",
                                width: fieldWidth,
                              ),
                              _field(
                                motherAgeAtBirthCtrl,
                                "Mother's Age at Birth",
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _field(
                                fatherNameCtrl,
                                "Father's Name",
                                width: fieldWidth,
                              ),
                              _field(
                                fatherOccupationCtrl,
                                "Father's Occupation",
                                width: fieldWidth,
                              ),
                              _field(
                                guardianNameCtrl,
                                "Parent/Guardian's Name",
                                width: fieldWidth,
                              ),
                              _field(
                                guardianOccupationCtrl,
                                "Parent/Guardian's Occupation",
                                width: fieldWidth,
                              ),
                            ],
                          );
                        },
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
                      child: const Text('Save Pupil'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(String title, Widget child) {
    return Card(
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
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    required double width,
    bool required = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: c,
        validator: required
            ? (v) => Validators.required(v, label: label)
            : null,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + end.month - start.month;
    if (end.day < start.day) months -= 1;
    return months < 0 ? 0 : months;
  }
}
