class Validators {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _schoolYearPairRe = RegExp(r'^\d{4}-\d{4}$');

  static String? required(String? v, {String label = 'Field'}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? email(String? v) {
    final req = required(v, label: 'Email');
    if (req != null) return req;
    if (!_emailRe.hasMatch(v!.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? v) {
    final req = required(v, label: 'Password');
    if (req != null) return req;
    final s = v!.trim();
    if (s.length < 8) return 'Password must be at least 8 characters';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(s);
    final hasNumber = RegExp(r'\d').hasMatch(s);
    if (!hasLetter || !hasNumber)
      return 'Password must include letters and numbers';
    return null;
  }

  static String? schoolYearPair(String? v) {
    final req = required(v, label: 'School Year');
    if (req != null) return req;
    if (!_schoolYearPairRe.hasMatch(v!.trim())) return 'Use format YYYY-YYYY';
    final parts = v.split('-');
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null || b != a + 1)
      return 'School Year must be consecutive (e.g., 2025-2026)';
    return null;
  }

  static String? ageForEccd(String? v) {
    final req = required(v, label: 'Age');
    if (req != null) return req;
    final age = int.tryParse(v!.trim());
    if (age == null) return 'Age must be a number';
    // Adjust if your ECCD categories differ.
    if (age < 3 || age > 5) return 'Age must be between 3 and 5';
    return null;
  }
}
