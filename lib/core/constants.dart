import 'package:flutter/material.dart';

class AppColors {
  static const maroon = Color(0xFF7A1E22);
  static const maroonDark = Color(0xFF61171A);
  static const offWhite = Color(0xFFF8F8F8);
  static const border = Color(0xFFE6E6E6);
}

class AppStrings {
  static const appName = 'ECCD Checklist';
}

enum UserRole { teacher, admin }

enum AssessmentType {
  pre,
  post,
} // Conditional overwrites PRE, so we store it as PRE.

enum Language { english, tagalog }

String roleLabel(UserRole role) =>
    role == UserRole.teacher ? 'Teacher' : 'Admin';

String assessmentLabel(AssessmentType t) =>
    t == AssessmentType.pre ? 'Pre-Test' : 'Post-Test';

String assessmentTypeDisplay(String typeCode) {
  switch (typeCode.trim().toLowerCase()) {
    case 'pre':
      return 'Pre-Test';
    case 'post':
      return 'Post-Test';
    case 'conditional':
      return 'Conditional Test';
    default:
      return typeCode;
  }
}

String languageLabel(Language l) =>
    l == Language.english ? 'English' : 'Tagalog';

String toSchoolYearPair(int startYear) => '$startYear-${startYear + 1}';

List<String> schoolYearRangeOptions({
  int startYear = 2020,
  int yearsFromNow = 0,
  bool descending = true,
}) {
  final endStartYear = DateTime.now().year + yearsFromNow;
  final out = <String>[
    for (int y = startYear; y <= endStartYear; y++) toSchoolYearPair(y),
  ];
  if (descending) {
    return out.reversed.toList();
  }
  return out;
}
