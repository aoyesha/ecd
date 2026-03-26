import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/ui_feedback.dart';
import '../../../core/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/settings_service.dart';
import '../../widgets/section_title.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _profileKey = GlobalKey<FormState>();
  final _pwKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _schoolCtrl = TextEditingController();
  final _currentPwCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _hasMinLength(String v) => v.length >= 8;
  bool _hasUppercase(String v) => RegExp(r'[A-Z]').hasMatch(v);
  bool _hasLowercase(String v) => RegExp(r'[a-z]').hasMatch(v);
  bool _hasNumber(String v) => RegExp(r'[0-9]').hasMatch(v);
  bool _hasSpecialChar(String v) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(v);

  bool _editingProfile = false;
  bool _obscureCurrentPw = true;
  bool _obscureNewPw = true;
  bool _showPwRules = false;

  String? _selectedRegion;
  String? _selectedDivision;
  String? _selectedDistrict;

  bool _loaded = false;

  Map<String, dynamic> currentProfile = {
    'name': '',
    'email': '',
    'school': '',
    'currentPw': '',
  };

  static const List<String> _regions = ['MIMAROPA'];

  static const Map<String, List<String>> _divisionsByRegion = {
    'MIMAROPA': [
      'Oriental Mindoro',
      'Occidental Mindoro',
      'Marinduque',
      'Romblon',
      'Palawan',
      'Puerto Princesa City',
      'Calapan City',
    ],
  };

  static const Map<String, List<String>> _districtsByDivision = {
    // Occidental Mindoro
    'Occidental Mindoro': [
      'Abra de Ilog',
      'Calintaan',
      'Looc',
      'Lubang',
      'Mamburao',
      'Paluan',
      'Rizal',
      'Sablayan',
      'San Jose',
      'Santa Cruz',
    ],

    // Oriental Mindoro
    'Oriental Mindoro': [
      'Baco',
      'Bansud',
      'Bongabong',
      'Bulalacao',
      'Gloria',
      'Mansalay',
      'Naujan',
      'Pinamalayan',
      'Pola',
      'Roxas',
      'San Teodoro',
      'Socorro',
      'Victoria',
    ],

    // Marinduque
    'Marinduque': [
      'Boac',
      'Buenavista',
      'Gasan',
      'Mogpog',
      'Santa Cruz',
      'Torrijos',
    ],

    // Romblon
    'Romblon': [
      'Alcantara',
      'Banton',
      'Cajidiocan',
      'Calatrava',
      'Concepcion',
      'Corcuera',
      'Ferrol',
      'Looc',
      'Magdiwang',
      'Odiongan',
      'Romblon',
      'San Agustin',
      'San Andres',
      'San Fernando',
      'San Jose',
      'Santa Fe',
    ],

    // Palawan Province (excluding Puerto Princesa)
    'Palawan': [
      'Aborlan',
      'Agutaya',
      'Araceli',
      'Balabac',
      'Bataraza',
      'Brooke\'s Point',
      'Busuanga',
      'Cagayancillo',
      'Coron',
      'Culion',
      'Cuyo',
      'Dumaran',
      'El Nido',
      'Kalayaan',
      'Linapacan',
      'Magsaysay',
      'Narra',
      'Quezon',
      'Rizal',
      'Roxas',
      'San Vicente',
      'Sofronio Española',
      'Taytay',
    ],

    // Independent Cities
    'Puerto Princesa City': ['Puerto Princesa North', 'Puerto Princesa South'],

    'Calapan City': ['Calapan East', 'Calapan West'],
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _schoolCtrl.dispose();
    _currentPwCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, Object?> user) {
    if (_loaded) return;
    currentProfile['name'] = _nameCtrl.text = (user['name'] ?? '').toString();
    currentProfile['email'] = _emailCtrl.text = (user['email'] ?? '')
        .toString();
    _schoolCtrl.text = (user['school'] ?? '').toString();
    _selectedRegion = (user['region'] ?? '').toString().isEmpty
        ? null
        : user['region'].toString();
    _selectedDivision = (user['division'] ?? '').toString().isEmpty
        ? null
        : user['division'].toString();
    _selectedDistrict = (user['district'] ?? '').toString().isEmpty
        ? null
        : user['district'].toString();
    _loaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final settings = context.watch<SettingsService>();
    final session = auth.session!;

    return FutureBuilder<Map<String, Object?>?>(
      future: auth.getUser(session.userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data ?? const <String, Object?>{};
        _hydrate(user);

        return Column(
          children: [
            /// SCROLLABLE CONTENT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    const SectionTitle(title: 'Account Settings'),
                    const SizedBox(height: 12),

                    _sectionCard(
                      title: 'Profile Information',
                      initiallyExpanded: true,
                      child: _editingProfile
                          ? _editProfileForm(session, auth)
                          : _profileViewCard(),
                    ),

                    const SizedBox(height: 12),

                    _sectionCard(
                      title: 'App Preferences',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Font Size',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Slider(
                            value: settings.fontScale,
                            min: 0.9,
                            max: 1.4,
                            divisions: 10,
                            label: settings.fontScale.toStringAsFixed(2),
                            onChanged: (v) => settings.setFontScale(v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    _sectionCard(
                      title: 'Security',
                      child: _passwordSection(auth, session),
                    ),
                    const SizedBox(height: 12),
                    _sectionCard(title: 'Support', child: _supportSection()),
                    const SizedBox(height: 12),
                    _sectionCard(title: 'Developers', child: _developersGrid()),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            /// FIXED LOGOUT BUTTON
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => auth.logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
              ),
            ),
          ],
        );
      },
    );
  }

  // ================= PROFILE VIEW =================
  Widget _profileViewCard() {
    Widget item(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              l,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(child: Text(v.isEmpty ? '-' : v)),
        ],
      ),
    );

    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => setState(() => _editingProfile = true),
          ),
        ),
        item('Full Name', _nameCtrl.text),
        item('Email', _emailCtrl.text),
        item('Region', _selectedRegion ?? ''),
        item('Division', _selectedDivision ?? ''),
        item('District', _selectedDistrict ?? ''),
        item('School', _schoolCtrl.text),
      ],
    );
  }

  String? _requiredDropdown(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  // ================= PROFILE EDIT =================
  Widget _editProfileForm(session, AuthService auth) {
    return Form(
      key: _profileKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameCtrl,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z\s\-']")),
            ],
            validator: (v) {
              final value = v?.trim() ?? '';

              if (value.isEmpty) {
                return 'Full Name is required';
              }

              final nameRegex = RegExp(r"^[A-Za-z]+([ '\-][A-Za-z]+)*$");

              if (!nameRegex.hasMatch(value)) {
                return 'Name must contain letters only';
              }

              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _field(_emailCtrl, 'Email', Validators.accountEmail),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            items: _regionItems(),
            validator: (v) => _requiredDropdown(v, 'Region'),
            onChanged: (v) => setState(() {
              _selectedRegion = v;
              _selectedDivision = null;
              _selectedDistrict = null;
            }),
            decoration: const InputDecoration(
              labelText: 'Region',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedDivision,
            items: _divisionItems(),
            validator: (v) => _requiredDropdown(v, 'Division'),
            onChanged: (v) => setState(() {
              _selectedDivision = v;
              _selectedDistrict = null; // reset cascade
            }),
            decoration: const InputDecoration(
              labelText: 'Division',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedDistrict,
            items: _districtItems(),
            validator: (v) => _requiredDropdown(v, 'District'),
            onChanged: (v) => setState(() => _selectedDistrict = v),
            decoration: const InputDecoration(
              labelText: 'District',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          _field(
            _schoolCtrl,
            'School',
            (v) => Validators.required(v, label: 'School'),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _editingProfile = false),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!_profileKey.currentState!.validate()) return;
                  try {
                    await auth.updateProfile(
                      userId: session.userId,
                      name: _nameCtrl.text,
                      email: _emailCtrl.text,
                      school: _schoolCtrl.text,
                      district: _selectedDistrict ?? '',
                      division: _selectedDivision ?? '',
                      region: _selectedRegion ?? '',
                    );

                    if (!mounted) return;
                    setState(() => _editingProfile = false);
                    AppFeedback.showSnackBar(
                      context,
                      'Profile updated.',
                      tone: AppFeedbackTone.success,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    if (e is StateError &&
                        e.message == 'Email already exists.') {
                      AppFeedback.showSnackBar(
                        context,
                        'This email is already registered.',
                        tone: AppFeedbackTone.error,
                      );
                      _emailCtrl.text = currentProfile['email'];
                    } else {
                      AppFeedback.showSnackBar(
                        context,
                        'Failed to update profile.',
                        tone: AppFeedbackTone.error,
                      );
                      // TO-DO: idk if kaya i-run _hydrate again somehow, dito sana
                    }
                    return;
                  }
                  setState(() => _editingProfile = false);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= PASSWORD =================
  Widget _passwordSection(AuthService auth, session) {
    return Form(
      key: _pwKey,
      child: Column(
        children: [
          /// CURRENT PASSWORD
          TextFormField(
            controller: _currentPwCtrl,
            validator: (v) => Validators.required(v, label: 'Current Password'),
            obscureText: _obscureCurrentPw,
            decoration: InputDecoration(
              labelText: 'Current Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureCurrentPw ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureCurrentPw = !_obscureCurrentPw;
                  });
                },
              ),
            ),
          ),

          const SizedBox(height: 10),

          /// NEW PASSWORD + CHECKLIST
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _pwCtrl,
                obscureText: _obscureNewPw,
                onChanged: (_) => setState(() => _showPwRules = true),
                validator: (value) {
                  final v = value ?? '';

                  if (v.isEmpty) return 'New password is required';

                  if (_currentPwCtrl.text == v) {
                    return 'New password must be different from current password';
                  }

                  if (!_hasMinLength(v) ||
                      !_hasUppercase(v) ||
                      !_hasLowercase(v) ||
                      !_hasNumber(v) ||
                      !_hasSpecialChar(v)) {
                    return 'Password does not meet requirements';
                  }

                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNewPw ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureNewPw = !_obscureNewPw),
                  ),
                ),
              ),

              if (_showPwRules) _passwordChecklist(_pwCtrl.text),
            ],
          ),

          const SizedBox(height: 12),

          /// UPDATE PASSWORD BUTTON  (THIS WAS MISSING)
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.maroon,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (!_pwKey.currentState!.validate()) return;

                try {
                  await auth.changePassword(
                    userId: session.userId,
                    currentPassword: _currentPwCtrl.text,
                    newPassword: _pwCtrl.text,
                  );

                  _currentPwCtrl.clear();
                  _pwCtrl.clear();
                  _showPwRules = false;

                  if (!mounted) return;
                  AppFeedback.showSnackBar(
                    context,
                    'Password successfully updated',
                    tone: AppFeedbackTone.success,
                  );
                } catch (e) {
                  if (!mounted) return;

                  AppFeedback.showSnackBar(
                    context,
                    'Current password is incorrect',
                    tone: AppFeedbackTone.error,
                  );
                }
              },
              child: const Text('Update Password'),
            ),
          ),
        ],
      ),
    );
  }

  // ================= SUPPORT =================
  Widget _supportSection() {
    return Align(
      alignment: Alignment.centerLeft, // force left alignment
      child: SizedBox(
        width: double.infinity, // take full width of card
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start, // left align children
          children: [
            Text(
              'Privacy Policy',
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'Your account and assessment data are stored locally in this system. '
              'Only exported files that you intentionally share are transmitted outside your device.',
              textAlign: TextAlign.left,
              style: TextStyle(height: 1.4),
            ),

            SizedBox(height: 12),

            Text(
              'FAQs',
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              '1. Why is a learner missing in summary?\n'
              'Only active learners with saved checklists are included.\n\n'
              '2. Why is my class not in general summary?\n'
              'Archived classes are excluded from active summaries.\n\n'
              '3. Why can\'t CSV export proceed?\n'
              'All required checklist records must be saved first.',
              textAlign: TextAlign.left,
              style: TextStyle(height: 1.4),
            ),

            SizedBox(height: 12),

            Text(
              'Contact Us',
              textAlign: TextAlign.left,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 4),
            Text(
              'For technical support, coordinate with your school or division ECCD focal person.',
              textAlign: TextAlign.left,
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ================= DEVELOPERS GRID =================
  Widget _developersGrid() {
    const devs = [
      ('Jose, Vincent Yuri E.', 'Project Manager'),
      ('Fernandez, Alfred Joaquin', 'System Analyst'),
      ('Amado, Aoyesha Ayen B.', 'Developer'),
      ('Tolentino, Liam Nathan S.', 'Developer'),
      ('Espina, Ericka Joana I.', 'QA Developer'),
      ('Maglalang, Jaz Mare C.', 'QA Developer'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final d in devs)
          Container(
            width: 260,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE6E6E6)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(d.$2, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String? Function(String?)? validator,
  ) {
    return TextFormField(
      controller: c,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    bool initiallyExpanded = false,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        children: [Padding(padding: const EdgeInsets.all(14), child: child)],
      ),
    );
  }

  List<DropdownMenuItem<String>> _regionItems() {
    final opts = <String>{..._regions};

    if ((_selectedRegion ?? '').trim().isNotEmpty) {
      opts.add(_selectedRegion!.trim());
    }

    return opts.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList();
  }

  List<DropdownMenuItem<String>> _divisionItems() {
    final fromRegion = _divisionsByRegion[_selectedRegion] ?? const <String>[];

    final opts = <String>{...fromRegion};

    if ((_selectedDivision ?? '').trim().isNotEmpty) {
      opts.add(_selectedDivision!.trim());
    }

    return opts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList();
  }

  List<DropdownMenuItem<String>> _districtItems() {
    final fromDivision =
        _districtsByDivision[_selectedDivision] ?? const <String>[];

    final opts = <String>{...fromDivision};

    if ((_selectedDistrict ?? '').trim().isNotEmpty) {
      opts.add(_selectedDistrict!.trim());
    }

    return opts.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList();
  }

  Widget _passwordChecklist(String value) {
    Widget item(bool ok, String text) => Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: ok ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: ok ? Colors.green : Colors.grey,
            fontSize: 13,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          item(_hasMinLength(value), 'At least 8 characters'),
          item(_hasUppercase(value), 'Contains uppercase letter'),
          item(_hasLowercase(value), 'Contains lowercase letter'),
          item(_hasNumber(value), 'Contains a number'),
          item(_hasSpecialChar(value), 'Contains special character'),
        ],
      ),
    );
  }
}
