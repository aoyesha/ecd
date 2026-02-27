import 'package:flutter/material.dart';

import 'teacher_classes_page.dart';

class TeacherMyClassesPage extends StatelessWidget {
  final int teacherId;

  const TeacherMyClassesPage({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context) {
    return const TeacherClassesPage();
  }
}
