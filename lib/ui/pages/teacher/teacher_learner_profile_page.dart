import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../../../core/unsaved_guard.dart';
import '../../../core/validators.dart';
import '../../../services/learner_service.dart';

class TeacherLearnerProfilePage extends StatefulWidget {
  final int learnerId;
  const TeacherLearnerProfilePage({super.key, required this.learnerId});

  @override
  State<TeacherLearnerProfilePage> createState() =>
      _TeacherLearnerProfilePageState();
}

class _TeacherLearnerProfilePageState extends State<TeacherLearnerProfilePage> {
  final _learners = LearnerService();

  final formKey = GlobalKey<FormState>();

  // Required
  final lastNameCtrl = TextEditingController();
  final firstNameCtrl = TextEditingController();
  final middleNameCtrl = TextEditingController();

  // Optional
  final lrnCtrl = TextEditingController();
  final birthOrderCtrl = TextEditingController();
  final siblingsCtrl = TextEditingController();
  final provinceCtrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final barangayCtrl = TextEditingController();
  final motherNameCtrl = TextEditingController();
  final motherOccupationCtrl = TextEditingController();
  final fatherNameCtrl = TextEditingController();
  final fatherOccupationCtrl = TextEditingController();
  final parentNameCtrl = TextEditingController();
  final parentOccupationCtrl = TextEditingController();
  final ageMotherAtBirthCtrl = TextEditingController();

  String gender = 'M';
  DateTime? birthDate;
  bool dirty = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    lastNameCtrl.dispose();
    firstNameCtrl.dispose();
    middleNameCtrl.dispose();
    lrnCtrl.dispose();
    birthOrderCtrl.dispose();
    siblingsCtrl.dispose();
    provinceCtrl.dispose();
    cityCtrl.dispose();
    barangayCtrl.dispose();
    motherNameCtrl.dispose();
    motherOccupationCtrl.dispose();
    fatherNameCtrl.dispose();
    fatherOccupationCtrl.dispose();
    parentNameCtrl.dispose();
    parentOccupationCtrl.dispose();
    ageMotherAtBirthCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final row = await _learners.getLearner(widget.learnerId);
    if (row == null) return;

    lastNameCtrl.text = (row['last_name'] ?? '').toString();
    firstNameCtrl.text = (row['first_name'] ?? '').toString();
    middleNameCtrl.text = (row['middle_name'] ?? '').toString();

    lrnCtrl.text = (row['lrn'] ?? '').toString();
    birthOrderCtrl.text = (row['birth_order'] ?? '').toString();
    siblingsCtrl.text = (row['number_of_siblings'] ?? '').toString();
    provinceCtrl.text = (row['province'] ?? '').toString();
    cityCtrl.text = (row['city'] ?? '').toString();
    barangayCtrl.text = (row['barangay'] ?? '').toString();
    motherNameCtrl.text = (row['mother_name'] ?? '').toString();
    motherOccupationCtrl.text = (row['mother_occupation'] ?? '').toString();
    fatherNameCtrl.text = (row['father_name'] ?? '').toString();
    fatherOccupationCtrl.text = (row['father_occupation'] ?? '').toString();
    parentNameCtrl.text = (row['parent_name'] ?? '').toString();
    parentOccupationCtrl.text = (row['parent_occupation'] ?? '').toString();
    ageMotherAtBirthCtrl.text = (row['age_mother_at_birth'] ?? '').toString();

    final g = (row['gender'] ?? 'M').toString().toUpperCase();
    gender = g == 'F' ? 'F' : 'M';

    final birthRaw = (row['birth_date'] ?? '').toString();
    birthDate = _parseDateFlexible(birthRaw);

