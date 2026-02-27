import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';
import '../../../services/csv_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_title.dart';
import '../../../core/constants.dart';

class AdminArchivePage extends StatefulWidget {
  const AdminArchivePage({super.key});

  @override
  State<AdminArchivePage> createState() => _AdminArchivePageState();
}

class _AdminArchivePageState extends State<AdminArchivePage> {
  final _csv = CsvService();

  @override
  Widget build(BuildContext context) {
    final adminId = context.watch<AuthService>().session!.userId;

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
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return const EmptyState(
                      title: 'No archived sources',
                      subtitle: 'Archived sources will appear here.');
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final s = list[i];
                    final id = s['id'] as int;
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE6E6E6))),
                      child: ListTile(
                        title: Text('Source • ${s['org_level']}'),
                        subtitle: Text('SY: ${s['school_year']}'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.maroon,
                              foregroundColor: Colors.white),
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
}
