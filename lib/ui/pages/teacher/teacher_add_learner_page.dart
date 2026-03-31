import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../../../core/ui_feedback.dart';
import '../../../core/unsaved_guard.dart';
import '../../../services/learner_service.dart';
import '../../widgets/subpage_shell.dart';

class TeacherAddLearnerPage extends StatefulWidget {
  final int classId;
  const TeacherAddLearnerPage({super.key, required this.classId});

  @override
  State<TeacherAddLearnerPage> createState() => _TeacherAddLearnerPageState();
}

class _TeacherAddLearnerPageState extends State<TeacherAddLearnerPage> {
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
  final motherEducationCtrl = TextEditingController();
  final fatherNameCtrl = TextEditingController();
  final fatherOccupationCtrl = TextEditingController();
  final fatherEducationCtrl = TextEditingController();
  final guardianNameCtrl = TextEditingController();
  final guardianOccupationCtrl = TextEditingController();
  final guardianEducationCtrl = TextEditingController();
  final ageMotherAtBirthCtrl = TextEditingController();

  String? _parentNameValidator(String? v, String label) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    final nameRegex = RegExp(r"^[A-Za-z]+([ '\-][A-Za-z]+)*$");
    if (!nameRegex.hasMatch(value)) {
      return "$label must use letters only, with single spaces, apostrophes, or hyphens";
    }
    return null;
  }

  String? _pupilNameValidator(String? v, String label, {bool required = true}) {
    final value = v?.trim() ?? '';

    if (value.isEmpty) {
      return required ? '$label is required' : null;
    }

    final nameRegex = RegExp(r"^[A-Za-z]+([ '\-][A-Za-z]+)*$");

    if (!nameRegex.hasMatch(value)) {
      return '$label must contain letters only';
    }

    return null;
  }

  String? _occupationValidator(String? v, String label) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    final occupationRegex = RegExp(r"^[A-Za-z]+([ '\-][A-Za-z]+)*$");
    if (!occupationRegex.hasMatch(value)) {
      return "$label must use letters only, with single spaces, apostrophes, or hyphens";
    }
    return null;
  }

  void _syncGuardianFromParentIfNeeded() {
    if (!guardianSameAsParent) return;
    guardianNameCtrl.text = _derivedParentName();
    guardianOccupationCtrl.text = motherOccupationCtrl.text.trim().isNotEmpty
        ? motherOccupationCtrl.text
        : fatherOccupationCtrl.text;
    guardianEducationCtrl.text = _derivedParentEducation();
  }

  String gender = 'M';
  String dominantHand = '';
  DateTime? birthDate;
  bool dirty = false;
  bool guardianSameAsParent = false;

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
    motherEducationCtrl.dispose();
    fatherNameCtrl.dispose();
    fatherOccupationCtrl.dispose();
    fatherEducationCtrl.dispose();
    guardianNameCtrl.dispose();
    guardianOccupationCtrl.dispose();
    guardianEducationCtrl.dispose();
    ageMotherAtBirthCtrl.dispose();
    super.dispose();
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
      AppFeedback.showSnackBar(
        context,
        'Birthdate is required',
        tone: AppFeedbackTone.error,
      );
      return;
    }

    final age = _derivedAgeYears;
    if (age < 3) {
      AppFeedback.showSnackBar(
        context,
        'Pupil age must be at least 3 years old',
        tone: AppFeedbackTone.error,
      );
      return;
    }
    final siblings = int.tryParse(siblingsCtrl.text);
    final birthOrder = int.tryParse(birthOrderCtrl.text);

    if (siblings != null && birthOrder != null) {
      final totalChildren = siblings + 1;

      if (birthOrder > totalChildren) {
        AppFeedback.showSnackBar(
          context,
          'Birth order cannot exceed total children ($totalChildren)',
          tone: AppFeedbackTone.error,
        );
        return;
      }
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
      AppFeedback.showSnackBar(
        context,
        'This pupil already exists in this class',
        tone: AppFeedbackTone.error,
      );
      return;
    }

    final enteredLrn = lrnCtrl.text.trim();
    if (enteredLrn.isNotEmpty) {
      final lrnExists = await _learners.lrnExists(enteredLrn);
      if (lrnExists) {
        if (!mounted) return;
        AppFeedback.showSnackBar(
          context,
          'This LRN is already registered. Please use a unique number',
          tone: AppFeedbackTone.error,
        );
        return;
      }
    }

    try {
      await _learners.addLearner(
        classId: widget.classId,
        firstName: firstNameCtrl.text,
        lastName: lastNameCtrl.text,
        middleName: middleNameCtrl.text,
        gender: gender,
        age: age,
        lrn: lrnCtrl.text,
        birthDate: birthDateStr,
        birthOrder: birthOrderCtrl.text,
        numberOfSiblings: siblingsCtrl.text,
        province: provinceCtrl.text,
        city: cityCtrl.text,
        barangay: barangayCtrl.text,
        motherName: motherNameCtrl.text,
        motherOccupation: motherOccupationCtrl.text,
        motherEducation: motherEducationCtrl.text,
        fatherName: fatherNameCtrl.text,
        fatherOccupation: fatherOccupationCtrl.text,
        fatherEducation: fatherEducationCtrl.text,
        dominantHand: dominantHand,
        parentName: _derivedParentName(),
        parentEducation: _derivedParentEducation(),
        guardianName: guardianSameAsParent
            ? _derivedParentName()
            : guardianNameCtrl.text,
        guardianOccupation: guardianSameAsParent
            ? (motherOccupationCtrl.text.trim().isNotEmpty
                  ? motherOccupationCtrl.text
                  : fatherOccupationCtrl.text)
            : guardianOccupationCtrl.text,
        guardianEducation: guardianSameAsParent
            ? _derivedParentEducation()
            : guardianEducationCtrl.text,
        ageMotherAtBirth: ageMotherAtBirthCtrl.text,
      );

      if (!mounted) return;
      AppFeedback.showSnackBar(
        context,
        'Pupil added successfully',
        tone: AppFeedbackTone.success,
      );
      setState(() => dirty = false);
      Navigator.pop(context);
    } on Exception {
      if (!mounted) return;
      AppFeedback.showSnackBar(
        context,
        'Failed to add pupil. Please try again',
        tone: AppFeedbackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthText = birthDate == null
        ? 'Select birthday'
        : '${birthDate!.year}-${birthDate!.month.toString().padLeft(2, '0')}-${birthDate!.day.toString().padLeft(2, '0')}';

    return UnsavedGuard(
      hasUnsavedChanges: dirty,
      child: SubpageShell(
        title: 'Add Pupil',
        directorySegments: const ['Dashboard', 'My Classes', 'Add Pupil'],
        navIndex: 0,
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
                      icon: Icons.badge_outlined,
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
                                (v) => _pupilNameValidator(v, 'Last Name'),
                                width: fieldWidth,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r"[A-Za-z\s\-']"),
                                  ),
                                ],
                              ),
                              _field(
                                firstNameCtrl,
                                'First Name',
                                (v) => _pupilNameValidator(v, 'First Name'),
                                width: fieldWidth,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r"[A-Za-z\s\-']"),
                                  ),
                                ],
                              ),
                              _field(
                                middleNameCtrl,
                                'Middle Name',
                                (v) => _pupilNameValidator(
                                  v,
                                  'Middle Name',
                                  required: false,
                                ),
                                width: fieldWidth,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r"[A-Za-z\s\-']"),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: fieldWidth,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Color(0xFFBCA5A5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
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
                              _field(
                                lrnCtrl,
                                'LRN',
                                (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'LRN is required';
                                  }
                                  if (!RegExp(r'^\d{12}$').hasMatch(v.trim())) {
                                    return 'LRN must be exactly 12 digits';
                                  }
                                  return null;
                                },
                                width: fieldWidth,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12),
                                ],
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
                                  decoration: _inputDecoration('Gender'),
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
                      icon: Icons.edit_note_outlined,
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

                          Widget group(String title, List<Widget> fields) {
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE8E1E1),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4B2A2E),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: fields,
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              group('General', [
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: constraints.maxWidth >= 620
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: _field(
                                                provinceCtrl,
                                                'Province',
                                                null,
                                                width: double.infinity,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _field(
                                                cityCtrl,
                                                'City',
                                                null,
                                                width: double.infinity,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _field(
                                                barangayCtrl,
                                                'Barangay',
                                                null,
                                                width: double.infinity,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            _field(
                                              provinceCtrl,
                                              'Province',
                                              null,
                                              width: double.infinity,
                                            ),
                                            const SizedBox(height: 10),
                                            _field(
                                              cityCtrl,
                                              'City',
                                              null,
                                              width: double.infinity,
                                            ),
                                            const SizedBox(height: 10),
                                            _field(
                                              barangayCtrl,
                                              'Barangay',
                                              null,
                                              width: double.infinity,
                                            ),
                                          ],
                                        ),
                                ),
                                _field(
                                  siblingsCtrl,
                                  'Number of Siblings',
                                  (v) {
                                    if (v == null || v.isEmpty) return null;
                                    final siblings = int.tryParse(v);
                                    if (siblings == null)
                                      return 'Invalid number';
                                    if (siblings < 0)
                                      return 'Cannot be negative';
                                    return null;
                                  },
                                  width: fieldWidth,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: () =>
                                      formKey.currentState!.validate(),
                                ),
                                _field(
                                  birthOrderCtrl,
                                  'Birth Order',
                                  (v) {
                                    if (v == null || v.isEmpty) return null;
                                    final birthOrder = int.tryParse(v);
                                    if (birthOrder == null)
                                      return 'Invalid number';
                                    if (birthOrder <= 0)
                                      return 'Must be at least 1';
                                    final siblings = int.tryParse(
                                      siblingsCtrl.text,
                                    );
                                    if (siblings != null) {
                                      final totalChildren = siblings + 1;
                                      if (birthOrder > totalChildren) {
                                        return 'Cannot exceed total children ($totalChildren)';
                                      }
                                    }
                                    return null;
                                  },
                                  width: fieldWidth,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: dominantHand.isEmpty
                                        ? null
                                        : dominantHand,
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Left',
                                        child: Text('Left'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Right',
                                        child: Text('Right'),
                                      ),
                                    ],
                                    onChanged: (v) => setState(() {
                                      dominantHand = v ?? '';
                                      dirty = true;
                                    }),
                                    decoration: _inputDecoration(
                                      'Dominant Hand',
                                    ),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              group("Mother's Details", [
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: constraints.maxWidth >= 620
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: _field(
                                                motherNameCtrl,
                                                'Mother Name',
                                                (v) => _pupilNameValidator(
                                                  v,
                                                  'Mother Name',
                                                  required: false,
                                                ),
                                                width: double.infinity,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r"[A-Za-z\s\-']"),
                                                  ),
                                                ],
                                                onChanged:
                                                    _syncGuardianFromParentIfNeeded,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _field(
                                                motherOccupationCtrl,
                                                "Mother's Occupation",
                                                (v) => _occupationValidator(
                                                  v,
                                                  "Mother's Occupation",
                                                ),
                                                width: double.infinity,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r"[A-Za-z\s\-']"),
                                                  ),
                                                ],
                                                onChanged:
                                                    _syncGuardianFromParentIfNeeded,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _field(
                                                motherEducationCtrl,
                                                "Mother's Highest Educational Attainment",
                                                null,
                                                width: double.infinity,
                                                onChanged:
                                                    _syncGuardianFromParentIfNeeded,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            _field(
                                              motherNameCtrl,
                                              'Mother Name',
                                              (v) => _pupilNameValidator(
                                                v,
                                                'Mother Name',
                                                required: false,
                                              ),
                                              width: double.infinity,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r"[A-Za-z\s\-']"),
                                                ),
                                              ],
                                              onChanged:
                                                  _syncGuardianFromParentIfNeeded,
                                            ),
                                            const SizedBox(height: 10),
                                            _field(
                                              motherOccupationCtrl,
                                              "Mother's Occupation",
                                              (v) => _occupationValidator(
                                                v,
                                                "Mother's Occupation",
                                              ),
                                              width: double.infinity,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r"[A-Za-z\s\-']"),
                                                ),
                                              ],
                                              onChanged:
                                                  _syncGuardianFromParentIfNeeded,
                                            ),
                                            const SizedBox(height: 10),
                                            _field(
                                              motherEducationCtrl,
                                              "Mother's Highest Educational Attainment",
                                              null,
                                              width: double.infinity,
                                              onChanged:
                                                  _syncGuardianFromParentIfNeeded,
                                            ),
                                          ],
                                        ),
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
                              ]),
                              const SizedBox(height: 10),
                              group("Father's Details", [
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: constraints.maxWidth >= 620
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: _field(
                                                fatherNameCtrl,
                                                'Father Name',
                                                (v) => _pupilNameValidator(
                                                  v,
                                                  'Father Name',
                                                  required: false,
                                                ),
                                                width: double.infinity,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r"[A-Za-z\s\-']"),
                                                  ),
                                                ],
                                                onChanged:
                                                    _syncGuardianFromParentIfNeeded,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _field(
                                                fatherOccupationCtrl,
                                                "Father's Occupation",
                                                (v) => _occupationValidator(
                                                  v,
                                                  "Father's Occupation",
                                                ),
                                                width: double.infinity,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r"[A-Za-z\s\-']"),
                                                  ),
                                                ],
                                                onChanged:
                                                    _syncGuardianFromParentIfNeeded,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _field(
                                                fatherEducationCtrl,
                                                "Father's Highest Educational Attainment",
                                                null,
                                                width: double.infinity,
                                                onChanged:
                                                    _syncGuardianFromParentIfNeeded,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            _field(
                                              fatherNameCtrl,
                                              'Father Name',
                                              (v) => _pupilNameValidator(
                                                v,
                                                'Father Name',
                                                required: false,
                                              ),
                                              width: double.infinity,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r"[A-Za-z\s\-']"),
                                                ),
                                              ],
                                              onChanged:
                                                  _syncGuardianFromParentIfNeeded,
                                            ),
                                            const SizedBox(height: 10),
                                            _field(
                                              fatherOccupationCtrl,
                                              "Father's Occupation",
                                              (v) => _occupationValidator(
                                                v,
                                                "Father's Occupation",
                                              ),
                                              width: double.infinity,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r"[A-Za-z\s\-']"),
                                                ),
                                              ],
                                              onChanged:
                                                  _syncGuardianFromParentIfNeeded,
                                            ),
                                            const SizedBox(height: 10),
                                            _field(
                                              fatherEducationCtrl,
                                              "Father's Highest Educational Attainment",
                                              null,
                                              width: double.infinity,
                                              onChanged:
                                                  _syncGuardianFromParentIfNeeded,
                                            ),
                                          ],
                                        ),
                                ),
                              ]),
                              const SizedBox(height: 10),
                              group('Guardian Details', [
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: CheckboxListTile(
                                    value: guardianSameAsParent,
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: const Text('Same as parent details'),
                                    onChanged: (v) {
                                      final useSame = v ?? false;
                                      setState(() {
                                        guardianSameAsParent = useSame;
                                        if (useSame) {
                                          _syncGuardianFromParentIfNeeded();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: constraints.maxWidth >= 620
                                      ? Row(
                                          children: [
                                            Expanded(
                                              child: _field(
                                                guardianNameCtrl,
                                                "Guardian's Name",
                                                (v) {
                                                  if (guardianSameAsParent) return null;
                                                  return _parentNameValidator(v, "Guardian's Name");
                                                    },
                                                width: double.infinity,
                                                readOnly: guardianSameAsParent,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r"[A-Za-z\s\-']"),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _field(
                                                guardianOccupationCtrl,
                                                "Guardian's Occupation",
                                               (v) {
                                                if (guardianSameAsParent) return null;
                                                return _occupationValidator(v, "Guardian's Occupation");
                                                },
                                                width: double.infinity,
                                                readOnly: guardianSameAsParent,
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r"[A-Za-z\s\-']"),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: _field(
                                                guardianEducationCtrl,
                                                "Guardian's Highest Educational Attainment",
                                                null,
                                                width: double.infinity,
                                                readOnly: guardianSameAsParent,
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          children: [
                                            _field(
                                              guardianNameCtrl,
                                              "Guardian's Name",
                                              (v) => _parentNameValidator(
                                                v,
                                                "Guardian's Name",
                                              ),
                                              width: double.infinity,
                                              readOnly: guardianSameAsParent,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r"[A-Za-z\s\-']"),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            _field(
                                              guardianOccupationCtrl,
                                              "Guardian's Occupation",
                                              (v) => _occupationValidator(
                                                v,
                                                "Guardian's Occupation",
                                              ),
                                              width: double.infinity,
                                              readOnly: guardianSameAsParent,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.allow(
                                                  RegExp(r"[A-Za-z\s\-']"),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            _field(
                                              guardianEducationCtrl,
                                              "Guardian's Highest Educational Attainment",
                                              null,
                                              width: double.infinity,
                                              readOnly: guardianSameAsParent,
                                            ),
                                          ],
                                        ),
                                ),
                              ]),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.maroon,
                          foregroundColor: Colors.white,
                          elevation: 1.5,
                          minimumSize: const Size(240, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _save,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Save Pupil'),
                      ),
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

  Widget _sectionCard(String title, Widget child, {IconData? icon}) {
    return Card(
      elevation: 0.5,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE8E1E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.maroon),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Color(0xFF272727),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
    bool readOnly = false,
    VoidCallback? onChanged, // ADD THIS
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: c,
        validator: validator,
        readOnly: readOnly,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: (_) {
          if (onChanged != null) onChanged();
        },
        decoration: _inputDecoration(label).copyWith(
          fillColor: readOnly ? const Color(0xFFF1EEEE) : Colors.white,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFBCA5A5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.maroon, width: 1.3),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + end.month - start.month;
    if (end.day < start.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  String _derivedParentName() =>
      _joinNonEmpty([motherNameCtrl.text, fatherNameCtrl.text], ' / ');

  String _derivedParentEducation() => _joinNonEmpty([
    motherEducationCtrl.text,
    fatherEducationCtrl.text,
  ], ' / ');

  String _joinNonEmpty(List<String> values, String separator) {
    final list = values
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return list.join(separator);
  }
}
