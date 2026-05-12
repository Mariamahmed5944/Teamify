import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/models/models.dart' as api;
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class ProjectDetailsScreen extends StatefulWidget {
  const ProjectDetailsScreen({super.key});
  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabLabels = [
    'Overview',
    'Tasks',
    'Files',
    'Chat',
    'Analytics'
  ];

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: _tabLabels.length, vsync: this, initialIndex: 0);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final p = args is ProjectModel
        ? args
        : args is api.ApiProject
            ? args.toDisplayModel()
            : null;
    if (p == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: AppColors.primary, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No project selected or data is invalid.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.primary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(p.company,
                    style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Overall Process',
                        style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                    Text('${p.progress}%',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                TBar(
                    value: p.progress / 100,
                    height: 6,
                    color: AppColors.primary),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Delay Risk: ',
                        style: TextStyle(
                            fontSize: 15, color: AppColors.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Low Risk',
                          style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Capsule Tabs
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabLabels.length,
              itemBuilder: (context, i) {
                final sel = _tabController.index == i;
                return GestureDetector(
                  onTap: () => setState(() => _tabController.index = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                        child: Text(_tabLabels[i],
                            style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12))),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Tab Content
          Expanded(
            child: Container(
              color: const Color(0xFFF8FAFC),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _OverviewTab(project: p),
                  _TasksTab(project: p),
                  _FilesTab(),
                  _ChatTab(project: p),
                  _AnalyticsTab(project: p),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          TBottomNav(current: 0, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final ProjectModel project;
  const _OverviewTab({required this.project});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _buildCard('Project Summary', [
          _infoRow('Duration', '12/11/2024 - 12/1/2025',
              Icons.calendar_today_outlined),
          _infoRow('Project Owner', 'John Doe', Icons.person_outline),
          const SizedBox(height: 12),
          const Text('Description',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(project.description,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
        ]),
        const SizedBox(height: 8),
        _buildCard(
            'AI Insights',
            [
              _insightRow(
                  '3 tasks at high risk of delay', const Color(0xFFEF4444)),
              _insightRow('75% of milestones completed on time',
                  const Color(0xFF10B981)),
              _insightRow(
                  'Overall delay probability: Medium', const Color(0xFFF59E0B)),
            ],
            icon: Icons.auto_awesome_outlined),
        const SizedBox(height: 8),
        _buildCard(
            'Important Deadlines',
            [
              _deadlineRow('Final Design Review', 'Jan 10, 2025'),
              _deadlineRow('Development Phase Complete', 'Jan 12, 2025'),
            ],
            icon: Icons.notifications_none),
        const SizedBox(height: 8),
        _buildCard(
            'Team Members',
            [
              if (project.members.isEmpty)
                const Text('No team members found',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textSecondary))
              else
                ...project.members.map((member) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          TAvatar(initials: _initials(member), radius: 20),
                          const SizedBox(width: 14),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const Text(
                                  'Member',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ]),
                        ],
                      ),
                    )),
            ],
            icon: Icons.people_outline),
      ],
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return value.isNotEmpty ? value[0].toUpperCase() : '?';
  }

  Widget _buildCard(String title, List<Widget> children, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6)
            ],
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String l, String v, IconData i) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(i, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text('$l: ',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(v,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ]));

  Widget _insightRow(String t, Color c) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 14),
        Expanded(child: Text(t, style: const TextStyle(fontSize: 13))),
      ]));

  Widget _deadlineRow(String t, String d) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        const Icon(Icons.calendar_today_outlined,
            size: 18, color: AppColors.primary),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(d,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Text('Upcoming',
                style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))),
      ]));
}

// ── Tasks Tab ─────────────────────────────────────────────────────────────────
class _TasksTab extends StatelessWidget {
  final ProjectModel project;
  const _TasksTab({required this.project});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.grid_view_rounded,
                    size: 24, color: AppColors.textSecondary)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, R.addTask),
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              label: const Text('Add Task',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(children: [
            _filter('All Status'),
            const SizedBox(width: 12),
            _filter('All People'),
            const SizedBox(width: 12),
            _filter('All Priority'),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: project.tasks.length,
          itemBuilder: (ctx, i) {
            final t = project.tasks[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary)),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: t.status == 'Complete'
                                      ? const Color(0xFFDCFCE7)
                                      : AppColors.primary
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(t.status,
                                  style: TextStyle(
                                      color: t.status == 'Complete'
                                          ? const Color(0xFF16A34A)
                                          : AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold))),
                        ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      TAvatar(initials: t.assigneeInitials, radius: 14),
                      const SizedBox(width: 8),
                      Text(t.assignee,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(t.priority,
                              style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold))),
                    ]),
                  ]),
            );
          },
        )),
      ],
    );
  }

  Widget _filter(String l) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Row(children: [
            Expanded(
                child: Text(l,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis)),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: AppColors.textSecondary)
          ])));
}

