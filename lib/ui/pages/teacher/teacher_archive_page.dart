import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_title.dart';

class TeacherArchivePage extends StatefulWidget {
  const TeacherArchivePage({super.key});

  @override
  State<TeacherArchivePage> createState() => _TeacherArchivePageState();
}

class _TeacherArchivePageState extends State<TeacherArchivePage> {
  final _classes = ClassService();

  @override
  Widget build(BuildContext context) {
    final teacherId = context.watch<AuthService>().session!.userId;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SectionTitle(title: 'My Archive'),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder(
              future: _classes.listArchivedClasses(teacherId),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final list = snapshot.data!;
                if (list.isEmpty) {
                  return const EmptyState(
                      title: 'No archived classes',
                      subtitle: 'Archived classes will appear here.');
                }
                return ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final c = list[i];
                    final id = c['id'] as int;
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE6E6E6))),
                      child: ListTile(
                        title: Text('Grade ${c['grade']} • ${c['section']}'),
                        subtitle: Text('School Year: ${c['school_year']}'),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.maroon,
                              foregroundColor: Colors.white),
                          onPressed: () async {
                            await _classes.unarchiveClass(id);
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
