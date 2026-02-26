import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';
import 'teacher_class_list.dart';

class AppColors {
  static const Color bg = Color(0xFFF7F4F6);
}

class AdminArchivePage extends StatefulWidget {
  final String role;
  final int userId;

  const AdminArchivePage({
    Key? key,
    required this.role,
    required this.userId,
  }) : super(key: key);

  @override
  State<AdminArchivePage> createState() => _AdminArchivePageState();
}

class _AdminArchivePageState extends State<AdminArchivePage>
    with TickerProviderStateMixin {
  late final TabController _dataSourceTab;

  @override
  void initState() {
    super.initState();
    _dataSourceTab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _dataSourceTab.dispose();
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
                      if (!isMobile) _desktopHeader(),
                      _subTabBar(_dataSourceTab, isMobile),
                      Expanded(
                        child: TabBarView(
                          controller: _dataSourceTab,
                          children: [
                            _dataSourceList(DatabaseService.statusActive, isMobile),
                            _dataSourceList(DatabaseService.statusDeactivated, isMobile),
                            _dataSourceList(DatabaseService.statusArchived, isMobile),
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

  // HEADERS
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
              child: Text("Data Source Archive",
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

  Widget _desktopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: const Column(
        children: [
          Text("Data Source Archive",
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900)),
          SizedBox(height: 18),
        ],
      ),
    );
  }

  // DATA SOURCE LIST
  Widget _dataSourceList(String status, bool isMobile) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseService.instance.getAllDataSourcesByStatus(status),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final list = snapshot.data!;
        if (list.isEmpty) return Center(child: Text("No data sources in $status"));

        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 12 : 24),
          itemCount: list.length,
          itemBuilder: (_, i) {
            final c = list[i];
            return Card(
              child: ListTile(
                dense: isMobile,
                leading: const Icon(Icons.storage_outlined),
                title: Text("${c['class_level']}"),
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
                      section: '',
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