// ── Files Tab ─────────────────────────────────────────────────────────────────
class _FilesTab extends StatefulWidget {
  @override
  State<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<_FilesTab> {
  String _selectedFilter = 'ALL';
  final List<String> _filters = [
    'ALL',
    'PDF',
    'FIGMA',
    'IMAGE',
    'SKETCH',
    'DOC'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: const TextField(
              decoration: InputDecoration(
                  hintText: 'Search Files',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search,
                      color: AppColors.textSecondary, size: 18)),
            ),
          ),
        ),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _filters.map((t) {
              final sel = _selectedFilter == t;
              return GestureDetector(
                onTap: () => setState(() => _selectedFilter = t),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: sel ? null : Border.all(color: AppColors.border),
                  ),
                  child: Center(
                      child: Text(t,
                          style: TextStyle(
                              color:
                                  sel ? Colors.white : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Opening file uploader...'),
                    behavior: SnackBarBehavior.floating),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload_file_outlined,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Upload File',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RepositoryLoader<List<api.ApiFile>>(
            load: () => context.read<AppRepositories>().files.listFiles(),
            isEmpty: (files) => files.isEmpty,
            emptyMessage: 'No files found',
            builder: (context, files) {
              final filteredFiles = _filterFiles(files);
              if (filteredFiles.isEmpty) {
                return const Center(
                  child: Text('No files found',
                      style: TextStyle(color: AppColors.textSecondary)),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: filteredFiles.length,
                itemBuilder: (ctx, i) {
                  final f = filteredFiles[i];
                  final color = _getFileColor(f.name);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(_getFileIcon(f.name),
                                    color: color, size: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(f.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary)),
                                  const SizedBox(height: 6),
                                  Text('${f.size} - Dec 18 - ${f.uploadedBy}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500)),
                                ])),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: AppColors.textSecondary),
                              onSelected: (val) {
                                if (val == 'Delete') {
                                  _showDeleteConfirm(context, f.name);
                                } else {
                                  _showEditDialog(context, val, f.name);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                    value: 'Edit', child: Text('Edit')),
                                const PopupMenuItem(
                                    value: 'Rename', child: Text('Rename')),
                                const PopupMenuItem(
                                    value: 'Delete',
                                    child: Text('Delete',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _fileActionBtn(context, 'Download',
                                Icons.download_rounded, f.name,
                                isPrimary: false),
                            const SizedBox(width: 8),
                            _fileActionBtn(
                                context, 'Share', Icons.share_rounded, f.name,
                                isPrimary: true),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<api.ApiFile> _filterFiles(List<api.ApiFile> files) {
    if (_selectedFilter == 'ALL') return files;
    return files.where((f) {
      final n = f.name.toLowerCase();
      final filter = _selectedFilter.toLowerCase();
      if (filter == 'figma') {
        return n.endsWith('.fig') || n.contains('figma');
      }
      if (filter == 'image') {
        return n.endsWith('.png') || n.endsWith('.jpg') || n.contains('image');
      }
      if (filter == 'doc') {
        return n.endsWith('.doc') || n.endsWith('.docx') || n.contains('doc');
      }
      return n.contains(filter);
    }).toList();
  }

  void _showEditDialog(BuildContext context, String action, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action $fileName'),
        content: TextField(
            decoration: InputDecoration(
                hintText: 'Enter new name',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save')),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
            'Are you sure you want to delete "$fileName"? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete')),
        ],
      ),
    );
  }

  IconData _getFileIcon(String n) {
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (n.endsWith('.fig')) return Icons.auto_awesome_motion_rounded;
    if (n.endsWith('.png') || n.endsWith('.jpg')) return Icons.image_rounded;
    if (n.endsWith('.docx') || n.endsWith('.doc')) {
      return Icons.description_rounded;
    }
    if (n.endsWith('.sketch')) return Icons.diamond_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String n) {
    if (n.endsWith('.pdf')) return const Color(0xFFEF4444);
    if (n.endsWith('.fig')) return const Color(0xFFA855F7);
    if (n.endsWith('.png') || n.endsWith('.jpg')) {
      return const Color(0xFF22C55E);
    }
    if (n.endsWith('.docx') || n.endsWith('.doc')) {
      return const Color(0xFF3B82F6);
    }
    if (n.endsWith('.sketch')) return const Color(0xFFF59E0B);
    return AppColors.textSecondary;
  }

  Widget _fileActionBtn(
      BuildContext context, String l, IconData i, String fileName,
      {required bool isPrimary}) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$l in progress for $fileName...'),
              behavior: SnackBarBehavior.floating),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: isPrimary ? null : Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(i,
                size: 10, color: isPrimary ? Colors.white : AppColors.primary),
            const SizedBox(width: 4),
            Text(l,
                style: TextStyle(
                    color: isPrimary ? Colors.white : AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ── Chat Tab ──────────────────────────────────────────────────────────────────
class _ChatTab extends StatelessWidget {
  final ProjectModel project;
  const _ChatTab({required this.project});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(project.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                            color: AppColors.primary)),
                    Text('${project.progress}% progress',
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                TBar(value: project.progress / 100, height: 8),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    const Text('Jan, 15',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('Low Risk',
                            style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 11,
                                fontWeight: FontWeight.bold))),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0))),
            child: const TextField(
              decoration: InputDecoration(
                  hintText: 'Search in Chats',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search,
                      color: AppColors.textSecondary, size: 24)),
            ),
          ),
        ),
        const Expanded(
            child: Center(
                child: Text('Chat messages will appear here',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)))),
      ],
    );
  }
}

