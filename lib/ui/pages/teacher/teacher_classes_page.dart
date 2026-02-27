import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/nav_no_transition.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_service.dart';
import 'teacher_add_class_page.dart';
import 'teacher_class_dashboard_page.dart';

class TeacherClassesPage extends StatefulWidget {
  const TeacherClassesPage({super.key});

  @override
  State<TeacherClassesPage> createState() => _TeacherClassesPageState();
}

class _TeacherClassesPageState extends State<TeacherClassesPage> {
  final _classService = ClassService();
  String? schoolYearFilter;
  int _reloadTick = 0;

  Future<List<Map<String, Object?>>> _load(int teacherId) {
    return _classService.listActiveClasses(
      teacherId,
      schoolYear: schoolYearFilter,
    );
  }

  Future<void> _openAddClass() async {
    await navPushNoTransition(context, const TeacherAddClassPage());
    if (!mounted) return;
    setState(() => _reloadTick++);
  }

  Future<void> _openClass(Map<String, Object?> c) async {
    await navPushNoTransition(
      context,
      TeacherClassDashboardPage(
        classId: c['id'] as int,
        grade: c['grade'] as String,
        section: c['section'] as String,
        schoolYear: c['school_year'] as String,
      ),
    );
    if (!mounted) return;
    setState(() => _reloadTick++);
  }

  @override
  Widget build(BuildContext context) {
    final teacherId = context.watch<AuthService>().session!.userId;
    final isMobile = MediaQuery.of(context).size.width < 700;
    final cardWidth = isMobile ? 170.0 : 260.0;
    final cardHeight = isMobile ? 190.0 : 330.0;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final dropdown = DropdownButton<String>(
              value: schoolYearFilter,
              hint: const Text('School Year'),
              items: _schoolYearOptions()
                  .map((sy) => DropdownMenuItem(value: sy, child: Text(sy)))
                  .toList(),
              onChanged: (v) => setState(() => schoolYearFilter = v),
            );
            if (!compact) {
              return Row(children: [const Spacer(), dropdown]);
            }
            return Row(children: [dropdown]);
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            key: ValueKey(_reloadTick),
            future: _load(teacherId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final classes = snapshot.data!;

              final items = <Widget>[
                ...classes.map((c) {
                  final classId = c['id'] as int;
                  final grade = c['grade'] as String;
                  final section = c['section'] as String;
                  final sy = c['school_year'] as String;
                  return _NotebookCard(
                    width: cardWidth,
                    height: cardHeight,
                    color: _pastelForClassId(classId),
                    schoolYear: sy,
                    grade: grade,
                    section: section,
                    onOpen: () => _openClass(c),
                  );
                }),
                _AddClassCard(
                  width: cardWidth,
                  height: cardHeight,
                  onTap: () {
                    _openAddClass();
                  },
                ),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    runAlignment: WrapAlignment.start,
                    spacing: 16,
                    runSpacing: 16,
                    children: items,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _pastelForClassId(int classId) {
    const palette = [
      Color(0xFFE3F2FD),
      Color(0xFFE8F5E9),
      Color(0xFFFFF3E0),
      Color(0xFFF3E5F5),
      Color(0xFFFFEBEE),
      Color(0xFFE0F2F1),
      Color(0xFFFCE4EC),
      Color(0xFFF1F8E9),
    ];
    return palette[classId.abs() % palette.length];
  }

  List<String> _schoolYearOptions() {
    return schoolYearRangeOptions(startYear: 2020, yearsFromNow: 10);
  }
}

class _AddClassCard extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback onTap;

  const _AddClassCard({
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Card(
          color: const Color(0xFFE0E0E0),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 40, color: Colors.black45),
                SizedBox(height: 8),
                Text(
                  'Add Class',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookCard extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final String schoolYear;
  final String grade;
  final String section;
  final VoidCallback onOpen;

  const _NotebookCard({
    required this.width,
    required this.height,
    required this.color,
    required this.schoolYear,
    required this.grade,
    required this.section,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 18,
            bottom: 18,
            child: Container(
              width: 26,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
          ),
          Positioned.fill(
            left: 18,
            child: Card(
              color: color,
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schoolYear,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Grade $grade',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        section,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
