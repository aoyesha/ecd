import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';
import 'teacher_class_list.dart';
import 'my_summary_page.dart';

class AppColors {
  static const Color bg = Color(0xFFF7F4F6);
}

class AdminLandingPage extends StatefulWidget {
  final int userId;
  final String role;

  const AdminLandingPage({
    Key? key,
    required this.userId,
    required this.role,
  }) : super(key: key);

  @override
  State<AdminLandingPage> createState() => _AdminLandingPageState();
}

class _AdminLandingPageState extends State<AdminLandingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Map<String, dynamic>> _activeDataSources = [];
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    final rows =
    await DatabaseService.instance.getAllActiveDataSources();
    if (mounted) {
      setState(() {
        _activeDataSources = rows;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bg,
      drawer: isMobile
          ? Navbar(
        selectedIndex: 0,
        onItemSelected: (_) {},
        userId: widget.userId,
        role: widget.role,
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
                    userId: widget.userId,
                    role: widget.role,
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(isMobile),
                      _toggleSection(isMobile),
                      Expanded(
                        child: _isLoading
                            ? const Center(
                            child: CircularProgressIndicator())
                            : TabBarView(
                          controller: _tab,
                          children: [
                            _adminDashboard(isMobile),
                            MySummaryPage(
                              userId: widget.userId,
                              role: widget.role,
                              embedded: true,
                            ),
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

  // ================= TOP BAR =================
  Widget _topBar(bool isMobile) {
    if (!isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.black12),
          ),
        ),
        child: const Column(
          children: [
            Text(
              'Early Childhood Development Checklist',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 14),
          ],
        ),
      );
    }

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black12),
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            left: 64,
            right: 64,
            child: Center(
              child: Text(
                'Early Childhood Development Checklist',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 6,
            bottom: 6,
            child: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () =>
                  _scaffoldKey.currentState!.openDrawer(),
            ),
          ),
        ],
      ),
    );
  }

  // ================= TOGGLE =================
  Widget _toggleSection(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 8 : 12),
      child: ToggleButtons(
        constraints: BoxConstraints(
          minHeight: isMobile ? 36 : 48,
          minWidth: isMobile ? 110 : 160,
        ),
        borderRadius: BorderRadius.circular(8),
        borderWidth: 1.5,
        selectedBorderColor: Colors.black,
        borderColor: Colors.black26,
        selectedColor: Colors.white,
        fillColor: Colors.black,
        color: Colors.black87,
        isSelected: [_tab.index == 0, _tab.index == 1],
        onPressed: (i) =>
            setState(() => _tab.animateTo(i)),
        children: const [
          Padding(
            padding:
            EdgeInsets.symmetric(horizontal: 10),
            child: Text("Data Sources"),
          ),
          Padding(
            padding:
            EdgeInsets.symmetric(horizontal: 10),
            child: Text("Summary"),
          ),
        ],
      ),
    );
  }

  // ================= DASHBOARD =================
  Widget _adminDashboard(bool isMobile) {
    final cardWidth =
    isMobile ? 170.0 : 330.0;
    final cardHeight =
    isMobile ? 190.0 : 400.0;

    final items = [
      ..._activeDataSources.map(
            (c) => _AdminNotebookCard(
          width: cardWidth,
          height: cardHeight,
          color:
          _pastelForClassId(c['class_id']),
          schoolYear:
          '${c['start_school_year']} - ${c['end_school_year']}',
          onOpen: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassListPage(
                  userId: widget.userId,
                  role: widget.role,
                  classId: c['class_id'],
                  gradeLevel:
                  c['class_level'],
                  section:
                  c['class_section'],
                ),
              ),
            );
          },
        ),
      ),
    ];

    if (isMobile) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items,
        ),
      );
    }

    final desktopCount =
    items.length.clamp(1, 4);
    const cardW = 340.0;
    const gap = 6.0;

    final gridWidth =
        (desktopCount * cardW) +
            ((desktopCount - 1) * gap);

    return SingleChildScrollView(
      child: Center(
        child: SizedBox(
          width: gridWidth,
          child: GridView.builder(
            shrinkWrap: true,
            physics:
            const NeverScrollableScrollPhysics(),
            padding:
            const EdgeInsets.symmetric(
                vertical: 24),
            itemCount: items.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 6,
              mainAxisSpacing: 8,
              childAspectRatio:
              330 / 400,
            ),
            itemBuilder: (_, i) =>
            items[i],
          ),
        ),
      ),
    );
  }

  Color _pastelForClassId(int id) {
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
    return palette[id.abs() %
        palette.length];
  }
}

// ================= NOTEBOOK CARD =================
class _AdminNotebookCard
    extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final String schoolYear;
  final VoidCallback onOpen;

  const _AdminNotebookCard({
    required this.width,
    required this.height,
    required this.color,
    required this.schoolYear,
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
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 28,
              decoration:
              const BoxDecoration(
                color:
                Color(0xFF1E1E1E),
                borderRadius:
                BorderRadius.only(
                  topLeft:
                  Radius.circular(
                      14),
                  bottomLeft:
                  Radius.circular(
                      14),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    offset:
                    Offset(3, 0),
                    color:
                    Colors.black26,
                  )
                ],
              ),
            ),
          ),
          Card(
            color: color,
            elevation: 8,
            margin:
            const EdgeInsets.only(
                left: 22),
            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius
                  .circular(
                  22),
            ),
            child: InkWell(
              onTap: onOpen,
              borderRadius:
              BorderRadius
                  .circular(
                  22),
              child: Center(
                child: Text(
                  schoolYear,
                  textAlign:
                  TextAlign.center,
                  style:
                  const TextStyle(
                    fontSize: 30,
                    fontWeight:
                    FontWeight
                        .w900,
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