// ── Analytics Tab ─────────────────────────────────────────────────────────────
class _AnalyticsTab extends StatelessWidget {
  final ProjectModel project;
  const _AnalyticsTab({required this.project});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _chartCard('Task Completion Rate', _BarChart()),
        const SizedBox(height: 10),
        _chartCard('AI Delay Prediction', _LineChart()),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.file_download_outlined,
              color: Colors.white, size: 22),
          label: const Text('Export Analytics Report',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(double.infinity, 48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _chartCard(String t, Widget c) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary)),
            const SizedBox(height: 12),
            SizedBox(height: 120, child: c),
          ],
        ),
      );
}

class _BarChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
            child: CustomPaint(
                painter: _BarPainter(), child: const SizedBox.expand())),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(AppColors.primary, 'Completed'),
            const SizedBox(width: 20),
            _legendItem(AppColors.border, 'Total'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color c, String l) => Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(l,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold)),
      ]);
}

class _BarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Y-Axis Labels & Grid
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i * (size.height / 4));
      textPainter.text = TextSpan(
          text: '${i * 5}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, Offset(-20, y - 6));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final data = [
      [8, 12],
      [14, 18],
      [10, 14],
      [16, 20]
    ];
    const barW = 18.0;
    final groupW = size.width / 4;

    for (int i = 0; i < 4; i++) {
      final xBase = i * groupW + (groupW / 2) - barW;
      // Primary Bar
      final h1 = (data[i][0] / 20) * size.height;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(xBase, size.height - h1, barW, h1),
              const Radius.circular(4)),
          Paint()..color = AppColors.primary);
      // Secondary Bar
      final h2 = (data[i][1] / 20) * size.height;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(xBase + barW + 4, size.height - h2, barW, h2),
              const Radius.circular(4)),
          Paint()..color = AppColors.border);

      textPainter.text = TextSpan(
          text: 'Week ${i + 1}',
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold));
      textPainter.layout();
      textPainter.paint(canvas, Offset(xBase - 4, size.height + 8));
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

class _LineChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
            child: CustomPaint(
                painter: _LinePainter(), child: const SizedBox.expand())),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendItem(AppColors.primary, 'Actual Progress'),
            const SizedBox(width: 20),
            _legendItem(AppColors.warning, 'Predicted Progress'),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color c, String l) => Row(children: [
        Container(width: 12, height: 2, color: c),
        const SizedBox(width: 6),
        Text(l,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.bold)),
      ]);
}

