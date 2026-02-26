import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';

class StudentInfoPage extends StatefulWidget {
  final String role;
  final int userId;
  final int learnerId;

  const StudentInfoPage({
    Key? key,
    required this.role,
    required this.userId,
    required this.learnerId,
  }) : super(key: key);

  @override
  State<StudentInfoPage> createState() => _StudentInfoPageState();
}

class _StudentInfoPageState extends State<StudentInfoPage> {
  bool loading = true;
  bool editMode = false;

  final Map<String, TextEditingController> c = {};
  TextEditingController _ctrl(String key) =>
      c.putIfAbsent(key, () => TextEditingController());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = await DatabaseService.instance.getDatabase();
    final rows = await db.query(
      'learner_information_table',
      where: 'learner_id=?',
      whereArgs: [widget.learnerId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final row = rows.first;
      row.forEach((key, value) {
        _ctrl(key).text = value?.toString() ?? "";
      });
    }

    setState(() => loading = false);
  }

  Future<void> _save() async {
    final db = await DatabaseService.instance.getDatabase();
    final data = <String, dynamic>{};
    c.forEach((k, v) => data[k] = v.text);

    await db.update("learner_information_table", data,
        where: "learner_id=?", whereArgs: [widget.learnerId]);

    setState(() => editMode = false);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Student profile updated")));
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
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
                      isMobile ? _mobileHeader() : _desktopHeader(),
                      Expanded(
                        child: loading
                            ? const Center(
                            child: CircularProgressIndicator())
                            : _formWrapper(isMobile),
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
              child: Text(
                "Student Profile",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
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


          Positioned(
            right: 12,
            top: 6,
            bottom: 6,
            child: IconButton(
              tooltip: editMode ? "Save Changes" : "Edit Profile",
              icon: Icon(editMode ? Icons.save : Icons.edit),
              onPressed: editMode ? _save : () => setState(() => editMode = true),
            ),
          ),
        ],
      ),
    );
  }


  Widget _desktopHeader() {
    return Container(
      color: const Color(0xFFF7F4F6),
      padding: const EdgeInsets.fromLTRB(80, 14, 16, 10),
      child: Row(
        children: [
          const Text("Student Profile",
              style:
              TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          const Spacer(),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA02A2A),
              padding:
              const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            ),
            onPressed:
            editMode ? _save : () => setState(() => editMode = true),
            child: Text(editMode ? "Save Changes" : "Edit Profile",
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }


  Widget _formWrapper(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 40),
      child: Center(
        child: SizedBox(
          width: isMobile ? double.infinity : 700,
          child: editMode
              ? _editLayout(isMobile)
              : _viewLayout(isMobile),
        ),
      ),
    );
  }

  // ================= VIEW MODE =================
  Widget _displayField(
      String label, String key, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: isMobile ? 14 : 18,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
                horizontal: 12, vertical: isMobile ? 12 : 18),
            decoration: BoxDecoration(
              color: const Color(0xFFE3E3E3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _ctrl(key).text.isEmpty ? "—" : _ctrl(key).text,
              style: TextStyle(fontSize: isMobile ? 14 : 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewLayout(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Student Information",
            style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),

        _displayField("Surname", "surname", isMobile),
        _displayField("First Name", "given_name", isMobile),
        _displayField("Middle Name", "middle_name", isMobile),
        _displayField("Sex", "sex", isMobile),
        _displayField("Date of Birth", "birthday", isMobile),
        _displayField("LRN", "lrn", isMobile),
        _displayField("Handedness", "handedness", isMobile),
        _displayField("Birth Order", "birth_order", isMobile),
        _displayField("Number of Siblings", "number_of_siblings", isMobile),

        const SizedBox(height: 24),

        Text("Address Information",
            style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),

        _displayField("Province", "province", isMobile),
        _displayField("City", "city", isMobile),
        _displayField("Barangay", "barangay", isMobile),

        const SizedBox(height: 24),

        Text("Parent Information",
            style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),

        _displayField("Parent Name", "parent_name", isMobile),
        _displayField("Parent Occupation", "parent_occupation",
            isMobile),
        _displayField(
            "Mother Age at Birth", "age_mother_at_birth", isMobile),
        _displayField(
            "Spouse Occupation", "spouse_occupation", isMobile),
      ],
    );
  }

  // ================= EDIT MODE =================
  Widget _editLayout(bool isMobile) {
    Widget field(String label, String key) => Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 10 : 12),
      child: TextField(
        controller: _ctrl(key),
        style: TextStyle(fontSize: isMobile ? 14 : 17),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
          TextStyle(fontSize: isMobile ? 14 : 18),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Student Information",
            style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        field("Surname*", "surname"),
        field("First Name*", "given_name"),
        field("Middle Name*", "middle_name"),
        field("Sex*", "sex"),
        field("Date of Birth*", "birthday"),
        field("LRN*", "lrn"),
        field("Handedness*", "handedness"),
        field("Birth Order*", "birth_order"),
        field("Number of Siblings*", "number_of_siblings"),

        const SizedBox(height: 16),

        Text("Address Information",
            style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        field("Province*", "province"),
        field("City*", "city"),
        field("Barangay*", "barangay"),

        const SizedBox(height: 16),

        Text("Parent / Guardian Information",
            style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        field("Parent Name*", "parent_name"),
        field("Parent Occupation*", "parent_occupation"),
        field("Mother's Age at Birth*", "age_mother_at_birth"),
        field("Spouse Occupation*", "spouse_occupation"),
      ],
    );
  }
}