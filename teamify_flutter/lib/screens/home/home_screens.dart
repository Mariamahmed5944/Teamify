import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/models/models.dart' as api;
import '../../models/models.dart';
import '../../widgets/widgets.dart';

class _FreelancerHomeData {
  final List<api.ApiProject> projects;
  final List<api.ApiNotification> notifications;
  final List<api.ApiTask> tasks;
  const _FreelancerHomeData({
    required this.projects,
    required this.notifications,
    required this.tasks,
  });
}

Future<_FreelancerHomeData> _loadFreelancerHome(AppRepositories r) async {
  final projects = await r.projects.listProjects();
  final notifications = await r.notifications.listNotifications();
  final tasks = <api.ApiTask>[];
  for (final p in projects.take(15)) {
    try {
      tasks.addAll(await r.tasks.listTasks(projectId: p.id));
    } catch (_) {}
  }
  return _FreelancerHomeData(
    projects: projects,
    notifications: notifications,
    tasks: tasks,
  );
}

bool _isTaskDone(api.ApiTask t) {
  final s = t.status.toLowerCase();
  return s == 'done' || s == 'complete' || s == 'completed';
}

class FreelancerHomeScreen extends StatelessWidget {
  const FreelancerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RepositoryLoader<_FreelancerHomeData>(
          load: () => _loadFreelancerHome(context.read<AppRepositories>()),
          builder: (context, d) {
            final activeProjects = d.projects
                .where(
                    (p) => p.status.toLowerCase() != 'completed')
                .length;
            final doneTasks = d.tasks.where(_isTaskDone).length;
            final pending = d.tasks.length - doneTasks;

            Widget recentSection;
            if (d.notifications.isEmpty) {
              recentSection = Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No recent activity yet',
                    style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.9),
                        fontSize: 13),
                  ),
                ),
              );
            } else {
              recentSection = Column(
                children: d.notifications.take(12).map((n) {
                  return TCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(n.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                      fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                n.body.isNotEmpty
                                    ? n.body
                                    : 'Notification',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          n.createdAt.isNotEmpty ? n.createdAt : ' ',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(10),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome Back',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        SizedBox(height: 2),
                        Text("Here's your overview for today",
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      ],
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_outlined,
                              color: AppColors.textPrimary, size: 26),
                          onPressed: () =>
                              Navigator.pushNamed(context, R.notifications),
                        ),
                        Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle))),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _miniStat(Icons.access_time_outlined,
                        '$activeProjects', 'Active Projects', AppColors.primary),
                    const SizedBox(width: 12),
                    _miniStat(Icons.check_circle_outline, '$doneTasks',
                        'Tasks Done', AppColors.success),
                    const SizedBox(width: 12),
                    _miniStat(Icons.warning_amber_outlined, '$pending',
                        'Pending', AppColors.warning),
                  ],
                ),
                const SizedBox(height: 6),
                AIBanner(
                  title: 'Daily AI Insight',
                  subtitle:
                      "You're performing 15% better this week. Keep up the great work on Project Alpha!",
                  badge: '↗ +15% improvement',
                  onTap: () => Navigator.pushNamed(context, R.aiInsights),
                ),
                const SizedBox(height: 10),
                const TSectionHeader(title: 'Quick Actions'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _quickAction(context, 'New Task', 'Create quickly',
                          Icons.add_task, AppColors.primary, R.addTask,
                          isDark: true),
                      const SizedBox(width: 12),
                      _quickAction(context, 'Teams', 'Manage groups',
                          Icons.groups_outlined, Colors.white, R.teamsList),
                      const SizedBox(width: 12),
                      _quickAction(
                          context,
                          'Members',
                          'Find experts',
                          Icons.person_search_outlined,
                          Colors.white,
                          R.membersList),
                      const SizedBox(width: 12),
                      _quickAction(context, 'Meetings', 'AI Smart Sync',
                          Icons.videocam_outlined, Colors.white, R.meeting),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const TSectionHeader(title: 'Recent Activity'),
                const SizedBox(height: 12),
                recentSection,
              ],
            );
          },
        ),
      ),
      bottomNavigationBar:
          TBottomNav(current: 0, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: TCard(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(BuildContext context, String title, String sub,
      IconData icon, Color color, String route,
      {bool isDark = false}) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: isDark ? null : Border.all(color: AppColors.border),
          boxShadow: isDark
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isDark ? Colors.white : AppColors.primary, size: 24),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              Text(sub,
                  style: TextStyle(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search Screen ─────────────────────────────────────────────────────────────

class _SearchIndex {
  final List<api.ApiProject> projects;
  final List<api.ApiUser> users;
  final List<(String, String)> tasks;

  const _SearchIndex({
    required this.projects,
    required this.users,
    required this.tasks,
  });
}

Future<_SearchIndex> _fetchSearchIndex(AppRepositories r) async {
  final projects = await r.projects.listProjects();
  final users = await r.search.users('');
  final taskRows = <(String, String)>[];
  for (final p in projects.take(24)) {
    try {
      final tl = await r.tasks.listTasks(projectId: p.id);
      for (final t in tl) {
        taskRows.add((t.title, p.name));
      }
    } catch (_) {}
  }
  return _SearchIndex(projects: projects, users: users, tasks: taskRows);
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '', _tab = 'All';

  Future<_SearchIndex>? _indexFuture;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _indexFuture ??= _fetchSearchIndex(context.read<AppRepositories>());
  }

  void _retryIndex() {
    setState(() {
      _indexFuture = _fetchSearchIndex(context.read<AppRepositories>());
    });
  }

  List<Map<String, dynamic>> _resultsFor(_SearchIndex idx) {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    final r = <Map<String, dynamic>>[];
    if (_tab == 'All' || _tab == 'Projects') {
      for (final p in idx.projects) {
        if (p.name.toLowerCase().contains(q)) {
          r.add({
            'type': 'Project',
            'title': p.name,
            'sub': p.category,
            'icon': Icons.folder_outlined
          });
        }
      }
    }
    if (_tab == 'All' || _tab == 'Teammates') {
      for (final u in idx.users) {
        final name = u.fullName.isNotEmpty ? u.fullName : u.displayName;
        if (name.toLowerCase().contains(q)) {
          r.add({
            'type': 'Person',
            'title': name,
            'sub': u.displayRole,
            'icon': Icons.person_outline
          });
        }
      }
    }
    if (_tab == 'All' || _tab == 'Tasks') {
      for (final row in idx.tasks) {
        final title = row.$1;
        final pname = row.$2;
        if (title.toLowerCase().contains(q)) {
          r.add({
            'type': 'Task',
            'title': title,
            'sub': 'In $pname',
            'icon': Icons.check_circle_outline
          });
        }
      }
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
              hintText: 'Search name or skill...', border: InputBorder.none),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _ctrl.clear();
                  setState(() => _query = '');
                }),
        ],
      ),
      body: FutureBuilder<_SearchIndex>(
        future: _indexFuture,
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
                          'Could not load suggestions.',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                        onPressed: _retryIndex, child: const Text('Retry')),
                  ],
                ),
              ),
            );
          }

          final idx = snapshot.data!;
          final rows = _resultsFor(idx);

          return Column(
            children: [
              Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        ['All', 'Teammates', 'Projects', 'Tasks'].map((t) {
                      final sel = _tab == t;
                      return GestureDetector(
                        onTap: () => setState(() => _tab = t),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    sel ? AppColors.primary : AppColors.border),
                          ),
                          child: Text(t,
                              style: TextStyle(
                                  color: sel
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Expanded(
                child: _query.isEmpty
                    ? _buildSuggestions(idx)
                    : rows.isEmpty
                        ? Center(
                            child: Text('No results for "$_query"',
                                style: const TextStyle(
                                    color: AppColors.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: rows.length,
                            itemBuilder: (_, i) {
                              final r = rows[i];
                              final isPerson = r['type'] == 'Person';
                              final title =
                                  r['title']?.toString() ?? '';
                              return TCard(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    isPerson
                                        ? TAvatar(
                                            initials: title.isEmpty
                                                ? '?'
                                                : title[0].toUpperCase(),
                                            radius: 22)
                                        : Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withOpacity(0.1),
                                                shape: BoxShape.circle),
                                            child: Icon(r['icon'] as IconData,
                                                color: AppColors.primary,
                                                size: 20),
                                          ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(title,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary)),
                                          Text(r['sub']?.toString() ?? '',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors
                                                      .textSecondary)),
                                        ],
                                      ),
                                    ),
                                    if (isPerson)
                                      Column(
                                        children: [
                                          Text('${75 + i * 3}%',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.primary,
                                                  fontSize: 16)),
                                          const Text('match',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors
                                                      .textSecondary)),
                                        ],
                                      )
                                    else
                                      TChip(
                                          label: r['type']?.toString() ?? ''),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar:
          TBottomNav(current: 1, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }

  Widget _buildSuggestions(_SearchIndex idx) {
    if (_tab == 'Projects') {
      if (idx.projects.isEmpty) {
        return const Center(
            child:
                Text('No projects found', style: TextStyle(color: AppColors.textSecondary)));
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TSectionHeader(title: 'Suggested Projects'),
          const SizedBox(height: 12),
          ...idx.projects.map((p) => _projectCard(p.toDisplayModel())),
        ],
      );
    }
    if (_tab == 'Teammates') {
      if (idx.users.isEmpty) {
        return const Center(
            child: Text('No teammates found',
                style: TextStyle(color: AppColors.textSecondary)));
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TSectionHeader(title: 'Recommended Teammates'),
          const SizedBox(height: 12),
          ...idx.users.map((u) => _personCard(u.toDisplayModel())),
        ],
      );
    }
    if (_tab == 'Tasks') {
      final models = idx.tasks.take(20).map((row) {
        return TaskModel(
          id: row.$1.hashCode.toString(),
          title: row.$1,
          assignee: '—',
          assigneeInitials: '?',
          status: '',
          priority: '',
          dueDate: '',
        );
      }).toList();
      if (models.isEmpty) {
        return const Center(
            child: Text('No tasks found yet',
                style: TextStyle(color: AppColors.textSecondary)));
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TSectionHeader(title: 'Suggested Tasks'),
          const SizedBox(height: 12),
          ...models.map((t) => _taskCard(t)),
        ],
      );
    }
    final projectsDm = idx.projects.map((p) => p.toDisplayModel()).toList();
    final usersDm = idx.users.map((u) => u.toDisplayModel()).toList();
    final children = <Widget>[
      const TSectionHeader(title: 'Suggested Projects'),
      const SizedBox(height: 12),
    ];
    if (projectsDm.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text('No projects found',
            style: TextStyle(color: AppColors.textSecondary)),
      ));
    } else {
      children.addAll(projectsDm.take(2).map(_projectCard));
    }
    children.add(const SizedBox(height: 24));
    children.add(const TSectionHeader(title: 'Recommended People'));
    children.add(const SizedBox(height: 12));
    if (usersDm.isEmpty) {
      children.add(const Text('No teammates found yet',
          style: TextStyle(color: AppColors.textSecondary)));
    } else {
      children.addAll(usersDm.take(3).map(_personCard));
    }
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  Widget _projectCard(ProjectModel p) => TCard(
        margin: const EdgeInsets.only(bottom: 10),
        onTap: () =>
            Navigator.pushNamed(context, R.projectDetails, arguments: p),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.folder_outlined,
                    color: AppColors.primary, size: 16)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text(p.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ])),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ],
        ),
      );

  Widget _personCard(UserModel u) => TCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          TAvatar(initials: u.initials, radius: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(u.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text(u.role,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          const Icon(Icons.arrow_forward_ios,
              size: 14, color: AppColors.textSecondary),
        ]),
      );

  Widget _taskCard(TaskModel t) => TCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text('Project task',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          const Icon(Icons.arrow_forward_ios,
              size: 14, color: AppColors.textSecondary),
        ]),
      );
}

