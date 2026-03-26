import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../services/auth_service.dart';
import '../../../services/csv_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_title.dart';

class AdminArchivePage extends StatefulWidget {
  const AdminArchivePage({super.key});

  @override
  State<AdminArchivePage> createState() => _AdminArchivePageState();
}

class _AdminArchivePageState extends State<AdminArchivePage> {
  final _csv = CsvService();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthService>().session;
    if (session == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final adminId = session.userId;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SectionTitle(title: 'My Archive'),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder(
              future: _csv.listAdminSources(adminId, archived: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return const EmptyState(
                    title: 'No archived sources',
                    subtitle: 'Archived sources will appear here.',
                  );
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    final id = s['id'] as int;
                    final level = (s['org_level'] ?? '').toString();
                    final label = (s['label'] ?? '').toString().trim();
                    final displayName = label.isNotEmpty
                        ? label
                        : _sourceKindLabel(level);

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFE6E6E6)),
                      ),
                      child: ListTile(
                        title: Text(displayName),
                        subtitle: Text('SY: ${s['school_year']}'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.maroon,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            await _csv.unarchiveSource(id);
                            setState(() {});
                          },
                          child: const Text('Unarchive'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _sourceKindLabel(String level) {
    switch (level.trim().toLowerCase()) {
      case 'teacher':
        return 'Section';
      case 'school':
        return 'School';
      case 'district':
        return 'District';
      case 'division':
        return 'Division';
      case 'regional':
        return 'Region';
      default:
        return 'Source';
    }
  }
}