class _LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintGrid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 0.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i * (size.height / 4));
      textPainter.text = TextSpan(
          text: '${i * 25}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10));
      textPainter.layout();
      textPainter.paint(canvas, Offset(-25, y - 6));
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final actual = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.25, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.55)
    ];
    final predicted = [
      Offset(0, size.height * 0.7),
      Offset(size.width * 0.25, size.height * 0.65),
      Offset(size.width * 0.5, size.height * 0.58),
      Offset(size.width * 0.75, size.height * 0.45),
      Offset(size.width, size.height * 0.3)
    ];

    final paintBlue = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final paintOrange = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(
        Path()
          ..moveTo(actual[0].dx, actual[0].dy)
          ..lineTo(actual[1].dx, actual[1].dy)
          ..lineTo(actual[2].dx, actual[2].dy),
        paintBlue);

    for (int i = 0; i < predicted.length - 1; i++) {
      canvas.drawLine(predicted[i], predicted[i + 1], paintOrange);
    }

    for (var p in actual) {
      canvas.drawCircle(p, 4, Paint()..color = AppColors.primary);
    }
    for (var p in predicted) {
      canvas.drawCircle(p, 4, Paint()..color = AppColors.warning);
    }

    final labels = ['Jan 5', 'Jan 8', 'Jan 10', 'Jan 12', 'Jan 15'];
    for (int i = 0; i < 5; i++) {
      textPainter.text = TextSpan(
          text: labels[i],
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold));
      textPainter.layout();
      textPainter.paint(
          canvas, Offset(i * (size.width / 4) - 10, size.height + 8));
    }
  }

  @override
  bool shouldRepaint(CustomPainter old) => false;
}

// ── Projects List Screen ──────────────────────────────────────────────────────
class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});
  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  late Future<List<ProjectModel>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _loadProjects();
  }

  Future<List<ProjectModel>> _loadProjects() {
    return context.read<AppRepositories>().projects.listProjects().then(
        (items) => items.map((project) => project.toDisplayModel()).toList());
  }

  void _retryProjects() {
    setState(() {
      _projectsFuture = _loadProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  size: 18, color: AppColors.primary),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Projects',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 18)),
          centerTitle: true),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5)),
                    borderRadius: BorderRadius.circular(12)),
                child: const TextField(
                    decoration: InputDecoration(
                        hintText: 'Search Projects...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search,
                            color: AppColors.primary, size: 20))))),
        Expanded(
            child: FutureBuilder<List<ProjectModel>>(
                future: _projectsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              snapshot.error?.toString() ??
                                  'Unable to load projects.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _retryProjects,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final projects = snapshot.data!;
                  if (projects.isEmpty) {
                    return const Center(
                      child: Text('No projects found',
                          style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }
                  return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        ...projects.map((p) => GestureDetector(
                              onTap: () => Navigator.pushNamed(
                                  context, R.projectDetails,
                                  arguments: p),
                              child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.2)),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(p.company,
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary)),
                                              Text('${p.progress}% progress',
                                                  style: const TextStyle(
                                                      fontSize: 11))
                                            ]),
                                        const SizedBox(height: 6),
                                        TBar(value: p.progress / 100),
                                        const SizedBox(height: 12),
                                        Row(children: [
                                          const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 12),
                                          const SizedBox(width: 6),
                                          const Text('Jan, 15',
                                              style: TextStyle(fontSize: 11)),
                                          const Spacer(),
                                          TChip(
                                              label: p.delayRisk,
                                              bg: AppColors.success
                                                  .withValues(alpha: 0.1),
                                              textColor: AppColors.success)
                                        ]),
                                      ])),
                            )),
                        const SizedBox(height: 20),
                        TButton(
                            label: '+ New Project',
                            onTap: () =>
                                Navigator.pushNamed(context, R.addProject)),
                        const SizedBox(height: 30),
                      ]);
                })),
      ]),
      bottomNavigationBar:
          TBottomNav(current: 0, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }
}

