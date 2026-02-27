class DevLevels {
  static const ssdd = 'SSDD';
  static const ssldd = 'SSLDD';
  static const ad = 'AD';
  static const ssad = 'SSAD';
  static const shad = 'SHAD';

  static const ordered = [ssdd, ssldd, ad, ssad, shad];
}

class ScoringService {
  String scaledInterpretation(int scaledScore) {
    if (scaledScore <= 3) return DevLevels.ssdd;
    if (scaledScore <= 6) return DevLevels.ssldd;
    if (scaledScore <= 13) return DevLevels.ad;
    if (scaledScore <= 16) return DevLevels.ssad;
    return DevLevels.shad;
  }

  String overallInterpretation(int standardScore) {
    if (standardScore <= 69) return DevLevels.ssdd;
    if (standardScore <= 79) return DevLevels.ssldd;
    if (standardScore <= 119) return DevLevels.ad;
    if (standardScore <= 129) return DevLevels.ssad;
    return DevLevels.shad;
  }

  int rawToScaled({
    required double ageValue,
    required String domain,
    required int raw,
  }) {
    final d = _domainCode(domain);
    final isOlderBand = ageValue >= 5.1;

    switch (d) {
      case 'gmd':
        // SPARKLER Teacher Report formula (I->J)
        if (isOlderBand) {
          if (raw <= 10) return 1;
          if (raw == 11) return 4;
          if (raw == 12) return 7;
          return 11; // raw >= 13
        }
        if (raw <= 5) return 1;
        if (raw == 6) return 2;
        if (raw == 7) return 4;
        if (raw == 8) return 5;
        if (raw == 9) return 7;
        if (raw == 10) return 8;
        if (raw == 11) return 10;
        if (raw == 12) return 11;
        return 13; // raw >= 13

      case 'fms':
        // SPARKLER Teacher Report formula (L->M)
        if (isOlderBand) {
          if (raw <= 5) return 1;
          if (raw == 6) return 3;
          if (raw == 7) return 5;
          if (raw == 8) return 7;
          if (raw == 9) return 8;
          if (raw == 10) return 10;
          return 12; // raw >= 11
        }
        if (raw <= 3) return 1;
        if (raw == 4) return 2;
        if (raw == 5) return 4;
        if (raw == 6) return 5;
        if (raw == 7) return 7;
        if (raw == 8) return 9;
        if (raw == 9) return 10;
        if (raw == 10) return 12;
        return 14; // raw >= 11

      case 'shd':
        // SPARKLER Teacher Report formula (O->P) [Self Help]
        if (isOlderBand) {
          if (raw <= 19) return 2;
          if (raw == 20) return 3;
          if (raw == 21) return 4;
          if (raw == 22) return 6;
          if (raw == 23) return 7;
          if (raw == 24) return 9;
          if (raw == 25) return 10;
          if (raw == 26) return 12;
          return 13; // raw >= 27
        }
        if (raw <= 15) return 1;
        if (raw == 16) return 2;
        if (raw == 17) return 3;
        if (raw == 18) return 4;
        if (raw == 19) return 5;
        if (raw == 20) return 6;
        if (raw == 21) return 8;
        if (raw == 22) return 9;
        if (raw == 23) return 10;
        if (raw == 24) return 11;
        if (raw == 25) return 12;
        if (raw == 26) return 13;
        return 14; // raw >= 27

      case 'rl':
        // SPARKLER Teacher Report formula (R->S)
        if (isOlderBand) {
          if (raw <= 2) return 1;
          if (raw == 3) return 4;
          if (raw == 4) return 8;
          return 11; // raw >= 5
        }
        if (raw <= 1) return 1;
        if (raw == 2) return 3;
        if (raw == 3) return 6;
        if (raw == 4) return 9;
        return 11; // raw >= 5

      case 'el':
        // SPARKLER Teacher Report formula (U->V)
        if (isOlderBand) {
          if (raw <= 7) return 5;
          return 11; // raw >= 8
        }
        if (raw <= 5) return 2;
        if (raw == 6) return 5;
        if (raw == 7) return 8;
        return 11; // raw >= 8

      case 'cd':
        // SPARKLER Teacher Report formula (X->Y)
        if (isOlderBand) {
          if (raw <= 9) return 1;
          if (raw == 10) return 2;
          if (raw == 11) return 3;
          if (raw == 12) return 4;
          if (raw == 13) return 5;
          if (raw == 14) return 6;
          if (raw == 15) return 7;
          if (raw == 16) return 8;
          if (raw == 17) return 9;
          if (raw == 18) return 10;
          if (raw == 19) return 11;
          if (raw == 20) return 12;
          return 13; // raw >= 21
        }
        if (raw == 0) return 1;
        if (raw == 1) return 2;
        if (raw <= 3) return 3;
        if (raw == 4) return 4;
        if (raw == 5) return 5;
        if (raw <= 7) return 6;
        if (raw == 8) return 7;
        if (raw <= 10) return 8;
        if (raw == 11) return 9;
        if (raw == 12) return 10;
        if (raw <= 14) return 11;
        if (raw == 15) return 12;
        if (raw <= 17) return 13;
        if (raw == 18) return 14;
        if (raw <= 20) return 15;
        return 16; // raw >= 21

      case 'sed':
        // SPARKLER Teacher Report formula (AA->AB)
        if (isOlderBand) {
          if (raw <= 15) return 1;
          if (raw == 16) return 2;
          if (raw == 17) return 3;
          if (raw == 18) return 5;
          if (raw == 19) return 6;
          if (raw == 20) return 7;
          if (raw == 21) return 9;
          if (raw == 22) return 10;
          if (raw == 23) return 11;
          return 13; // raw >= 24
        }
        if (raw <= 13) return 1;
        if (raw == 14) return 2;
        if (raw == 15) return 3;
        if (raw == 16) return 4;
        if (raw == 17) return 5;
        if (raw == 18) return 7;
        if (raw == 19) return 8;
        if (raw == 20) return 9;
        if (raw == 21) return 10;
        if (raw == 22) return 11;
        if (raw == 23) return 12;
        return 13; // raw >= 24

      default:
        throw Exception('Unknown domain: $domain');
    }
  }

