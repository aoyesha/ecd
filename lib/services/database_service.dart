import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._constructor();
  static Database? _database;

  DatabaseService._constructor();

  // Tables
  static const teacherTable = "teacher_table";
  static const adminTable = "admin_table";
  static const classTable = "class_table";
  static const learnerTable = "learner_information_table";
  static const assessmentHeaderTable = "assessment_header";
  static const assessmentResultsTable = "assessment_results";
  static const learnerEcdTable = "learner_ecd_table";

  // Status values
  static const statusActive = "active";
  static const statusDeactivated = "deactivated";
  static const statusArchived = "archived";

  Future<Database> getDatabase() async {
    if (_database != null) return _database!;

    final dbPath = join(await getDatabasesPath(), "eccd_db.db");

    _database = await openDatabase(
      dbPath,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _database!;
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration: Add recovery columns to Teacher and Admin tables if moving from v1 to v2
    if (oldVersion < 2) {
      // SQLite requires separate ALTER TABLE statements for each new column
      final List<String> columnsToAdd = [
        "recovery_q1",
        "recovery_a1",
        "recovery_q2",
        "recovery_a2"
      ];

      for (var column in columnsToAdd) {
        await db.execute("ALTER TABLE $teacherTable ADD COLUMN $column TEXT;");
        await db.execute("ALTER TABLE $adminTable ADD COLUMN $column TEXT;");
      }
    }

    // Non-destructive: ensure assessment tables exist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS assessment_header (
        assessment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        learner_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        assessment_type TEXT NOT NULL,
        date_taken TEXT NOT NULL,
        age_as_of_assessment REAL,
        FOREIGN KEY (learner_id) REFERENCES learner_information_table(learner_id),
        FOREIGN KEY (class_id) REFERENCES class_table(class_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS assessment_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER NOT NULL,
        domain TEXT NOT NULL,
        question_index INTEGER NOT NULL,
        answer INTEGER NOT NULL,
        FOREIGN KEY (assessment_id) REFERENCES assessment_header(assessment_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS learner_ecd_table (
        learner_ecd_id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER,
        gmd_total INTEGER, gmd_ss INTEGER, gmd_interpretation TEXT,
        fms_total INTEGER, fms_ss INTEGER, fms_interpretation TEXT,
        shd_total INTEGER, shd_ss INTEGER, shd_interpretation TEXT,
        rl_total INTEGER, rl_ss INTEGER, rl_interpretation TEXT,
        el_total INTEGER, el_ss INTEGER, el_interpretation TEXT,
        cd_total INTEGER, cd_ss INTEGER, cd_interpretation TEXT,
        sed_total INTEGER, sed_ss INTEGER, sed_interpretation TEXT,
        raw_score INTEGER, summary_scaled_score INTEGER,
        standard_score INTEGER, interpretation TEXT,
        FOREIGN KEY (assessment_id) REFERENCES assessment_header(assessment_id)
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    // ------------------ TEACHER ------------------
    await db.execute('''
      CREATE TABLE $teacherTable (
        teacher_id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacher_name TEXT,
        class_id INTEGER,
        email TEXT,
        password TEXT,
        school TEXT,
        district TEXT,
        division TEXT,
        region TEXT,
        recovery_q1 TEXT,
        recovery_a1 TEXT,
        recovery_q2 TEXT,
        recovery_a2 TEXT,
        status TEXT
      )
    ''');

    // ------------------ ADMIN ------------------
    await db.execute('''
      CREATE TABLE $adminTable (
        admin_id INTEGER PRIMARY KEY AUTOINCREMENT,
        admin_name TEXT,
        email TEXT,
        password TEXT,
        school TEXT,
        district TEXT,
        division TEXT,
        region TEXT,
        recovery_q1 TEXT,
        recovery_a1 TEXT,
        recovery_q2 TEXT,
        recovery_a2 TEXT,
        status TEXT
      )
    ''');

    // ------------------ CLASS ------------------
    await db.execute('''
      CREATE TABLE $classTable (
        class_id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_level TEXT,
        class_section TEXT,
        start_school_year TEXT,
        end_school_year TEXT,
        status TEXT,
        teacher_id INTEGER
      )
    ''');

    // ------------------ LEARNER ------------------
    await db.execute('''
      CREATE TABLE $learnerTable (
        learner_id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER,
        surname TEXT,
        given_name TEXT,
        middle_name TEXT,
        sex TEXT,
        lrn INTEGER UNIQUE,
        birthday TEXT,
        handedness TEXT,
        birth_order TEXT,
        barangay TEXT,
        city TEXT,
        province TEXT,
        parent_name TEXT,
        parent_occupation TEXT,
        age_mother_at_birth INTEGER,
        spouse_occupation TEXT,
        number_of_siblings INTEGER,
        status TEXT
      )
    ''');

    // ------------------ ASSESSMENT HEADER ------------------
    await db.execute('''
      CREATE TABLE assessment_header (
        assessment_id INTEGER PRIMARY KEY AUTOINCREMENT,
        learner_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL,
        assessment_type TEXT NOT NULL,
        date_taken TEXT NOT NULL,
        age_as_of_assessment REAL,
        FOREIGN KEY (learner_id) REFERENCES learner_information_table(learner_id),
        FOREIGN KEY (class_id) REFERENCES class_table(class_id)
      )
    ''');

    // ------------------ ASSESSMENT RESULTS ------------------
    await db.execute('''
      CREATE TABLE assessment_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER NOT NULL,
        domain TEXT NOT NULL,
        question_index INTEGER NOT NULL,
        answer INTEGER NOT NULL,
        FOREIGN KEY (assessment_id) REFERENCES assessment_header(assessment_id)
      )
    ''');

    // ------------------ ECCD COMPUTED SUMMARY ------------------
    await db.execute('''
      CREATE TABLE learner_ecd_table (
        learner_ecd_id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER,
        gmd_total INTEGER, gmd_ss INTEGER, gmd_interpretation TEXT,
        fms_total INTEGER, fms_ss INTEGER, fms_interpretation TEXT,
        shd_total INTEGER, shd_ss INTEGER, shd_interpretation TEXT,
        rl_total INTEGER, rl_ss INTEGER, rl_interpretation TEXT,
        el_total INTEGER, el_ss INTEGER, el_interpretation TEXT,
        cd_total INTEGER, cd_ss INTEGER, cd_interpretation TEXT,
        sed_total INTEGER, sed_ss INTEGER, sed_interpretation TEXT,
        raw_score INTEGER, summary_scaled_score INTEGER,
        standard_score INTEGER, interpretation TEXT,
        FOREIGN KEY (assessment_id) REFERENCES assessment_header(assessment_id)
      )
    ''');
  }

  // ================== CREATE ==================
  Future<int> createTeacher(Map<String, dynamic> data) async {
    final db = await getDatabase();
    return db.insert(teacherTable, data);
  }

  Future<int> createAdmin(Map<String, dynamic> data) async {
    final db = await getDatabase();
    return db.insert(adminTable, data);
  }

  Future<int> createClass(Map<String, dynamic> data) async {
    final db = await getDatabase();
    return db.insert(classTable, data);
  }

  Future<int> createLearner(Map<String, dynamic> data) async {
    final db = await getDatabase();
    return db.insert(learnerTable, data);
  }

  // ================== AUTH LOOKUPS ==================
  Future<Map<String, dynamic>?> findTeacherByEmail(String email) async {
    final db = await getDatabase();
    final rows = await db.query(
      teacherTable,
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> findAdminByEmail(String email) async {
    final db = await getDatabase();
    final rows = await db.query(
      adminTable,
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> getAllTeachers() async {
    final db = await getDatabase();
    return db.query(teacherTable, orderBy: 'teacher_id DESC');
  }

  Future<List<Map<String, dynamic>>> getAllAdmins() async {
    final db = await getDatabase();
    return db.query(adminTable, orderBy: 'admin_id DESC');
  }

  // ================== CLASSES ==================
  Future<List<Map<String, dynamic>>> getClassesByTeacherAndStatus(
      int teacherId,
      String status,
      ) async {
    final db = await getDatabase();
    return db.query(
      classTable,
      where: 'teacher_id = ? AND status = ?',
      whereArgs: [teacherId, status],
      orderBy: 'class_id DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getActiveClassesByTeacher(int teacherId) async {
    return getClassesByTeacherAndStatus(teacherId, statusActive);
  }

  Future<List<Map<String, dynamic>>> getDeactivatedClassesByTeacher(int teacherId) async {
    return getClassesByTeacherAndStatus(teacherId, statusDeactivated);
  }

  Future<List<Map<String, dynamic>>> getArchivedClassesByTeacher(int teacherId) async {
    return getClassesByTeacherAndStatus(teacherId, statusArchived);
  }

  Future<void> setClassStatus(int classId, String status) async {
    final db = await getDatabase();
    await db.update(
      classTable,
      {'status': status},
      where: 'class_id = ?',
      whereArgs: [classId],
    );
  }

  Future<void> setAllLearnersStatusForClass(int classId, String status) async {
    final db = await getDatabase();
    await db.update(
      learnerTable,
      {'status': status},
      where: 'class_id = ?',
      whereArgs: [classId],
    );
  }

  // ================== LEARNERS ==================
  Future<List<Map<String, dynamic>>> getLearnersByClass(int classId) async {
    final db = await getDatabase();
    return db.query(
      learnerTable,
      where: 'class_id = ? AND status = ?',
      whereArgs: [classId, 'active'],
      orderBy: 'surname ASC, given_name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getLearnersByClassAndStatus(
      int classId,
      String status,
      ) async {
    final db = await getDatabase();
    return db.query(
      learnerTable,
      where: 'class_id = ? AND status = ?',
      whereArgs: [classId, status],
      orderBy: 'surname ASC, given_name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getActiveLearnersByClass(int classId) async {
    return getLearnersByClassAndStatus(classId, statusActive);
  }

  Future<List<Map<String, dynamic>>> getDeactivatedLearnersByClass(int classId) async {
    return getLearnersByClassAndStatus(classId, statusDeactivated);
  }

  Future<List<Map<String, dynamic>>> getArchivedLearnersByClass(int classId) async {
    return getLearnersByClassAndStatus(classId, statusArchived);
  }

  Future<void> setLearnerStatus(int learnerId, String status) async {
    final db = await getDatabase();
    await db.update(
      learnerTable,
      {'status': status},
      where: 'learner_id = ?',
      whereArgs: [learnerId],
    );
  }

  // ================== PASSWORD UPDATE ==================
  Future<void> updatePassword({
    required String role,
    required String email,
    required String newPassword,
  }) async {
    final db = await getDatabase();

    if (role == 'Teacher') {
      await db.update(
        teacherTable,
        {'password': newPassword},
        where: 'email = ?',
        whereArgs: [email],
      );
    } else {
      await db.update(
        adminTable,
        {'password': newPassword},
        where: 'email = ?',
        whereArgs: [email],
      );
    }
  }

  Future<Map<String, dynamic>?> getTeacherById(int teacherId) async {
    final db = await getDatabase();
    final rows = await db.query(
      teacherTable,
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>?> getAdminById(int adminId) async {
    final db = await getDatabase();
    final rows = await db.query(
      adminTable,
      where: 'admin_id = ?',
      whereArgs: [adminId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }
}