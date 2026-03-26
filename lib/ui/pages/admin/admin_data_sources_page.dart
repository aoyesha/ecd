import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants.dart';
import '../../../core/nav_no_transition.dart';
import '../../../services/auth_service.dart';
import '../../../services/csv_service.dart';
import '../../widgets/section_title.dart';
import 'admin_add_data_source_page.dart';
import 'admin_data_source_detail_page.dart';

class AdminDataSourcesPage extends StatefulWidget {
  final VoidCallback onSourceImported;

  const AdminDataSourcesPage({super.key, required this.onSourceImported});

  @override
  State<AdminDataSourcesPage> createState() => _AdminDataSourcesPageState();
}

class _AdminDataSourcesPageState extends State<AdminDataSourcesPage> {
  final _csv = CsvService();
  String? schoolYearFilter;

  String _sourceDisplayName(Map<String, Object?> source) {
    final label = (source['label'] ?? '').toString().trim();
    if (label.isNotEmpty) {
      return label;
    }
    return _levelLabel((source['org_level'] ?? '').toString());
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

  Future<void> _openAddSource() async {
    final imported = await navPushNoTransition<bool>(
      context,
      const AdminAddDataSourcePage(),
    );
    if (imported == true && mounted) {
      setState(() {});
      widget.onSourceImported();
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminId = context.watch<AuthService>().session!.userId;
    final isMobile = MediaQuery.of(context).size.width < 700;

    final cardWidth = isMobile ? double.infinity : 260.0;
    final cardHeight = isMobile ? 135.0 : 330.0;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            final dropdown = DropdownButton<String>(
              value: schoolYearFilter,
              hint: const Text('School Year'),
              items: _schoolYearOptions()
                  .map((sy) => DropdownMenuItem(value: sy, child: Text(sy)))
                  .toList(),
              onChanged: (v) => setState(() => schoolYearFilter = v),
            );

            if (!compact) {
              return Row(
                children: [
                  const Expanded(child: SectionTitle(title: 'My Data Sources')),
                  dropdown,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle(title: 'My Data Sources'),
                const SizedBox(height: 8),
                dropdown,
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        Expanded(
          child: FutureBuilder(
            future: _csv.listAdminSources(
              adminId,
              archived: false,
              schoolYear: schoolYearFilter,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final list = snapshot.data!;

              // ================= MOBILE (same as teacher layout) =================
              if (isMobile) {
                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    ...list.map((s) {
                      final id = s['id'] as int;
                      String sy = (s['school_year'] ?? '').toString();

                      if (sy.contains('META') || sy.contains('DATA')) {
                        sy = sy.split('\n').first;
                      }

                      if (sy.contains(',')) {
                        sy = sy.split(',').first;
                      }
                      final level = (s['org_level'] ?? '').toString();
                      String label = (s['label'] ?? '').toString();

                      if (label.contains('META') || label.contains('DATA')) {
                        label = '';
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _NotebookCard(
                          width: double.infinity,
                          height: 135,
                          color: _pastelForSourceId(id),
                          schoolYear: sy,
                          title: _sourceDisplayName(s),
                          subtitle: _sourceKindLabel(level),
                          onTap: () => navPushNoTransition(
                            context,
                            AdminDataSourceDetailPage(
                              sourceId: id,
                              orgLevel: level,
                              schoolYear: sy,
                              label: label,
                            ),
                          ),
                          onArchive: () async {
                            await _csv.archiveSource(id);
                            if (!mounted) return;
                            setState(() {});
                          },
                        ),
                      );
                    }),

                    _AddSourceCard(
                      width: double.infinity,
                      height: 135,
                      onTap: _openAddSource,
                    ),
                  ],
                );
              }

              // ================= DESKTOP GRID =================
              final items = <Widget>[
                ...list.map((s) {
                  final id = s['id'] as int;
                  final sy = (s['school_year'] ?? '').toString();
                  final level = (s['org_level'] ?? '').toString();
                  final label = (s['label'] ?? '').toString();

                  return _NotebookCard(
                    width: cardWidth,
                    height: cardHeight,
                    color: _pastelForSourceId(id),
                    schoolYear: sy,
                    title: _sourceDisplayName(s),
                    subtitle: _sourceKindLabel(level),
                    onTap: () => navPushNoTransition(
                      context,
                      AdminDataSourceDetailPage(
                        sourceId: id,
                        orgLevel: level,
                        schoolYear: sy,
                        label: label,
                      ),
                    ),
                    onArchive: () async {
                      await _csv.archiveSource(id);
                      if (!mounted) return;
                      setState(() {});
                    },
                  );
                }),

                _AddSourceCard(
                  width: cardWidth,
                  height: cardHeight,
                  onTap: _openAddSource,
                ),
              ];

              return SizedBox.expand(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Wrap(spacing: 16, runSpacing: 16, children: items),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _pastelForSourceId(int sourceId) {
    const palette = [
      Color(0xFFE3F2FD),
      Color(0xFFE8F5E9),
      Color(0xFFFFF3E0),
      Color(0xFFF3E5F5),
      Color(0xFFFFEBEE),
      Color(0xFFE0F2F1),
      Color(0xFFFCE4EC),
      Color(0xFFF1F8E9),
    ];
    return palette[sourceId.abs() % palette.length];
  }

  String _levelLabel(String level) {
    if (level.isEmpty) return 'Unknown';
    return level[0].toUpperCase() + level.substring(1).toLowerCase();
  }

  List<String> _schoolYearOptions() {
    return schoolYearRangeOptions(startYear: 2020, yearsFromNow: 10);
  }
}

class _AddSourceCard extends StatelessWidget {
  final double width;
  final double height;
  final VoidCallback onTap;

  const _AddSourceCard({
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Card(
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, size: 40, color: Colors.black38),
                SizedBox(height: 8),
                Text(
                  'New Source',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookCard extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final String schoolYear;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  const _NotebookCard({
    required this.width,
    required this.height,
    required this.color,
    required this.schoolYear,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned(
            left: 6,
            top: 10,
            bottom: 10,
            child: Container(
              width: 24,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),

          Positioned.fill(
            left: 18,
            child: Card(
              color: color,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,

                // ---------- MOBILE LAYOUT ----------
                child: isMobile
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    schoolYear,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Flexible(
                                    child: Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              icon: const Icon(
                                Icons.archive,
                                color: AppColors.maroon,
                              ),
                              onPressed: onArchive,
                              tooltip: "Archive",
                            ),
                          ],
                        ),
                      )
                    // ---------- DESKTOP LAYOUT ----------
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schoolYear.isEmpty
                                  ? 'No School Year'
                                  : schoolYear,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),

                            const Spacer(),

                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.maroon,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: onArchive,
                                icon: const Icon(Icons.archive),
                                label: const Text('Archive'),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