// ── Add Task Screen ──────────────────────────────────────────────────────────
class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  String _selectedStatus = 'To Do';
  String _selectedDate = 'Select date';
  String _selectedPriority = 'Medium';
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  final Map<String, Color> _statusColors = {
    'To Do': Colors.blue,
    'In Progress': Colors.orange,
    'Review': Colors.purple,
    'Completed': Colors.green,
    'Blocked': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              size: 18, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add Task',
            style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Task Title'),
              _field('Enter task title', _titleController),
              const SizedBox(height: 16),
              _label('Assignee'),
              _interactiveDrop(context, 'Select assignee', Icons.person,
                  ['Sarah Johnson', 'Ahmed Ali', 'Jessica Chen'], (val) {}),
              const SizedBox(height: 16),
              _label('Due Date'),
              GestureDetector(
                onTap: () => _showDateOptions(context),
                child: _dropField(_selectedDate, Icons.calendar_month),
              ),
              const SizedBox(height: 16),
              _label('Status'),
              GestureDetector(
                onTap: () => _showStatusOptions(context),
                child: _statusDrop(),
              ),
              const SizedBox(height: 16),
              _label('Priority'),
              GestureDetector(
                onTap: () => _showOptions(
                    context,
                    'Priority',
                    ['Low', 'Medium', 'High'],
                    (val) => setState(() => _selectedPriority = val)),
                child: _priorityDrop(),
              ),
              const SizedBox(height: 16),
              _label('Description'),
              _areaField('Enter Project Description', _descController),
              const SizedBox(height: 24),
              TButton(
                  label: 'Create Task', onTap: () => Navigator.pop(context)),
              const SizedBox(height: 12),
              TButton(
                  label: 'Cancel',
                  outline: true,
                  onTap: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 15)),
      );

  Widget _field(String h, TextEditingController ctrl) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12)),
        child: TextField(
            controller: ctrl,
            decoration: InputDecoration(hintText: h, border: InputBorder.none)),
      );

  Widget _interactiveDrop(BuildContext context, String h, IconData? i,
          List<String> options, Function(String) onSelect) =>
      GestureDetector(
        onTap: () => _showOptions(context, h, options, onSelect),
        child: _dropField(h, i),
      );

  void _showOptions(BuildContext context, String title, List<String> options,
      Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 16),
            ...options.map((o) => ListTile(
                  title: Text(o),
                  onTap: () {
                    onSelect(o);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showStatusOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Update Status',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 20),
            ..._statusColors.keys.map((status) {
              final sel = _selectedStatus == status;
              return ListTile(
                leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: _statusColors[status], shape: BoxShape.circle)),
                title: Text(status,
                    style: TextStyle(
                        fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                        color:
                            sel ? AppColors.primary : AppColors.textPrimary)),
                trailing: sel
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _selectedStatus = status);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showDateOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Due Date',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            const SizedBox(height: 20),
            _dateOption(ctx, 'Today', DateTime.now()),
            _dateOption(
                ctx, 'Tomorrow', DateTime.now().add(const Duration(days: 1))),
            _dateOption(
                ctx, 'Next Week', DateTime.now().add(const Duration(days: 7))),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined,
                  color: AppColors.primary),
              title: const Text('Pick Custom Date'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDate =
                      '${picked.day}/${picked.month}/${picked.year}');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateOption(BuildContext ctx, String label, DateTime date) => ListTile(
        leading: const Icon(Icons.calendar_today_outlined,
            color: AppColors.primary, size: 20),
        title: Text(label),
        subtitle: Text('${date.day}/${date.month}/${date.year}'),
        onTap: () {
          setState(
              () => _selectedDate = '${date.day}/${date.month}/${date.year}');
          Navigator.pop(ctx);
        },
      );

  Widget _dropField(String h, IconData? i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            if (i != null) ...[
              Icon(i, size: 18, color: AppColors.primary),
              const SizedBox(width: 10)
            ],
            Text(h,
                style: TextStyle(
                    color: h.contains('/')
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                    fontWeight:
                        h.contains('/') ? FontWeight.w500 : FontWeight.normal)),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
          ],
        ),
      );

  Widget _statusDrop() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: _statusColors[_selectedStatus],
                    shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(_selectedStatus,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
          ],
        ),
      );

  Widget _priorityDrop() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            TChip(
                label: _selectedPriority,
                bg: _selectedPriority == 'High'
                    ? Colors.red
                    : (_selectedPriority == 'Medium'
                        ? AppColors.warning
                        : Colors.blue),
                textColor: Colors.white),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
          ],
        ),
      );

  Widget _areaField(String h, TextEditingController ctrl) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12)),
        child: TextField(
            controller: ctrl,
            maxLines: 4,
            decoration: InputDecoration(hintText: h, border: InputBorder.none)),
      );
}

// ── Add Project Screen ────────────────────────────────────────────────────────
class AddProjectScreen extends StatefulWidget {
  const AddProjectScreen({super.key});
  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  @override
  build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  size: 18, color: AppColors.primary),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Add New Project',
              style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          centerTitle: true),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Project registration form goes here...',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 40),
            SizedBox(
                width: double.infinity,
                child: TButton(
                    label: 'Explore Skill',
                    outline: true,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Exploring new skills...'))))),
            const SizedBox(height: 20),
            TButton(
                label: 'Create Project', onTap: () => Navigator.pop(context)),
          ])),
    );
  }
}
