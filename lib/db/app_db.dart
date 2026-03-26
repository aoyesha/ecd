import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'schema.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  late Database db;

  Future<void> init() async {
    final basePath = await getDatabasesPath();
    final dbPath = p.join(basePath, 'eccd_new.db');

    db = await openDatabase(
      dbPath,
      version: DbSchema.dbVersion,
      onCreate: (db, version) async => _createAll(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _upgradeToV2(db);
        }
        if (oldVersion < 3) {
          await _upgradeToV3(db);
        }
        if (oldVersion < 4) {
          await _upgradeToV4(db);
        }
        if (oldVersion < 5) {
          await _upgradeToV5(db);
        }
        if (oldVersion < 6) {
          await _upgradeToV6(db);
        }
        if (oldVersion < 7) {
          await _upgradeToV7(db);
        }
        if (oldVersion < 8) {
          await _upgradeToV8(db);
        }
        if (oldVersion < 9) {
          await _upgradeToV9(db);
        }
        if (oldVersion < 10) {
          await _upgradeToV10(db);
        }
        if (oldVersion < 11) {
          await _upgradeToV11(db);
        }
      },
    );
  }

  Future<void> _createAll(Database db) async {
    await db.execute('''
CREATE TABLE ${DbSchema.tUsers} (
  ${DbSchema.cUserId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cUserEmail} TEXT NOT NULL,
  ${DbSchema.cUserPasswordHash} TEXT NOT NULL,
  ${DbSchema.cUserRole} TEXT NOT NULL,
  ${DbSchema.cUserName} TEXT NOT NULL DEFAULT '',
  ${DbSchema.cUserAcceptedTos} INTEGER NOT NULL DEFAULT 0,
  ${DbSchema.cUserAcceptedPrivacy} INTEGER NOT NULL DEFAULT 0,
  ${DbSchema.cUserSchool} TEXT,
  ${DbSchema.cUserDistrict} TEXT,
  ${DbSchema.cUserDivision} TEXT,
  ${DbSchema.cUserRegion} TEXT,
  ${DbSchema.cUserCreatedAt} TEXT NOT NULL,
  ${DbSchema.cUserLastMonthlyOtpAt} TEXT,
  UNIQUE(${DbSchema.cUserEmail}, ${DbSchema.cUserRole})
)
''');

    await db.execute('''
CREATE TABLE ${DbSchema.tClasses} (
  ${DbSchema.cClassId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cClassTeacherId} INTEGER NOT NULL,
  ${DbSchema.cClassGrade} TEXT NOT NULL,
  ${DbSchema.cClassSection} TEXT NOT NULL,
  ${DbSchema.cClassSchoolYear} TEXT NOT NULL,
  ${DbSchema.cClassStatus} TEXT NOT NULL,
  ${DbSchema.cClassCreatedAt} TEXT NOT NULL,
  FOREIGN KEY(${DbSchema.cClassTeacherId}) REFERENCES ${DbSchema.tUsers}(${DbSchema.cUserId})
)
''');

    await db.execute('''
CREATE TABLE ${DbSchema.tLearners} (
  ${DbSchema.cLearnerId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cLearnerClassId} INTEGER NOT NULL,
  ${DbSchema.cLearnerFirstName} TEXT NOT NULL,
  ${DbSchema.cLearnerLastName} TEXT NOT NULL,
  ${DbSchema.cLearnerGender} TEXT NOT NULL,
  ${DbSchema.cLearnerAge} INTEGER NOT NULL,
  ${DbSchema.cLearnerMiddleName} TEXT,
  ${DbSchema.cLearnerLrn} TEXT,
  ${DbSchema.cLearnerBirthDate} TEXT,
  ${DbSchema.cLearnerBirthOrder} TEXT,
  ${DbSchema.cLearnerNumSiblings} TEXT,
  ${DbSchema.cLearnerProvince} TEXT,
  ${DbSchema.cLearnerCity} TEXT,
  ${DbSchema.cLearnerBarangay} TEXT,
  ${DbSchema.cLearnerParentName} TEXT,
  ${DbSchema.cLearnerParentOccupation} TEXT,
  ${DbSchema.cLearnerParentEducation} TEXT,
  ${DbSchema.cLearnerGuardianName} TEXT,
  ${DbSchema.cLearnerGuardianOccupation} TEXT,
  ${DbSchema.cLearnerGuardianEducation} TEXT,
  ${DbSchema.cLearnerMotherName} TEXT,
  ${DbSchema.cLearnerMotherOccupation} TEXT,
  ${DbSchema.cLearnerMotherEducation} TEXT,
  ${DbSchema.cLearnerFatherName} TEXT,
  ${DbSchema.cLearnerFatherOccupation} TEXT,
  ${DbSchema.cLearnerFatherEducation} TEXT,
  ${DbSchema.cLearnerDominantHand} TEXT,
  ${DbSchema.cLearnerAgeMotherAtBirth} TEXT,
  ${DbSchema.cLearnerSpouseOccupation} TEXT,
  ${DbSchema.cLearnerStatus} TEXT NOT NULL,
  ${DbSchema.cLearnerCreatedAt} TEXT NOT NULL,
  FOREIGN KEY(${DbSchema.cLearnerClassId}) REFERENCES ${DbSchema.tClasses}(${DbSchema.cClassId})
)
''');

    await db.execute('''
CREATE TABLE ${DbSchema.tAssessments} (
  ${DbSchema.cAssessId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cAssessLearnerId} INTEGER NOT NULL,
  ${DbSchema.cAssessClassId} INTEGER NOT NULL,
  ${DbSchema.cAssessType} TEXT NOT NULL,
  ${DbSchema.cAssessDate} TEXT NOT NULL,
  ${DbSchema.cAssessAgeAt} INTEGER NOT NULL,
  ${DbSchema.cAssessLanguage} TEXT NOT NULL,
  ${DbSchema.cAssessCreatedAt} TEXT NOT NULL,
  FOREIGN KEY(${DbSchema.cAssessLearnerId}) REFERENCES ${DbSchema.tLearners}(${DbSchema.cLearnerId}),
  FOREIGN KEY(${DbSchema.cAssessClassId}) REFERENCES ${DbSchema.tClasses}(${DbSchema.cClassId})
)
''');

    await db.execute('''
CREATE TABLE ${DbSchema.tAnswers} (
  ${DbSchema.cAnsId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cAnsAssessId} INTEGER NOT NULL,
  ${DbSchema.cAnsDomain} TEXT NOT NULL,
  ${DbSchema.cAnsIndex} INTEGER NOT NULL,
  ${DbSchema.cAnsValue} INTEGER NOT NULL,
  FOREIGN KEY(${DbSchema.cAnsAssessId}) REFERENCES ${DbSchema.tAssessments}(${DbSchema.cAssessId})
)
''');

    await db.execute('''
CREATE TABLE ${DbSchema.tDomainSummary} (
  ${DbSchema.cDomSumId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cDomSumAssessId} INTEGER NOT NULL,
  ${DbSchema.cDomSumDomain} TEXT NOT NULL,
  ${DbSchema.cDomSumRaw} INTEGER NOT NULL,
  ${DbSchema.cDomSumScaled} INTEGER NOT NULL,
  ${DbSchema.cDomSumInterp} TEXT NOT NULL,
  FOREIGN KEY(${DbSchema.cDomSumAssessId}) REFERENCES ${DbSchema.tAssessments}(${DbSchema.cAssessId})
)
''');

    await db.execute('''
CREATE TABLE ${DbSchema.tAssessmentSummary} (
  ${DbSchema.cSumId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cSumAssessId} INTEGER NOT NULL,
  ${DbSchema.cSumOverallScaled} INTEGER NOT NULL,
  ${DbSchema.cSumStandardScore} INTEGER NOT NULL,
  ${DbSchema.cSumOverallInterpretation} TEXT NOT NULL,
  FOREIGN KEY(${DbSchema.cSumAssessId}) REFERENCES ${DbSchema.tAssessments}(${DbSchema.cAssessId})
)
''');

    await db.execute('''
CREATE TABLE ${DbSchema.tRollupSources} (
  ${DbSchema.cSrcId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cSrcAdminId} INTEGER NOT NULL,
  ${DbSchema.cSrcSchoolYear} TEXT NOT NULL,
  ${DbSchema.cSrcStatus} TEXT NOT NULL,
  ${DbSchema.cSrcLevel} TEXT NOT NULL,
  ${DbSchema.cSrcCreatedAt} TEXT NOT NULL,
  FOREIGN KEY(${DbSchema.cSrcAdminId}) REFERENCES ${DbSchema.tUsers}(${DbSchema.cUserId})
)
''');

    await db.execute('''
CREATE TABLE ${DbSchema.tRollupRows} (
  ${DbSchema.cRowId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cRowSourceId} INTEGER NOT NULL,
  ${DbSchema.cRowAssessmentType} TEXT NOT NULL,
  ${DbSchema.cRowDomain} TEXT NOT NULL,
  ${DbSchema.cRowGender} TEXT NOT NULL,
  ${DbSchema.cRowLevel} TEXT NOT NULL,
  ${DbSchema.cRowCount} INTEGER NOT NULL,
  FOREIGN KEY(${DbSchema.cRowSourceId}) REFERENCES ${DbSchema.tRollupSources}(${DbSchema.cSrcId})
)
''');

    // V2 additions
    await _upgradeToV2(db);
    await _upgradeToV3(db);
    await _upgradeToV4(db);
    await _upgradeToV5(db);
    await _upgradeToV6(db);
    await _upgradeToV7(db);
    await _upgradeToV8(db);
    await _upgradeToV9(db);
    await _upgradeToV10(db);
    await _upgradeToV11(db);
  }

  Future<void> _upgradeToV2(Database db) async {
    await db.execute('''
CREATE TABLE IF NOT EXISTS ${DbSchema.tRollupSkillRows} (
  ${DbSchema.cSkillRowId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cSkillRowSourceId} INTEGER NOT NULL,
  ${DbSchema.cSkillRowAssessmentType} TEXT NOT NULL,
  ${DbSchema.cSkillRowDomain} TEXT NOT NULL,
  ${DbSchema.cSkillRowSkillIndex} INTEGER NOT NULL,
  ${DbSchema.cSkillRowSkillText} TEXT NOT NULL,
  ${DbSchema.cSkillRowCheckedCount} INTEGER NOT NULL,
  ${DbSchema.cSkillRowTotalLearners} INTEGER NOT NULL,
  FOREIGN KEY(${DbSchema.cSkillRowSourceId}) REFERENCES ${DbSchema.tRollupSources}(${DbSchema.cSrcId})
)
''');
  }

  Future<void> _upgradeToV3(Database db) async {
    await _addColumnIfMissing(
      db,
      DbSchema.tUsers,
      DbSchema.cUserName,
      "TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tUsers,
      DbSchema.cUserAcceptedTos,
      'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tUsers,
      DbSchema.cUserAcceptedPrivacy,
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _upgradeToV4(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.transaction((txn) async {
      await txn.execute('''
CREATE TABLE users_v4_tmp (
  ${DbSchema.cUserId} INTEGER PRIMARY KEY AUTOINCREMENT,
  ${DbSchema.cUserEmail} TEXT NOT NULL,
  ${DbSchema.cUserPasswordHash} TEXT NOT NULL,
  ${DbSchema.cUserRole} TEXT NOT NULL,
  ${DbSchema.cUserName} TEXT NOT NULL DEFAULT '',
  ${DbSchema.cUserAcceptedTos} INTEGER NOT NULL DEFAULT 0,
  ${DbSchema.cUserAcceptedPrivacy} INTEGER NOT NULL DEFAULT 0,
  ${DbSchema.cUserSchool} TEXT,
  ${DbSchema.cUserDistrict} TEXT,
  ${DbSchema.cUserDivision} TEXT,
  ${DbSchema.cUserRegion} TEXT,
  ${DbSchema.cUserCreatedAt} TEXT NOT NULL,
  UNIQUE(${DbSchema.cUserEmail}, ${DbSchema.cUserRole})
)
''');

      await txn.execute('''
INSERT INTO users_v4_tmp (
  ${DbSchema.cUserId},
  ${DbSchema.cUserEmail},
  ${DbSchema.cUserPasswordHash},
  ${DbSchema.cUserRole},
  ${DbSchema.cUserName},
  ${DbSchema.cUserAcceptedTos},
  ${DbSchema.cUserAcceptedPrivacy},
  ${DbSchema.cUserSchool},
  ${DbSchema.cUserDistrict},
  ${DbSchema.cUserDivision},
  ${DbSchema.cUserRegion},
  ${DbSchema.cUserCreatedAt}
)
SELECT
  ${DbSchema.cUserId},
  LOWER(${DbSchema.cUserEmail}),
  ${DbSchema.cUserPasswordHash},
  LOWER(${DbSchema.cUserRole}),
  COALESCE(${DbSchema.cUserName}, ''),
  COALESCE(${DbSchema.cUserAcceptedTos}, 0),
  COALESCE(${DbSchema.cUserAcceptedPrivacy}, 0),
  ${DbSchema.cUserSchool},
  ${DbSchema.cUserDistrict},
  ${DbSchema.cUserDivision},
  ${DbSchema.cUserRegion},
  ${DbSchema.cUserCreatedAt}
FROM ${DbSchema.tUsers}
''');

      await txn.execute('DROP TABLE ${DbSchema.tUsers}');
      await txn.execute(
        'ALTER TABLE users_v4_tmp RENAME TO ${DbSchema.tUsers}',
      );
    });
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeToV5(Database db) async {
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerMiddleName,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerLrn,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerBirthDate,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerBirthOrder,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerNumSiblings,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerProvince,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerCity,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerBarangay,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerParentName,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerParentOccupation,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerAgeMotherAtBirth,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerSpouseOccupation,
      'TEXT',
    );
  }

  Future<void> _upgradeToV6(Database db) async {
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerMotherName,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerMotherOccupation,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerFatherName,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerFatherOccupation,
      'TEXT',
    );
  }

  Future<void> _upgradeToV7(Database db) async {
    await _addColumnIfMissing(
      db,
      DbSchema.tRollupSources,
      DbSchema.cSrcLabel,
      "TEXT NOT NULL DEFAULT ''",
    );
  }

  Future<void> _upgradeToV8(Database db) async {
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerParentEducation,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerMotherEducation,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerFatherEducation,
      'TEXT',
    );
  }

  Future<void> _upgradeToV9(Database db) async {
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerGuardianName,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerGuardianOccupation,
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerGuardianEducation,
      'TEXT',
    );
  }

  Future<void> _upgradeToV10(Database db) async {
    await _addColumnIfMissing(
      db,
      DbSchema.tLearners,
      DbSchema.cLearnerDominantHand,
      'TEXT',
    );
  }

  Future<void> _upgradeToV11(Database db) async {
    await _addColumnIfMissing(
      db,
      DbSchema.tUsers,
      DbSchema.cUserLastMonthlyOtpAt,
      'TEXT',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final cols = await db.rawQuery("PRAGMA table_info($table)");
    final exists = cols.any((c) => (c['name'] as String?) == column);
    if (exists) return;
    await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
  }
}
