class DbSchema {
  // V11: add monthly login OTP verification timestamp for users.
  static const int dbVersion = 11;

  // USERS
  static const String tUsers = 'users';
  static const String cUserId = 'id';
  static const String cUserEmail = 'email';
  static const String cUserPasswordHash = 'password_hash';
  static const String cUserRole = 'role'; // teacher|admin
  static const String cUserName = 'name';
  static const String cUserAcceptedTos = 'accepted_tos';
  static const String cUserAcceptedPrivacy = 'accepted_privacy';
  static const String cUserCreatedAt = 'created_at';
  static const String cUserLastMonthlyOtpAt = 'last_monthly_otp_at';

  // Org profile fields
  static const String cUserSchool = 'school';
  static const String cUserDistrict = 'district';
  static const String cUserDivision = 'division';
  static const String cUserRegion = 'region';

  // CLASSES
  static const String tClasses = 'classes';
  static const String cClassId = 'id';
  static const String cClassTeacherId = 'teacher_id';
  static const String cClassGrade = 'grade';
  static const String cClassSection = 'section';
  static const String cClassSchoolYear = 'school_year';
  static const String cClassStatus = 'status'; // active|archived
  static const String cClassCreatedAt = 'created_at';

  // LEARNERS
  static const String tLearners = 'learners';
  static const String cLearnerId = 'id';
  static const String cLearnerClassId = 'class_id';
  static const String cLearnerFirstName = 'first_name';
  static const String cLearnerLastName = 'last_name';
  static const String cLearnerGender = 'gender'; // M|F
  static const String cLearnerAge = 'age';
  static const String cLearnerMiddleName = 'middle_name';
  static const String cLearnerLrn = 'lrn';
  static const String cLearnerBirthDate = 'birth_date';
  static const String cLearnerBirthOrder = 'birth_order';
  static const String cLearnerNumSiblings = 'number_of_siblings';
  static const String cLearnerProvince = 'province';
  static const String cLearnerCity = 'city';
  static const String cLearnerBarangay = 'barangay';
  static const String cLearnerParentName = 'parent_name';
  static const String cLearnerParentOccupation = 'parent_occupation';
  static const String cLearnerParentEducation = 'parent_education';
  static const String cLearnerGuardianName = 'guardian_name';
  static const String cLearnerGuardianOccupation = 'guardian_occupation';
  static const String cLearnerGuardianEducation = 'guardian_education';
  static const String cLearnerMotherName = 'mother_name';
  static const String cLearnerMotherOccupation = 'mother_occupation';
  static const String cLearnerMotherEducation = 'mother_education';
  static const String cLearnerFatherName = 'father_name';
  static const String cLearnerFatherOccupation = 'father_occupation';
  static const String cLearnerFatherEducation = 'father_education';
  static const String cLearnerDominantHand = 'dominant_hand';
  static const String cLearnerAgeMotherAtBirth = 'age_mother_at_birth';
  static const String cLearnerSpouseOccupation = 'spouse_occupation';
  static const String cLearnerStatus = 'status'; // active|dropped
  static const String cLearnerCreatedAt = 'created_at';

  // ASSESSMENTS (pre/post)
  static const String tAssessments = 'assessments';
  static const String cAssessId = 'id';
  static const String cAssessLearnerId = 'learner_id';
  static const String cAssessClassId = 'class_id';
  static const String cAssessType = 'type'; // pre|post|conditional
  static const String cAssessDate = 'date_iso';
  static const String cAssessAgeAt = 'age_at_assessment';
  static const String cAssessLanguage = 'language'; // english|tagalog
  static const String cAssessCreatedAt = 'created_at';

  // ANSWERS
  static const String tAnswers = 'answers';
  static const String cAnsId = 'id';
  static const String cAnsAssessId = 'assessment_id';
  static const String cAnsDomain = 'domain';
  static const String cAnsIndex = 'question_index';
  static const String cAnsValue = 'value'; // 0|1

  // DOMAIN SUMMARY (per domain)
  static const String tDomainSummary = 'domain_summary';
  static const String cDomSumId = 'id';
  static const String cDomSumAssessId = 'assessment_id';
  static const String cDomSumDomain = 'domain';
  static const String cDomSumRaw = 'raw_score';
  static const String cDomSumScaled = 'scaled_score';
  static const String cDomSumInterp =
      'interpretation'; // SSDD|SSLDD|AD|SSAD|SHAD

  // OVERALL SUMMARY
  static const String tAssessmentSummary = 'assessment_summary';
  static const String cSumId = 'id';
  static const String cSumAssessId = 'assessment_id';
  static const String cSumOverallScaled = 'overall_scaled';
  static const String cSumStandardScore = 'standard_score';
  static const String cSumOverallInterpretation = 'overall_interpretation';

  // ADMIN ROLLUP SOURCES (imported CSVs)
  static const String tRollupSources = 'rollup_sources';
  static const String cSrcId = 'id';
  static const String cSrcAdminId = 'admin_id';
  static const String cSrcSchoolYear = 'school_year';
  static const String cSrcStatus = 'status'; // active|archived
  static const String cSrcLevel =
      'org_level'; // teacher|school|district|division|regional
  static const String cSrcLabel = 'label'; // e.g. section name, school name
  static const String cSrcCreatedAt = 'created_at';

  // ADMIN ROLLUP ROWS (domain×gender×level counts)
  static const String tRollupRows = 'rollup_rows';
  static const String cRowId = 'id';
  static const String cRowSourceId = 'source_id';
  static const String cRowAssessmentType = 'assessment_type'; // pre|post
  static const String cRowDomain = 'domain';
  static const String cRowGender = 'gender'; // M|F|ALL
  static const String cRowLevel = 'level';
  static const String cRowCount = 'count';

  // NEW: ADMIN SKILL ROLLUP ROWS (per domain, per skill index)
  static const String tRollupSkillRows = 'rollup_skill_rows';
  static const String cSkillRowId = 'id';
  static const String cSkillRowSourceId = 'source_id';
  static const String cSkillRowAssessmentType = 'assessment_type'; // pre|post
  static const String cSkillRowDomain = 'domain';
  static const String cSkillRowSkillIndex = 'skill_index';
  static const String cSkillRowSkillText = 'skill_text';
  static const String cSkillRowCheckedCount = 'checked_count';
  static const String cSkillRowTotalLearners = 'total_learners';
}
