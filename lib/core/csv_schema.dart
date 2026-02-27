class RollupCsvSchema {
  static const metaMarker = 'META';
  static const dataMarker = 'DATA';
  static const skillMarker = 'SKILL';

  static const metaKeys = [
    'ORG_LEVEL',
    'SCHOOL_YEAR',
    'SCHOOL',
    'DISTRICT',
    'DIVISION',
    'REGION',
    'GRADE',
    'SECTION',
    'DATE_GENERATED',
  ];

  // DATA rows: TYPE, DOMAIN, GENDER, LEVEL, COUNT
  static const dataHeader = ['TYPE', 'DOMAIN', 'GENDER', 'LEVEL', 'COUNT'];

  // SKILL rows: TYPE, DOMAIN, SKILL_INDEX, SKILL_TEXT, CHECKED_COUNT, TOTAL_LEARNERS
  // This enables Admin Top 3 most/least learned per domain.
  static const skillHeader = [
    'TYPE',
    'DOMAIN',
    'SKILL_INDEX',
    'SKILL_TEXT',
    'CHECKED_COUNT',
    'TOTAL_LEARNERS'
  ];
}