  int overallScaledToStandard(int overallScaled) {
    const table = {
      29: 37,
      30: 38,
      31: 40,
      32: 41,
      33: 43,
      34: 44,
      35: 45,
      36: 47,
      37: 48,
      38: 50,
      39: 51,
      40: 53,
      41: 54,
      42: 56,
      43: 57,
      44: 59,
      45: 60,
      46: 62,
      47: 63,
      48: 65,
      49: 66,
      50: 67,
      51: 69,
      52: 70,
      53: 72,
      54: 73,
      55: 75,
      56: 76,
      57: 78,
      58: 79,
      59: 81,
      60: 82,
      61: 84,
      62: 85,
      63: 86,
      64: 88,
      65: 89,
      66: 91,
      67: 92,
      68: 94,
      69: 95,
      70: 97,
      71: 98,
      72: 100,
      73: 101,
      74: 103,
      75: 104,
      76: 105,
      77: 107,
      78: 108,
      79: 110,
      80: 111,
      81: 113,
      82: 114,
      83: 116,
      84: 117,
      85: 119,
      86: 120,
      87: 122,
      88: 123,
      89: 124,
      90: 126,
      91: 127,
      92: 129,
      93: 130,
      94: 132,
      95: 133,
      96: 135,
      97: 136,
      98: 138,
    };
    if (table.containsKey(overallScaled)) return table[overallScaled]!;
    if (overallScaled <= 29) return table[29]!;
    const maxKey = 98;
    if (overallScaled >= maxKey) return table[maxKey]!;
    final lowerKey = table.keys
        .where((k) => k <= overallScaled)
        .reduce((a, b) => a > b ? a : b);
    return table[lowerKey]!;
  }

  String _domainCode(String domain) {
    final d = domain.toLowerCase().trim();
    if (d.contains('gross')) return 'gmd';
    if (d.contains('fine')) return 'fms';
    if (d.contains('self') || d.contains('dress') || d.contains('toilet')) {
      return 'shd';
    }
    if (d.contains('receptive')) return 'rl';
    if (d.contains('expressive')) return 'el';
    if (d.contains('cognitive')) return 'cd';
    if (d.contains('social') || d.contains('socio')) return 'sed';
    return d;
  }
}
