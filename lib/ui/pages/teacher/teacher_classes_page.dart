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
    final cardWidth = isMobile ? double.infinity : 260.0;
    final cardHeight = isMobile ? 135.0 : 330.0;

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

              if (isMobile) {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    ...classes.map((c) {
                      final classId = c['id'] as int;
                      final grade = c['grade'] as String;
                      final section = c['section'] as String;
                      final sy = c['school_year'] as String;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _NotebookCard(
                          classId: classId,
                          width: cardWidth,
                          height: cardHeight,
                          color: _pastelForClassId(classId),
                          schoolYear: sy,
                          grade: grade,
                          section: section,
                          onOpen: () => _openClass(c),
                          onUpdated: () => setState(() => _reloadTick++),
                        ),
                      );
                    }),
                    _AddClassCard(
                      width: cardWidth,
                      height: cardHeight,
                      onTap: _openAddClass,
                    ),
                  ],
                );
              }

              // ================= DESKTOP GRID =================
              final items = <Widget>[
                ...classes.map((c) {
                  final classId = c['id'] as int;
                  final grade = c['grade'] as String;
                  final section = c['section'] as String;
                  final sy = c['school_year'] as String;
                  return _NotebookCard(
                    classId: classId,
                    width: cardWidth,
                    height: cardHeight,
                    color: _pastelForClassId(classId),
                    schoolYear: sy,
                    grade: grade,
                    section: section,
                    onOpen: () => _openClass(c),
                    onUpdated: () => setState(() => _reloadTick++),
                  );
                }),
                _AddClassCard(
                  width: cardWidth,
                  height: cardHeight,
                  onTap: _openAddClass,
                ),
              ];

              return SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Wrap(
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

class _NotebookCard extends StatefulWidget {
  final int classId;
  final double width;
  final double height;
  final Color color;
  final String schoolYear;
  final String grade;
  final String section;
  final VoidCallback onOpen;
  final VoidCallback? onUpdated;

  const _NotebookCard({
    required this.classId,
    required this.width,
    required this.height,
    required this.color,
    required this.schoolYear,
    required this.grade,
    required this.section,
    required this.onOpen,
    this.onUpdated,
  });

  @override
  State<_NotebookCard> createState() => _NotebookCardState();
}

class _NotebookCardState extends State<_NotebookCard> {
  final _classService = ClassService();
  late TextEditingController _gradeCtrl;
  late TextEditingController _sectionCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _gradeCtrl = TextEditingController(text: 'Kindergarten');
    _sectionCtrl = TextEditingController(text: widget.section);
  }

  @override
  void dispose() {
    _gradeCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  void _enterEditMode() {
    _showEditDialog();
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Edit Class Details',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF272727),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _gradeCtrl,
                enabled: false,
                decoration: InputDecoration(
                  labelText: 'Grade',
                  prefixIcon: const Icon(Icons.school),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _sectionCtrl,
                enabled: !_isSaving,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Section',
                  prefixIcon: const Icon(Icons.group),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : () => _saveEdit(dialogContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.pop(dialogContext),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.maroon,
                  side: const BorderSide(color: AppColors.maroon),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveEdit(BuildContext dialogContext) async {
    final section = _sectionCtrl.text.trim();

    if (section.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Section cannot be empty',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          elevation: 4,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _classService.updateClass(
        classId: widget.classId,
        grade: 'Kindergarten',
        section: section,
      );
      if (!mounted) return;
      Navigator.pop(dialogContext);
      setState(() => _isSaving = false);
      widget.onUpdated?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Class updated successfully',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          elevation: 4,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          elevation: 4,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 10,
            bottom: 10,
            child: Container(
              width: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          Positioned.fill(
            left: 18,
            child: Card(
              color: widget.color,
              child: _buildViewMode(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode() {
    return Stack(
      children: [
        InkWell(
          onTap: widget.onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.schoolYear,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grade ${widget.grade}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.section,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: _enterEditMode,
              color: AppColors.maroon,
              tooltip: 'Edit class details',
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
