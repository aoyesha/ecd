import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';
import 'teacher_class_list.dart';

class AppColors {
  static const Color maroon = Color(0xFF7A1E22);
  static const Color bg = Color(0xFFF7F4F6);
}

class ArchivePage extends StatefulWidget {
  final String role;
  final int userId;

  const ArchivePage({Key? key, required this.role, required this.userId})
      : super(key: key);

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage>
    with TickerProviderStateMixin {
  late final TabController _topTab;
  late final TabController _classTab;
  late final TabController _learnerTab;

  @override
  void initState() {
    super.initState();
    _topTab = TabController(length: 2, vsync: this);
    _classTab = TabController(length: 3, vsync: this);
    _learnerTab = TabController(length: 3, vsync: this);
    _topTab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _topTab.dispose();
    _classTab.dispose();
    _learnerTab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: isMobile
          ? Navbar(
        selectedIndex: 1,
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
                    selectedIndex: 1,
                    onItemSelected: (_) {},
                    role: widget.role,
                    userId: widget.userId,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      if (isMobile) _mobileHeader(),
                      if (isMobile) _mobileTopToggle(),
                      if (!isMobile) _desktopHeader(),
                      Expanded(
                        child: TabBarView(
                          controller: _topTab,
                          children: [
                            _classesPane(isMobile),
                            _learnersPane(isMobile),
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

  // MOBILE HEADER
  Widget _mobileHeader() {
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
              child: Text("My Archive",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            ),
          ),
          Positioned(
            left: 12,
            top: 6,
            bottom: 6,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileTopToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ToggleButtons(
        constraints: const BoxConstraints(minHeight: 36, minWidth: 120),
        borderRadius: BorderRadius.circular(8),
        borderWidth: 1.5,
        selectedBorderColor: Colors.black,
        borderColor: Colors.black26,
        selectedColor: Colors.white,
        fillColor: Colors.black,
        color: Colors.black87,
        isSelected: [_topTab.index == 0, _topTab.index == 1],
        onPressed: (i) => setState(() => _topTab.animateTo(i)),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text("Classes"),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text("Learners"),
          ),
        ],
      ),
    );
  }

  // DESKTOP HEADER (unchanged)
  Widget _desktopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Column(
        children: [
          const Text("My Archive",
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          ToggleButtons(
            borderRadius: BorderRadius.circular(10),
            borderWidth: 1.8,
            selectedBorderColor: Colors.black,
            borderColor: Colors.black26,
            selectedColor: Colors.white,
            fillColor: Colors.black,
            color: Colors.black87,
            isSelected: [_topTab.index == 0, _topTab.index == 1],
            onPressed: (i) => setState(() => _topTab.animateTo(i)),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                child: Text("Classes"),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                child: Text("Learners"),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  // CLASSES
  Widget _classesPane(bool isMobile) {
    return Column(
      children: [
        _subTabBar(_classTab, isMobile),
        Expanded(
          child: TabBarView(
            controller: _classTab,
            children: [
              _classList(DatabaseService.statusActive, isMobile),
              _classList(DatabaseService.statusDeactivated, isMobile),
              _classList(DatabaseService.statusArchived, isMobile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _classList(String status, bool isMobile) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.instance
          .getClassesByTeacherAndStatus(widget.userId, status),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return Center(child: Text("No classes in $status"));

        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final c = list[i];
            return Card(
              child: ListTile(
                dense: isMobile,
                leading: const Icon(Icons.class_outlined),
                title: Text("${c['class_level']} - ${c['class_section']}"),
                subtitle: Text("SY ${c['start_school_year']}-${c['end_school_year']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.restore, color: Colors.green),
                  onPressed: () async {
                    await DatabaseService.instance.setClassStatus(
                        c['class_id'], DatabaseService.statusActive);
                    setState(() {});
                  },
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassListPage(
                      role: widget.role,
                      userId: widget.userId,
                      classId: c['class_id'],
                      gradeLevel: c['class_level'],
                      section: c['class_section'],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // LEARNERS
  Widget _learnersPane(bool isMobile) {
    return Column(
      children: [
        _subTabBar(_learnerTab, isMobile),
        Expanded(
          child: TabBarView(
            controller: _learnerTab,
            children: [
              _learnerList(DatabaseService.statusActive, isMobile),
              _learnerList(DatabaseService.statusDeactivated, isMobile),
              _learnerList(DatabaseService.statusArchived, isMobile),
            ],
          ),
        ),
      ],
    );
  }

  Widget _learnerList(String status, bool isMobile) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.instance.getDatabase().then(
            (db) => db.query(DatabaseService.learnerTable,
            where: 'status=?', whereArgs: [status]),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final list = snapshot.data!;
        if (list.isEmpty) return Center(child: Text("No learners in $status"));

        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final l = list[i];
            return Card(
              child: ListTile(
                dense: isMobile,
                leading: const Icon(Icons.person_outline),
                title: Text("${l['surname']}, ${l['given_name']}"),
                subtitle: Text("LRN: ${l['lrn']}"),
                trailing: IconButton(
                  icon: const Icon(Icons.restore, color: Colors.green),
                  onPressed: () async {
                    await DatabaseService.instance.setLearnerStatus(
                        l['learner_id'], DatabaseService.statusActive);
                    setState(() {});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _subTabBar(TabController controller, bool isMobile) {
    return Center(
      child: SizedBox(
        width: isMobile ? double.infinity : 420,
        child: TabBar(
          controller: controller,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: const [
            Tab(text: "Active"),
            Tab(text: "Deactivated"),
            Tab(text: "Archived"),
          ],
        ),
      ),
    );
  }
}