// ── Student Home ──────────────────────────────────────────────────────────────
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(10),
          children: [
            const Text('Welcome Back',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Text("Here's your overview for today",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 6),
            // Profile card
            TCard(
                child: Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle),
                  child: const Center(
                      child: Icon(Icons.person_outline,
                          color: AppColors.primary, size: 26))),
              const SizedBox(width: 12),
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ahmed Hassan',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 15)),
                    Row(children: [
                      Icon(Icons.school_outlined,
                          size: 13, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('Cairo University',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))
                    ]),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Text('Cairo, Egypt',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary))
                    ]),
                  ]),
            ])),
            const SizedBox(height: 6),
            // Stats
            Row(children: [
              _stat(Icons.book_outlined, '3', 'Active', AppColors.primary),
              const SizedBox(width: 10),
              _stat(
                  Icons.check_circle_outline, '24', 'Done', AppColors.success),
              const SizedBox(width: 10),
              _stat(Icons.warning_amber_outlined, '8', 'Pending',
                  AppColors.warning),
            ]),
            const SizedBox(height: 6),
            // AI Insight
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.auto_awesome,
                          color: AppColors.primary, size: 18),
                      SizedBox(width: 6),
                      Text('Daily AI Insight',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ]),
                    const SizedBox(height: 6),
                    const Text(
                        "You're improving your productivity this week. Keep going!",
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('↗ +15% improvement',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600))),
                  ]),
            ),
            const SizedBox(height: 10),
            const Text('Quick Actions',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, R.addTask),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF3B6BB3),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('New Task',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Create quickly',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, R.projectDetails),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('View Projects',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 15)),
                        SizedBox(height: 4),
                        Text('See all active',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    Spacer(),
                    Icon(Icons.book_outlined,
                        color: Color(0xFF3B6BB3), size: 26),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, R.search),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Find Teammates',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 15)),
                        SizedBox(height: 4),
                        Text('Join a team',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    Spacer(),
                    Icon(Icons.search,
                        color: Color(0xFF3B6BB3), size: 26),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Recent Activity',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...[
              {
                'icon': Icons.check_circle_outline,
                'color': AppColors.success,
                'title': 'Completed assignment',
                'sub': 'Machine Learning Project - 2 hours ago'
              },
              {
                'icon': Icons.chat_bubble_outline,
                'color': AppColors.primary,
                'title': 'Received feedback',
                'sub': 'Web Development Task - 5 hours ago'
              },
              {
                'icon': Icons.book_outlined,
                'color': const Color(0xFF8B5CF6),
                'title': 'Joined new project',
                'sub': 'Mobile App Development - 1 day ago'
              },
            ].map((a) => TCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: (a['color'] as Color).withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: Icon(a['icon'] as IconData,
                            color: a['color'] as Color, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(a['title'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                  fontSize: 13)),
                          Text(a['sub'] as String,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ])),
                  ]),
                )),
          ],
        ),
      ),
      bottomNavigationBar:
          TBottomNav(current: 0, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) {
    return Expanded(
        child: TCard(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
            ])));
  }
}

