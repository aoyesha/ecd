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
  State<TeacherAddLearnerPage> createState() => _TeacherAddLearnerPageState(


  );
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

  final _nameFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'[A-Za-z]'),
  );

  final _parentNameFormatter = FilteringTextInputFormatter.allow(
    RegExp(r"[a-zA-Z]"),
  );

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

    // ================= CROSS FIELD VALIDATION =================

    final siblings = int.tryParse(siblingsCtrl.text);
    final birthOrder = int.tryParse(birthOrderCtrl.text);

    if (siblings != null && birthOrder != null) {
      final totalChildren = siblings + 1;

      if (birthOrder > totalChildren) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Birth order cannot exceed total children ($totalChildren).',
            ),
          ),
        );
        return;
      }

      if (birthOrder <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Birth order must be at least 1.'),
          ),
        );
        return;
      }
    }

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
    final birthDateStr =
        '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}';

    final exists = await _learners.learnerExists(
      classId: widget.classId,
      firstName: firstNameCtrl.text.trim(),
      lastName: lastNameCtrl.text.trim(),
      birthDate: birthDateStr,
    );

    if (exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This pupil already exists in this class.'),
        ),
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
                                inputFormatters: [_nameFormatter],
                              ),
                              _field(
                                firstNameCtrl,
                                'First Name',
                                width: fieldWidth,
                                required: true,
                                inputFormatters: [_nameFormatter],
                              ),
                              _field(
                                middleNameCtrl,
                                'Middle Name',
                                width: fieldWidth,
                                required: false,
                                inputFormatters: [_nameFormatter],
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
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12), // max 12 digits
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
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: () => formKey.currentState!.validate(),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return null;
                                  if (int.tryParse(v) == null) return 'Invalid number';
                                  return null;
                                },
                              ),
                              _field(
                                birthOrderCtrl,
                                'Birth Order',
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                validator: (v) {
                                  if (v == null || v.isEmpty) return null;

                                  final birthOrder = int.tryParse(v);
                                  if (birthOrder == null) return 'Invalid number';

                                  final siblings = int.tryParse(siblingsCtrl.text);
                                  if (siblings == null) return null;

                                  final totalChildren = siblings + 1;

                                  if (birthOrder > totalChildren) {
                                    return 'Birth order cannot exceed $totalChildren';
                                  }
                                  if (birthOrder <= 0) {
                                    return 'Birth order must be at least 1';
                                  }
                                  return null;
                                },
                              ),
                              _field(
                                motherNameCtrl,
                                "Mother's Name",
                                width: fieldWidth,
                                validator: (v) => _parentNameValidator(v, "Mother's name"),
                                inputFormatters: [_parentNameFormatter],
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
                                validator: (v) => _parentNameValidator(v, "Father's name"),
                                inputFormatters: [_parentNameFormatter],
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
                                validator: (v) => _parentNameValidator(v, "Guardian's name"),
                                inputFormatters: [_parentNameFormatter],
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

  String? _parentNameValidator(String? v, String label) {
    if (v == null || v.isEmpty) return null; // optional field

    final onlyLetters = RegExp(r'^[A-Za-z]+$');
    if (!onlyLetters.hasMatch(v)) {
      return '$label must contain letters only (no spaces or symbols)';
    }
    return null;
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
        String? Function(String?)? validator,
        VoidCallback? onChanged,
        TextInputType? keyboardType,
        List<TextInputFormatter>? inputFormatters,
      }) {

    String? Function(String?)? finalValidator;

    if (validator != null) {
      finalValidator = validator;
    } else if (required) {
      finalValidator = (v) => Validators.required(v, label: label);
    } else {
      finalValidator = null;
    }

    return SizedBox(
      width: width,
      child: TextFormField(
        controller: c,
        validator: finalValidator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,

        onChanged: (_) {
          if (onChanged != null) onChanged();
        },

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
