class AssessmentScoring {

  static const List<String> domainsShort = [
    'gmd', 'fms', 'shd', 'rl', 'el', 'cd', 'sed'
  ];

  static Map<String, dynamic> calculate({
    required double ageInYears,
    required int gmdRaw,
    required int fmsRaw,
    required int shdRaw,
    required int rlRaw,
    required int elRaw,
    required int cdRaw,
    required int sedRaw,
  }) {

    if (ageInYears < 3.1 || ageInYears > 5.11) {
      throw Exception("Invalid age range: $ageInYears");
    }

    final gmdSS = _getScaledScore(ageInYears, 'gmd', gmdRaw);
    final fmsSS = _getScaledScore(ageInYears, 'fms', fmsRaw);
    final shdSS = _getScaledScore(ageInYears, 'shd', shdRaw);
    final rlSS  = _getScaledScore(ageInYears, 'rl', rlRaw);
    final elSS  = _getScaledScore(ageInYears, 'el', elRaw);
    final cdSS  = _getScaledScore(ageInYears, 'cd', cdRaw);
    final sedSS = _getScaledScore(ageInYears, 'sed', sedRaw);

    final rawTotal =
        gmdRaw + fmsRaw + shdRaw + rlRaw + elRaw + cdRaw + sedRaw;

    final summaryScaled =
        gmdSS + fmsSS + shdSS + rlSS + elSS + cdSS + sedSS;

    final standardScore = _getStandardScore(summaryScaled);

    return {
      "gmd_total": gmdRaw,
      "gmd_ss": gmdSS,
      "gmd_interpretation": scaledInterpretation(gmdSS),

      "fms_total": fmsRaw,
      "fms_ss": fmsSS,
      "fms_interpretation": scaledInterpretation(fmsSS),

      "shd_total": shdRaw,
      "shd_ss": shdSS,
      "shd_interpretation": scaledInterpretation(shdSS),

      "rl_total": rlRaw,
      "rl_ss": rlSS,
      "rl_interpretation": scaledInterpretation(rlSS),

      "el_total": elRaw,
      "el_ss": elSS,
      "el_interpretation": scaledInterpretation(elSS),

      "cd_total": cdRaw,
      "cd_ss": cdSS,
      "cd_interpretation": scaledInterpretation(cdSS),

      "sed_total": sedRaw,
      "sed_ss": sedSS,
      "sed_interpretation": scaledInterpretation(sedSS),

      "raw_score": rawTotal,
      "summary_scaled_score": summaryScaled,
      "standard_score": standardScore,
      "interpretation": _overallInterpretation(standardScore),
    };
  }

  // ROUTER
  static int _getScaledScore(double age, String domain, int raw) {
    if (age >= 3.1 && age <= 4.0) return _age3to4(domain, raw);
    if (age >= 4.1 && age <= 5.0) return _age4to5(domain, raw);
    if (age >= 5.1 && age <= 5.11) return _age5to511(domain, raw);
    throw Exception("Invalid age");
  }

  // INTERPRETATIONS
  static String scaledInterpretation(int ss) {
    if (ss <= 3) return "SSDD";
    if (ss <= 6) return "SSLDD";
    if (ss <= 13) return "AD";
    if (ss <= 16) return "SSAD";
    return "SHAD";
  }

  static String _overallInterpretation(int score) {
    if (score <= 69) return "SSDD";
    if (score <= 79) return "SSLDD";
    if (score <= 119) return "AD";
    if (score <= 129) return "SSAD";
    return "SHAD";
  }

  static int _getStandardScore(int sum) {
    const table = {29:37,30:38,31:40,32:41,33:43,34:44,35:45,36:47,37:48,38:50,39:51,40:53,41:54,42:56,43:57,44:59,45:60,46:62,47:63,48:65,49:66,50:67,51:69,52:70,53:72,54:73,55:75,56:76,57:78,58:79,59:81,60:82,61:84,62:85,63:86,64:88,65:89,66:91,67:92,68:94,69:95,70:97,71:98,72:100,73:101,74:103,75:104,76:105,77:107,78:108,79:110,80:111,81:113,82:114,83:116,84:117,85:119,86:120,87:122,88:123,89:124,90:126,91:127,92:129,93:130,94:132,95:133,96:135,97:136,98:138};

    if (table.containsKey(sum)) return table[sum]!;
    final lowerKey = table.keys.where((k) => k <= sum).reduce((a,b)=>a>b?a:b);
    return table[lowerKey]!;
  }

  // =====================================================
  // AGE TABLES (THE MISSING PART THAT CAUSED YOUR ERROR)
  // =====================================================

  static int _age3to4(String d, int r) {
    if (d == 'gmd') return r <= 3 ? 1 : r == 4 ? 2 : r == 5 ? 3 : r == 6 ? 5 : r == 7 ? 6 : r == 8 ? 7 : r == 9 ? 8 : r == 10 ? 10 : r == 11 ? 11 : r == 12 ? 12 : 14;
    if (d == 'fms') return r <= 3 ? 2 : r == 4 ? 4 : r == 5 ? 5 : r == 6 ? 7 : r == 7 ? 9 : r == 8 ? 10 : r == 9 ? 12 : r == 10 ? 14 : r == 11 ? 15 : 16;
    if (d == 'rl')  return r <= 1 ? 3 : r == 2 ? 5 : r == 3 ? 7 : r == 4 ? 10 : r == 5 ? 12 : 14;
    if (d == 'el')  return r <= 2 ? 1 : r == 3 ? 3 : r == 4 ? 4 : r == 5 ? 6 : r == 6 ? 9 : r == 7 ? 11 : 13;
    return 10;
  }

  static int _age4to5(String d, int r) {
    if (d == 'gmd') return r <= 5 ? 1 : r == 6 ? 2 : r == 7 ? 4 : r == 8 ? 5 : r == 9 ? 7 : r == 10 ? 8 : r == 11 ? 10 : r == 12 ? 11 : 13;
    if (d == 'fms') return r <= 3 ? 1 : r == 4 ? 2 : r == 5 ? 4 : r == 6 ? 5 : r == 7 ? 7 : r == 8 ? 9 : r == 9 ? 10 : r == 10 ? 12 : 14;
    return 10;
  }

  static int _age5to511(String d, int r) {
    if (d == 'gmd') return r <= 10 ? 1 : r == 11 ? 4 : r == 12 ? 7 : 11;
    if (d == 'fms') return r <= 5 ? 1 : r == 6 ? 3 : r == 7 ? 5 : r == 8 ? 7 : r == 9 ? 8 : r == 10 ? 10 : 12;
    return 10;
  }
}