// ── Notifications Screen ──────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, String>> _notifs = [
    {
      'title': 'New task assigned',
      'body': 'You have been assigned to "Design homepage mockup"',
      'time': '5 minutes ago',
      'type': 'task'
    },
    {
      'title': 'AI Delay Warning',
      'body': '"Back-end API Integration" has high delay risk (85%)',
      'time': '1 hour ago',
      'type': 'ai'
    },
    {
      'title': 'Deadline approaching',
      'body': 'Final Design Review is due in 2 days',
      'time': '3 hours ago',
      'type': 'deadline'
    },
    {
      'title': 'New message from John Doe',
      'body': 'Great work on the wireframes! Let\'s discuss...',
      'time': '5 hours ago',
      'type': 'message'
    },
    {
      'title': 'Added to Design Team',
      'body': 'You have been added to the Design Team',
      'time': '1 day ago',
      'type': 'team'
    },
    {
      'title': 'New device login',
      'body': 'Login detected from iPhone 13 mini',
      'time': '2 days ago',
      'type': 'security'
    },
    {
      'title': 'Task updated',
      'body': 'Deadline for "Create wireframes" has been extended',
      'time': '3 days ago',
      'type': 'task'
    },
  ];

  bool _allRead = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            const Text('Notifications',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 8),
            if (!_allRead)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('2',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TButton(
              label: _allRead ? 'All Read' : '✓ Mark all as read',
              outline: true,
              onTap: () => setState(() => _allRead = true),
            ),
          ),
          Expanded(
            child: _notifs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 80,
                            color: AppColors.textHint.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        const Text('No Notifications',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const Text("You're all caught up!",
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _notifs.length,
                    itemBuilder: (_, i) {
                      final n = _notifs[i];
                      final type = n['type'];

                      Color iconBg;
                      IconData icon;
                      Color iconColor;

                      switch (type) {
                        case 'task':
                          iconBg = const Color(0xFFEFF6FF);
                          icon = Icons.check_circle_outline;
                          iconColor = AppColors.primary;
                          break;
                        case 'ai':
                          iconBg = const Color(0xFFFEF2F2);
                          icon = Icons.error_outline;
                          iconColor = const Color(0xFFDC2626);
                          break;
                        case 'deadline':
                          iconBg = const Color(0xFFFFFBEB);
                          icon = Icons.calendar_today_outlined;
                          iconColor = const Color(0xFFD97706);
                          break;
                        case 'message':
                          iconBg = const Color(0xFFF0FDF4);
                          icon = Icons.chat_bubble_outline;
                          iconColor = const Color(0xFF16A34A);
                          break;
                        case 'team':
                          iconBg = const Color(0xFFF5F3FF);
                          icon = Icons.people_outline;
                          iconColor = const Color(0xFF7C3AED);
                          break;
                        case 'security':
                          iconBg = const Color(0xFFFEF2F2);
                          icon = Icons.security_outlined;
                          iconColor = const Color(0xFFDC2626);
                          break;
                        default:
                          iconBg = AppColors.primary.withOpacity(0.1);
                          icon = Icons.notifications_none;
                          iconColor = AppColors.primary;
                      }

                      return TCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: iconBg, shape: BoxShape.circle),
                              child: Icon(icon, color: iconColor, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(n['title']!,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                              fontSize: 14)),
                                      if (!_allRead && i < 2)
                                        Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(n['body']!,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text(n['time']!,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textHint)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
