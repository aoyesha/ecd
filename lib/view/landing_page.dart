import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';
import 'teacher_new_data_source.dart';
import 'teacher_class_list.dart';
import 'my_summary_page.dart';

class AppColors {
  static const Color bg = Color(0xFFF7F4F6);
}

class LandingPage extends StatefulWidget {
  final int userId;
  final String role;

  const LandingPage({Key? key, required this.userId, required this.role}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Map<String, dynamic>> _activeClasses = [];
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.role == 'Teacher') {
      final rows = await DatabaseService.instance.getActiveClassesByTeacher(widget.userId);
      if (mounted) setState(() => _activeClasses = rows);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: isMobile
          ? Navbar(selectedIndex: 0, onItemSelected: (_) {}, userId: widget.userId, role: widget.role)
          : null,
      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
                if (!isMobile)
                  Navbar(selectedIndex: 0, onItemSelected: (_) {}, userId: widget.userId, role: widget.role),

                Expanded(
                  child: Column(
                    children: [
                      _topBar(isMobile),
                      _toggleSection(isMobile),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : TabBarView(
                          controller: _tab,
                          children: [
                            _teacherDashboard(isMobile),
                            MySummaryPage(userId: widget.userId, role: widget.role, embedded: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 285,
              child: const NavbarBackButton(),
            ),
        ],
      ),
    );
  }

  Widget _topBar(bool isMobile) {
    if (!isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: const Column(children: [
          Text('Early Childhood Development Checklist',
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
          SizedBox(height: 14),
        ]),
      );
    }

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            left: 64,
            right: 64,
            child: Center(
              child: Text('Early Childhood Development Checklist',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ),
          ),
          Positioned(
            left: 12,
            top: 6,
            bottom: 6,
            child: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState!.openDrawer()),
          ),
        ],
      ),
    );
  }

  Widget _toggleSection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
      child: ToggleButtons(
        constraints: BoxConstraints(minHeight: isMobile ? 36 : 48, minWidth: isMobile ? 110 : 160),
        borderRadius: BorderRadius.circular(8),
        borderWidth: 1.5,
        selectedBorderColor: Colors.black,
        borderColor: Colors.black26,
        selectedColor: Colors.white,
        fillColor: Colors.black,
        color: Colors.black87,
        isSelected: [_tab.index == 0, _tab.index == 1],
        onPressed: (i) => setState(() => _tab.animateTo(i)),
        children: const [
          Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("My Classes")),
          Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("My Summary")),
        ],
      ),
    );
  }

  Widget _teacherDashboard(bool isMobile) {
    final cardWidth = isMobile ? 170.0 : 260.0;
    final cardHeight = isMobile ? 190.0 : 330.0;

    final items = [
      ..._activeClasses.map((c) => _NotebookCard(
        width: cardWidth,
        height: cardHeight,
        color: _pastelForClassId(c['class_id']),
        schoolYear: '${c['start_school_year']}-${c['end_school_year']}',
        grade: '${c['class_level']}',
        section: '${c['class_section']}',
        onOpen: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClassListPage(
                userId: widget.userId,
                role: widget.role,
                classId: c['class_id'],
                gradeLevel: c['class_level'],
                section: c['class_section'],
              ),
            ),
          );
        },
      )),
      _AddClassCard(
        width: cardWidth,
        height: cardHeight,
        userId: widget.userId,
        role: widget.role,
      ),
    ];

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 16, runSpacing: 16, children: items),
      );
    }

    const gap = 24.0;
    final totalWidth =
        (items.length * cardWidth) + ((items.length - 1) * gap);

    return SingleChildScrollView(
      child: Center(
        child: SizedBox(
          width: totalWidth,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: items,
          ),
        ),
      ),
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
}

class _AddClassCard extends StatelessWidget {
  final double width, height;
  final int userId;
  final String role;

  const _AddClassCard({
    required this.width,
    required this.height,
    required this.userId,
    required this.role,
  });

  static const double _spineOffset = 18; // MUST MATCH NOTEBOOK OVERLAP

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(left: _spineOffset),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TeacherNewDataSourcePage(role: role, userId: userId),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black12),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, size: 40, color: Colors.black26),
                SizedBox(height: 12),
                Text('New Class',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookCard extends StatelessWidget {
  final double width, height;
  final Color color;
  final String schoolYear, grade, section;
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

  static const double _radius = 22;
  static const double _spineWidth = 26;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [

          /// SPINE (now INSIDE width, no negative offsets)
          Positioned(
            left: 6,
            top: 18,
            bottom: 18,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(_radius),
                bottomLeft: Radius.circular(_radius),
              ),
              child: Container(
                width: _spineWidth,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1E1E),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      offset: Offset(3, 0),
                      color: Colors.black26,
                    )
                  ],
                ),
              ),
            ),
          ),

          /// COVER (shifted RIGHT by spine width)
          Positioned.fill(
            left: _spineWidth - 8, // overlap nicely but keep width honest
            child: Card(
              color: color,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_radius),
              ),
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(_radius),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schoolYear,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        grade,
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