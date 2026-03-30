import 'package:flutter/material.dart';

import '../../../core/app_dialogs.dart';
import '../../../core/constants.dart';
import '../../widgets/section_title.dart';
import 'teacher_classes_page.dart';
import 'teacher_my_summary_page.dart';

class TeacherDashboardPage extends StatefulWidget {
  final int teacherId;
  final ValueChanged<List<String>>? onDirectoryChanged;

  const TeacherDashboardPage({
    super.key,
    required this.teacherId,
    this.onDirectoryChanged,
  });

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  int tab = 0;

  List<String> get _directorySegments => switch (tab) {
    0 => const ['Dashboard', 'My Classes'],
    1 => const ['Dashboard', 'My Summary'],
    _ => const ['Dashboard'],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onDirectoryChanged?.call(_directorySegments);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const TeacherClassesPage(),
      TeacherMySummaryPage(teacherId: widget.teacherId),
    ];

    return Stack(
      children: [
        Padding(
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
                    onSelectionChanged: (v) {
                      setState(() => tab = v.first);
                      widget.onDirectoryChanged?.call(_directorySegments);
                    },
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
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            onPressed: () {
              AppDialogs.showHelpDialog(context);
            },
            backgroundColor: AppColors.maroon,
            foregroundColor: Colors.white,
            elevation: 6,
            highlightElevation: 10,
            shape: const CircleBorder(),
            child: const Text(
              '?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
