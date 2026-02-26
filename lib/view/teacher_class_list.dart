import 'package:flutter/material.dart';
import '../services/assessment_service.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';
import 'teacher_add_learner_profile.dart';
import 'teacher_checklist_page.dart';
import 'teacher_checklist_view_page.dart';
import 'student_information_page.dart';

class ClassListPage extends StatefulWidget {
  final String role;
  final int userId;
  final int classId;
  final String gradeLevel;
  final String section;

  const ClassListPage({
    Key? key,
    required this.role,
    required this.userId,
    required this.classId,
    required this.gradeLevel,
    required this.section,
  }) : super(key: key);

  @override
  State<ClassListPage> createState() => _ClassListPageState();
}

class _ClassListPageState extends State<ClassListPage> {
  static const Color maroonLight = Color(0xFFA02A2A);
  String learnerProgressFilter = "All";

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: isMobile
            ? AppBar(
          title: Text("Class ${widget.gradeLevel} - ${widget.section}"),
          backgroundColor: maroonLight,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: "Active"),
              Tab(text: "Deactivated"),
              Tab(text: "Archived"),
              Tab(text: "Class Summary"),
            ],
          ),
        )
            : null,
        drawer: isMobile
            ? Navbar(
          selectedIndex: 0,
          onItemSelected: (_) {},
          role: widget.role,
          userId: widget.userId,
        )
            : null,
        body: Stack(
          children: [
            SafeArea(
              child: Row(
                children: [
                  if (!isMobile)
                    Navbar(
                      selectedIndex: 0,
                      onItemSelected: (_) {},
                      role: widget.role,
                      userId: widget.userId,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (!isMobile) _desktopHeader(),
                        const Expanded(
                          child: TabBarView(
                            children: [
                              _LearnerTab(
                                  status: DatabaseService.statusActive),
                              _LearnerTab(
                                  status:
                                  DatabaseService.statusDeactivated),
                              _LearnerTab(
                                  status: DatabaseService.statusArchived),
                              _ClassSummaryTab(),
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
        floatingActionButton: widget.role == "Teacher"
            ? FloatingActionButton(
          backgroundColor: maroonLight,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeacherAddLearnerProfilePage(
                  role: widget.role,
                  userId: widget.userId,
                  classId: widget.classId,
                  learnerId: null,
                ),
              ),
            ).then((_) {
              if (mounted) setState(() {});
            });
          },
          child: const Icon(Icons.person_add, color: Colors.white),
        )
            : null,
      ),
    );
  }

  Widget _desktopHeader() {
    return Container(
      color: const Color(0xFFF7F4F6),
      padding: const EdgeInsets.fromLTRB(80, 14, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                "Class ${widget.gradeLevel} - ${widget.section}",
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: learnerProgressFilter,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    labelText: "Learner Status",
                  ),
                  items: const [
                    DropdownMenuItem(value: "All", child: Text("All")),
                    DropdownMenuItem(
                        value: "In Progress",
                        child: Text("In Progress")),
                    DropdownMenuItem(
                        value: "Passed", child: Text("Passed")),
                  ],
                  onChanged: (v) =>
                      setState(() => learnerProgressFilter = v ?? "All"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const TabBar(
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.black54,
            indicatorColor: Colors.black87,
            tabs: [
              Tab(text: "Active"),
              Tab(text: "Deactivated"),
              Tab(text: "Archived"),
              Tab(text: "Class Summary"),
            ],
          ),
        ],
      ),
    );
  }
}

class _LearnerTab extends StatefulWidget {
  final String status;
  const _LearnerTab({required this.status});

  @override
  State<_LearnerTab> createState() => _LearnerTabState();
}

class _LearnerTabState extends State<_LearnerTab> {
  ClassListPage get _page =>
      context.findAncestorWidgetOfExactType<ClassListPage>()!;

  Future<bool> _isPassed(int learnerId) {
    return AssessmentService.hasPostTest(
      learnerId: learnerId,
      classId: _page.classId,
    );
  }

  Future<void> _setLearnerStatus(int learnerId, String status) async {
    await DatabaseService.instance.setLearnerStatus(learnerId, status);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.instance.getLearnersByClassAndStatus(
        page.classId,
        widget.status,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final list = snapshot.data ?? [];
        if (list.isEmpty)
          return Center(child: Text("No learners in ${widget.status}."));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final l = list[i];
            final id = l['learner_id'] as int;
            final name =
                "${l['surname'] ?? ''}, ${l['given_name'] ?? ''}";
            final isActive =
                widget.status == DatabaseService.statusActive;

            return FutureBuilder<bool>(
              future: _isPassed(id),
              builder: (context, passedSnap) {
                final passed = passedSnap.data ?? false;
                final dotColor =
                passed ? Colors.green : Colors.red;

                return ListTile(
                  dense: isMobile,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6 : 12,
                    vertical: isMobile ? 2 : 6,
                  ),
                  leading: Container(
                    width: isMobile ? 7 : 10,
                    height: isMobile ? 7 : 10,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    "LRN: ${l['lrn'] ?? '-'} \n• ${passed ? 'Passed' : 'In Progress'}",
                    style: TextStyle(
                      fontSize: isMobile ? 11.5 : 13,
                    ),
                  ),
                  onTap: isActive
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeacherChecklistPage(
                          role: page.role,
                          userId: page.userId,
                          classId: page.classId,
                          learnerId: id,
                          learnerName: name,
                        ),
                      ),
                    );
                  }
                      : null,
                  trailing: Wrap(
                    spacing: isMobile ? 0 : 8,
                    children: [
                      IconButton(
                        iconSize: isMobile ? 20 : 24,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "View Profile",
                        icon: const Icon(
                            Icons.visibility_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentInfoPage(
                                role: page.role,
                                userId: page.userId,
                                learnerId: id,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        iconSize: isMobile ? 20 : 24,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: "View Checklist",
                        icon: const Icon(
                            Icons.fact_check_outlined),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TeacherChecklistViewPage(
                                    role: page.role,
                                    userId: page.userId,
                                    classId: page.classId,
                                    learnerId: id,
                                    learnerName: name,
                                  ),
                            ),
                          );
                        },
                      ),
                      if (isActive) ...[
                        IconButton(
                          iconSize: isMobile ? 20 : 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                              Icons.pause_circle_outline),
                          onPressed: () =>
                              _setLearnerStatus(
                                  id,
                                  DatabaseService
                                      .statusDeactivated),
                        ),
                        IconButton(
                          iconSize: isMobile ? 20 : 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon:
                          const Icon(Icons.archive_outlined),
                          onPressed: () =>
                              _setLearnerStatus(
                                  id,
                                  DatabaseService.statusArchived),
                        ),
                      ] else ...[
                        IconButton(
                          iconSize: isMobile ? 20 : 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                              Icons.play_circle_outline),
                          onPressed: () =>
                              _setLearnerStatus(
                                  id,
                                  DatabaseService.statusActive),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ClassSummaryTab extends StatelessWidget {
  const _ClassSummaryTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Class Summary"));
  }
}