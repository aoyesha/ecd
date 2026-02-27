import 'package:flutter/material.dart';

import '../../widgets/section_title.dart';
import 'teacher_classes_page.dart';
import 'teacher_my_summary_page.dart';

class TeacherDashboardPage extends StatefulWidget {
  final int teacherId;

  const TeacherDashboardPage({super.key, required this.teacherId});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const TeacherClassesPage(),
      TeacherMySummaryPage(teacherId: widget.teacherId),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final segmented = SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('My Classes')),
                  ButtonSegment(value: 1, label: Text('My Summary')),
                ],
                selected: {tab},
                onSelectionChanged: (v) => setState(() => tab = v.first),
              );
              if (!compact) {
                return Row(
                  children: [
                    const Expanded(child: SectionTitle(title: 'Dashboard')),
                    segmented,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: 'Dashboard'),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: segmented,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(child: tabs[tab]),
        ],
      ),
    );
  }
}