    setState(() => loading = false);
  }

  String get _ageDecimal {
    if (birthDate == null) return '-';
    final months = _monthsBetween(birthDate!, DateTime.now());
    return '${months ~/ 12}.${months % 12}';
  }

  int get _derivedAgeYears {
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
      ).showSnackBar(const SnackBar(content: Text('Birthdate is required')));
      return;
    }

    final age = _derivedAgeYears;
    if (age < 3 || age > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Derived age must be between 3 and 5.')),
      );
      return;
    }

    await _learners.updateLearner(
      learnerId: widget.learnerId,
      firstName: firstNameCtrl.text,
      lastName: lastNameCtrl.text,
      middleName: middleNameCtrl.text,
      gender: gender,
      age: age,
      lrn: lrnCtrl.text,
      birthDate:
          '${birthDate!.year.toString().padLeft(4, '0')}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}',
      birthOrder: birthOrderCtrl.text,
      numberOfSiblings: siblingsCtrl.text,
      province: provinceCtrl.text,
      city: cityCtrl.text,
      barangay: barangayCtrl.text,
      motherName: motherNameCtrl.text,
      motherOccupation: motherOccupationCtrl.text,
      fatherName: fatherNameCtrl.text,
      fatherOccupation: fatherOccupationCtrl.text,
      parentName: parentNameCtrl.text,
      parentOccupation: parentOccupationCtrl.text,
      ageMotherAtBirth: ageMotherAtBirthCtrl.text,
    );

    if (!mounted) return;
    setState(() => dirty = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
          title: const Text('Pupil Profile'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final birthText = birthDate == null
        ? 'Select birthday'
        : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}';

    return UnsavedGuard(
      hasUnsavedChanges: dirty,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.maroon,
          foregroundColor: Colors.white,
          title: const Text('Pupil Profile'),
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
                                (v) =>
                                    Validators.required(v, label: 'Last Name'),
                                width: fieldWidth,
                              ),
                              _field(
                                firstNameCtrl,
                                'First Name',
                                (v) =>
                                    Validators.required(v, label: 'First Name'),
                                width: fieldWidth,
                              ),
                              _field(
                                middleNameCtrl,
                                'Middle Name',
                                (v) => Validators.required(
                                  v,
                                  label: 'Middle Name',
                                ),
                                width: fieldWidth,
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 12,
                                    ),
                                  ),
                                  onPressed: _pickBirthDate,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      birthText,
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
                                  onChanged: (v) => setState(() {
                                    gender = v ?? 'M';
                                    dirty = true;
                                  }),
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
                                null,
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _field(
                                provinceCtrl,
                                'Province',
                                null,
                                width: fieldWidth,
                              ),
                              _field(cityCtrl, 'City', null, width: fieldWidth),
                              _field(
                                barangayCtrl,
                                'Barangay',
                                null,
                                width: fieldWidth,
                              ),
                              _field(
                                siblingsCtrl,
                                'Number of Siblings',
                                null,
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _field(
                                birthOrderCtrl,
                                'Birth Order',
                                null,
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _field(
                                motherNameCtrl,
                                "Mother's Name",
                                null,
                                width: fieldWidth,
                              ),
                              _field(
                                motherOccupationCtrl,
                                "Mother's Occupation",
                                null,
                                width: fieldWidth,
                              ),
                              _field(
                                ageMotherAtBirthCtrl,
                                "Mother's Age at Birth",
                                null,
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              _field(
                                fatherNameCtrl,
                                "Father's Name",
                                null,
                                width: fieldWidth,
                              ),
                              _field(
                                fatherOccupationCtrl,
                                "Father's Occupation",
                                null,
                                width: fieldWidth,
                              ),
                              _field(
                                parentNameCtrl,
                                "Parent/Guardian's Name",
                                null,
                                width: fieldWidth,
                              ),
                              _field(
                                parentOccupationCtrl,
                                "Parent/Guardian's Occupation",
                                null,
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
                      child: const Text('Save Changes'),
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
    String label,
    String? Function(String?)? validator, {
    required double width,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: c,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
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

  int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + end.month - start.month;
    if (end.day < start.day) months -= 1;
    return months < 0 ? 0 : months;
  }
}
