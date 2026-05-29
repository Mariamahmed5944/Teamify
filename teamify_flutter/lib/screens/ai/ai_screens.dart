import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/models/models.dart' as api;
import '../../services/app_services.dart';
import '../../core/network/api_result.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

Future<List<UserModel>> _fetchTeammateRecommendations(
    BuildContext context) async {
  final services = context.read<AppServices>();
  final user = context.read<SessionController>().currentUser;
  final result = await services.ai
      .recommendTeammates({
        'user_id': user?.id,
        'skills': user?.skills ?? const <String>[],
      })
      .unwrap();
  final raw = result['recommendations'] ??
      result['teammates'] ??
      result['users'] ??
      result['data'];
  if (raw is List && raw.isNotEmpty) {
    return raw
        .whereType<Map>()
        .map((item) => api.ApiUser.fromJson(Map<String, dynamic>.from(item))
            .toDisplayModel())
        .toList();
  }
  return services.search.users('').unwrap().then(
      (users) => users.map((user) => user.toDisplayModel()).toList());
}

Future<List<Map<String, dynamic>>> _fetchRecommendedCourses(
    BuildContext context) async {
  final userId = context.read<SessionController>().currentUser?.id ?? '';
  if (userId.isEmpty) return const [];
  final result =
      await context.read<AppServices>().ai.mentorCourses(userId).unwrap();
  final raw = result['courses'] ??
      result['recommended_courses'] ??
      result['items'] ??
      result['data'];
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

// ── AI Hub ────────────────────────────────────────────────────────────────────
class AIHubScreen extends StatelessWidget {
  const AIHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tools = [
      {
        'icon': Icons.checklist_rounded,
        'title': 'Smart To-Do',
        'sub': 'AI-prioritized tasks',
        'route': R.smartTodo,
        'color': AppColors.primary
      },
      {
        'icon': Icons.people_outline,
        'title': 'Team Recommendation',
        'sub': 'Best fit matching',
        'route': R.teamRecommendation,
        'color': AppColors.accent
      },
      {
        'icon': Icons.auto_awesome,
        'title': 'Task Allocation',
        'sub': 'AI assignment',
        'route': R.aiTaskAllocation,
        'color': const Color(0xFF6366F1)
      },
      {
        'icon': Icons.psychology_outlined,
        'title': 'AI Mentor',
        'sub': 'Personalized guidance',
        'route': R.aiMentor,
        'color': AppColors.success
      },
      {
        'icon': Icons.trending_up,
        'title': 'AI Insights',
        'sub': 'Performance analysis',
        'route': R.aiInsights,
        'color': AppColors.warning
      },
      {
        'icon': Icons.timer_outlined,
        'title': 'Pomodoro',
        'sub': 'Focus timer',
        'route': R.pomodoro,
        'color': Colors.red
      },
      {
        'icon': Icons.school_outlined,
        'title': 'Recommended Courses',
        'sub': 'Learn & grow',
        'route': R.recommendedCourses,
        'color': Colors.purple
      },
      {
        'icon': Icons.bar_chart,
        'title': 'Skills',
        'sub': 'AI skill mapping',
        'route': R.skills,
        'color': Colors.teal
      },
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('AI Hub',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Text('Your AI-powered workspace',
                style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            AIBanner(
                title: 'AI is ready',
                subtitle: 'All systems operational. 3 insights available.',
                onTap: () => Navigator.pushNamed(context, R.aiInsights)),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: tools
                  .map((t) => GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, t['route'] as String),
                        child: TCard(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: (t['color'] as Color)
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Icon(t['icon'] as IconData,
                                        color: t['color'] as Color, size: 22)),
                                const SizedBox(height: 8),
                                Text(t['title'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        fontSize: 13)),
                                Text(t['sub'] as String,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                              ]),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          TBottomNav(current: 2, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }
}

// ── Smart Todo ────────────────────────────────────────────────────────────────
class SmartTodoScreen extends StatefulWidget {
  const SmartTodoScreen({super.key});
  @override
  State<SmartTodoScreen> createState() => _SmartTodoScreenState();
}

class _SmartTodoScreenState extends State<SmartTodoScreen> {
  bool _loading = true;
  String? _error;
  final List<Map<String, dynamic>> _todos = [];
  final Set<int> _done = {};

  static const _priorityOrder = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AppServices>();
      final projectsResult = await svc.projects.listProjects();
      final projects = projectsResult.when(
        success: (list) => list,
        failure: (_) => <dynamic>[],
      );
      final todos = <Map<String, dynamic>>[];
      for (final p in projects.take(5)) {
        final taskRes = await svc.tasks.listTasks(projectId: p.id.toString());
        taskRes.when(
          success: (tasks) {
            for (final t in tasks) {
              todos.add({
                'id': t.id,
                'title': t.title,
                'priority': t.priority.toLowerCase(),
                'project': p.name,
                'status': t.status,
              });
            }
          },
          failure: (_) {},
        );
      }
      todos.sort((a, b) =>
          (_priorityOrder[a['priority']] ?? 3)
              .compareTo(_priorityOrder[b['priority']] ?? 3));
      if (!mounted) return;
      setState(() {
        _todos.clear();
        _todos.addAll(todos);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Color _priorityBg(String p) {
    switch (p) {
      case 'critical': return AppColors.error.withValues(alpha: 0.12);
      case 'high': return AppColors.error.withValues(alpha: 0.1);
      case 'medium': return AppColors.warning.withValues(alpha: 0.1);
      default: return AppColors.border;
    }
  }

  Color _priorityFg(String p) {
    switch (p) {
      case 'critical':
      case 'high': return AppColors.error;
      case 'medium': return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Smart To-Do',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _loading ? null : _load)
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 12),
                    TButton(label: 'Retry', onTap: _load),
                  ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _todos.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: AIBanner(
                              title: 'AI Prioritization',
                              subtitle: 'Tasks sorted by impact and urgency'));
                    }
                    final t = _todos[i - 1];
                    final done = _done.contains(t['id']);
                    final priority = (t['priority'] as String?) ?? 'medium';
                    return TCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => setState(() => done
                              ? _done.remove(t['id'])
                              : _done.add(t['id'] as int)),
                          child: Icon(
                              done
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: done ? AppColors.success : AppColors.border,
                              size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(t['title'] as String,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: done
                                          ? AppColors.textSecondary
                                          : AppColors.textPrimary,
                                      decoration:
                                          done ? TextDecoration.lineThrough : null,
                                      fontSize: 13)),
                              Text(t['project'] as String,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ])),
                        TChip(
                            label: priority[0].toUpperCase() +
                                priority.substring(1),
                            bg: _priorityBg(priority),
                            textColor: _priorityFg(priority)),
                      ]),
                    );
                  },
                ),
    );
  }
}

// ── AI Task Allocation ────────────────────────────────────────────────────────
class AITaskAllocationScreen extends StatefulWidget {
  const AITaskAllocationScreen({super.key});
  @override
  State<AITaskAllocationScreen> createState() => _AITaskAllocationScreenState();
}

class _AITaskAllocationScreenState extends State<AITaskAllocationScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final svc = context.read<AppServices>();
      final result = await svc.ai.classifyTask('Optimize database query for high throughput').unwrap();
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('AI Task Allocation',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const AIBanner(
                      title: 'AI Allocation Engine',
                      subtitle: 'Matching tasks to the best team members'),
                  const SizedBox(height: 16),
                  TCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Model Details',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 16)),
                        const SizedBox(height: 12),
                        _row('Category', _data?['category']?.toString() ?? 'N/A'),
                        _row('Complexity', _data?['complexity']?.toString() ?? 'N/A'),
                        _row('Confidence', '${((_data?['confidence'] as num?)?.toDouble() ?? 0) * 100}%'),
                      ])),
                  const SizedBox(height: 12),
                  TCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Recommended Assignment',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(children: [
                          const TAvatar(initials: 'AI', radius: 28),
                          const SizedBox(width: 14),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(_data?['suggested_assignee']?.toString() ?? 'Auto Assigned',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                                const Text('Best match for this task',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13)),
                              ])),
                          TChip(
                              label: 'Optimal',
                              bg: AppColors.success.withValues(alpha: 0.1),
                              textColor: AppColors.success,
                              fontSize: 12),
                        ]),
                      ])),
                  const SizedBox(height: 16),
                  TButton(
                      label: 'View Full Result',
                      onTap: () =>
                          Navigator.pushNamed(context, R.aiSuggestedResult)),
                ]),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          SizedBox(
              width: 110,
              child: Text(k,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13))),
          Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      fontSize: 13))),
        ]),
      );
}

// ── Suggested Result ──────────────────────────────────────────────────────────
class AISuggestedResultScreen extends StatelessWidget {
  const AISuggestedResultScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('AI Result',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: RepositoryLoader<List<UserModel>>(
        load: () => _fetchTeammateRecommendations(context),
        isEmpty: (users) => users.isEmpty,
        emptyMessage: 'No suggested teammates found',
        builder: (context, users) =>
            ListView(padding: const EdgeInsets.all(16), children: [
          ...users.take(3).map((u) => TCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  TAvatar(initials: u.initials, radius: 24),
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
                        const SizedBox(height: 4),
                        TBar(value: u.rating / 5, color: AppColors.primary),
                      ])),
                  const SizedBox(width: 12),
                  Column(children: [
                    Text('${(u.rating * 20).toInt()}%',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 16)),
                    const Text('match',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ]),
              )),
          const SizedBox(height: 8),
          TButton(
              label: 'View Explanation',
              onTap: () => Navigator.pushNamed(context, R.aiExplanation)),
        ]),
      ),
    );
  }
}

// ── AI Explanation ────────────────────────────────────────────────────────────
class AIExplanationScreen extends StatelessWidget {
  const AIExplanationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('AI Explanation',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const AIBanner(
            title: 'Why Alice Smith?',
            subtitle: 'AI reasoning for this recommendation'),
        const SizedBox(height: 16),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reasoning Factors',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 16)),
          const SizedBox(height: 12),
          ...<Map<String, dynamic>>[
            {
              'label': 'Skills Match',
              'value': 0.96,
              'desc':
                  'Flutter, Dart, Firebase perfectly match task requirements'
            },
            {
              'label': 'Workload',
              'value': 0.85,
              'desc': 'Current workload is balanced with capacity for new tasks'
            },
            {
              'label': 'Performance',
              'value': 0.94,
              'desc': 'Consistently delivers high-quality work on time'
            },
            {
              'label': 'Availability',
              'value': 0.90,
              'desc': 'Available 40+ hours this week'
            },
          ].map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(f['label'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      Text('${((f['value'] as double) * 100).toInt()}%',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold))
                    ]),
                    const SizedBox(height: 4),
                    TBar(value: f['value'] as double),
                    const SizedBox(height: 4),
                    Text(f['desc'] as String,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]))),
        ])),
      ]),
    );
  }
}

// ── AI Priority ───────────────────────────────────────────────────────────────
class AIPriorityScreen extends StatefulWidget {
  const AIPriorityScreen({super.key});
  @override
  State<AIPriorityScreen> createState() => _AIPriorityScreenState();
}

class _AIPriorityScreenState extends State<AIPriorityScreen> {
  String _priority = 'medium';
  bool _suggesting = false;
  List<String> _reasons = [];
  String? _projectId;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProject());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    final svc = context.read<AppServices>();
    final result = await svc.projects.listProjects();
    result.when(
      success: (list) {
        if (list.isNotEmpty && mounted) {
          setState(() => _projectId = list.first.id.toString());
        }
      },
      failure: (_) {},
    );
  }

  Future<void> _suggest() async {
    if (_projectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No project found. Create a project first.')));
      return;
    }
    setState(() { _suggesting = true; _reasons = []; });
    try {
      final svc = context.read<AppServices>();
      final result = await svc.ai.suggestPriority(
        projectId: _projectId!,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      ).unwrap();
      if (!mounted) return;
      final rawPriority = (result['priority'] ?? 'medium').toString().toLowerCase();
      final rawReasons = result['reasons'];
      setState(() {
        _priority = rawPriority;
        _reasons = rawReasons is List
            ? rawReasons.map((e) => e.toString()).toList()
            : [];
        _suggesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _suggesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Color _colorFor(String p) {
    switch (p) {
      case 'critical':
      case 'high': return AppColors.error;
      case 'medium': return AppColors.warning;
      default: return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('AI Priority Suggestion',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Describe your task',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15)),
                const SizedBox(height: 10),
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Task title',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Brief description (optional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _suggesting ? null : _suggest,
                    icon: _suggesting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: Text(_suggesting ? 'Analysing…' : 'Get AI Suggestion'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white),
                  ),
                ),
              ])),
          const SizedBox(height: 16),
          TCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Suggested Priority',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15)),
                const SizedBox(height: 12),
                ...['critical', 'high', 'medium', 'low'].map((p) {
                  final sel = _priority == p;
                  final c = _colorFor(p);
                  return GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: sel ? c.withValues(alpha: 0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? c : AppColors.border,
                              width: sel ? 2 : 1)),
                      child: Row(children: [
                        Icon(Icons.flag, color: c, size: 20),
                        const SizedBox(width: 12),
                        Text(p[0].toUpperCase() + p.substring(1),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sel ? c : AppColors.textPrimary,
                                fontSize: 15)),
                        const Spacer(),
                        if (sel) Icon(Icons.check_circle, color: c)
                      ]),
                    ),
                  );
                }),
                if (_reasons.isNotEmpty) ...[
                  const Divider(),
                  const Text('AI Reasoning:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  ..._reasons.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('• ',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold)),
                          Expanded(
                              child: Text(r,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary))),
                        ]),
                      )),
                ],
              ])),
          const Spacer(),
          TButton(
              label: 'Confirm Priority',
              onTap: () => Navigator.pushNamed(context, R.aiDeadline,
                  arguments: {'priority': _priority, 'project_id': _projectId})),
        ]),
      ),
    );
  }
}

// ── AI Deadline ───────────────────────────────────────────────────────────────
class AIDeadlineScreen extends StatefulWidget {
  const AIDeadlineScreen({super.key});
  @override
  State<AIDeadlineScreen> createState() => _AIDeadlineScreenState();
}

class _AIDeadlineScreenState extends State<AIDeadlineScreen> {
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  bool _loading = true;
  String _bannerSubtitle = 'Fetching AI suggestion…';
  List<String> _reasons = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSuggestion());
  }

  Future<void> _loadSuggestion() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    String priority = 'medium';
    String? projectId;
    if (args is Map) {
      priority = (args['priority'] as String?) ?? 'medium';
      projectId = args['project_id']?.toString();
    }
    if (projectId == null) {
      final svc = context.read<AppServices>();
      final result = await svc.projects.listProjects();
      result.when(
        success: (list) { if (list.isNotEmpty) projectId = list.first.id.toString(); },
        failure: (_) {},
      );
    }
    if (projectId == null || !mounted) {
      setState(() {
        _loading = false;
        _bannerSubtitle = 'No project available. Using default 7-day estimate.';
      });
      return;
    }
    try {
      final svc = context.read<AppServices>();
      final result = await svc.ai.suggestDeadline(
        projectId: projectId!,
        priority: priority,
      ).unwrap();
      if (!mounted) return;
      final dateStr = result['suggested_date']?.toString() ?? '';
      final rawReasons = result['reasons'];
      final parsedDate = DateTime.tryParse(dateStr);
      final reasons = rawReasons is List
          ? rawReasons.map((e) => e.toString()).toList()
          : <String>[];
      setState(() {
        if (parsedDate != null) _date = parsedDate;
        _reasons = reasons;
        _bannerSubtitle = reasons.isNotEmpty
            ? reasons.first
            : 'AI suggests ${_date.day}/${_date.month}/${_date.year} based on priority';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _bannerSubtitle = 'Using default 7-day estimate.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('AI Deadline Suggestion',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          AIBanner(
              title: 'AI Suggestion',
              subtitle: _bannerSubtitle),
          const SizedBox(height: 16),
          TCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Suggested Deadline',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 16)),
                const SizedBox(height: 16),
                CalendarDatePicker(
                    initialDate: _date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onDateChanged: (d) => setState(() => _date = d)),
                if (_reasons.length > 1) ...[
                  const Divider(),
                  const Text('AI Reasoning:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  ..._reasons.skip(1).map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold)),
                              Expanded(
                                  child: Text(r,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary))),
                            ]),
                      )),
                ],
              ])),
          const Spacer(),
          TButton(
              label: 'Confirm Deadline',
              onTap: () => Navigator.pop(context, _date)),
        ]),
      ),
    );
  }
}

// ── Pomodoro ──────────────────────────────────────────────────────────────────
class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});
  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  int _seconds = 25 * 60;
  bool _running = false;
  int _session = 1;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_seconds > 0) {
          setState(() => _seconds--);
        } else {
          _timer?.cancel();
          setState(() {
            _running = false;
            _session++;
            _seconds = 25 * 60;
          });
        }
      });
    } else {
      _timer?.cancel();
    }
  }

  String get _timeStr =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final progress = _seconds / (25 * 60);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Pomodoro Timer',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          TChip(
              label: 'Session $_session',
              bg: AppColors.primary.withValues(alpha: 0.1)),
          const SizedBox(height: 32),
          SizedBox(
              width: 220,
              height: 220,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                    child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 12,
                        backgroundColor: AppColors.border,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary))),
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_timeStr,
                      style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text(_running ? 'Focus' : 'Paused',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              ])),
          const SizedBox(height: 40),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
                onTap: () => setState(() {
                      _timer?.cancel();
                      _running = false;
                      _seconds = 25 * 60;
                    }),
                child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.refresh,
                        color: AppColors.textSecondary))),
            const SizedBox(width: 20),
            GestureDetector(
                onTap: _toggle,
                child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: Icon(_running ? Icons.pause : Icons.play_arrow,
                        color: Colors.white, size: 32))),
            const SizedBox(width: 20),
            GestureDetector(
                onTap: () => setState(() {
                      _timer?.cancel();
                      _running = false;
                      _session++;
                      _seconds = 25 * 60;
                    }),
                child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border)),
                    child: const Icon(Icons.skip_next,
                        color: AppColors.textSecondary))),
          ]),
        ]),
      ),
    );
  }
}

// ── AI Insights ───────────────────────────────────────────────────────────────

double _delayPercentValue(num? raw) {
  if (raw == null) return 0;
  final v = raw.toDouble();
  if (v > 0 && v <= 1) return v * 100;
  return v.clamp(0, 100).toDouble();
}

Color _delayRiskColor(String? risk) {
  switch (risk?.toLowerCase()) {
    case 'high':
      return AppColors.error;
    case 'medium':
      return AppColors.warning;
    case 'low':
      return AppColors.success;
    default:
      return AppColors.textSecondary;
  }
}

String _delayRiskLabel(String? risk) {
  if (risk == null || risk.isEmpty) return 'Unknown';
  return '${risk[0].toUpperCase()}${risk.substring(1).toLowerCase()}';
}

class AIInsightsScreen extends StatefulWidget {
  const AIInsightsScreen({super.key});
  @override
  State<AIInsightsScreen> createState() => _AIInsightsScreenState();
}

class _AIInsightsScreenState extends State<AIInsightsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  List<api.ApiProject> _projects = [];
  String? _selectedProjectId;
  Map<String, String> _taskTitles = {};
  Map<String, dynamic>? _modelStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({String? projectId}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final svc = context.read<AppServices>();

      final projectsResult = await svc.projects.listProjects(forceRefresh: true);
      if (!mounted) return;

      var projects = <api.ApiProject>[];
      projectsResult.when(
        success: (list) => projects = list,
        failure: (e) => throw Exception(e),
      );

      if (projects.isEmpty) {
        setState(() {
          _error =
              'No projects found. Join or create a project to see delay insights.';
          _loading = false;
          _projects = [];
        });
        return;
      }

      final selected =
          projectId ?? _selectedProjectId ?? projects.first.id;

      Map<String, dynamic>? modelStatus;
      final modelResult = await svc.ai.getDelayModelStatus();
      modelResult.when(
        success: (m) => modelStatus = m,
        failure: (_) {},
      );

      final prediction = await svc.ai
          .predictDelay(projectId: selected, forceRefresh: true)
          .unwrap();
      final err = prediction['error']?.toString();
      if (err != null && err.isNotEmpty) {
        throw Exception(err);
      }

      final titles = <String, String>{};
      final tasksResult = await svc.tasks.listTasks(
        projectId: selected,
        forceRefresh: true,
      );
      tasksResult.when(
        success: (tasks) {
          for (final t in tasks) {
            titles[t.id] = t.title;
          }
        },
        failure: (_) {},
      );

      if (!mounted) return;
      setState(() {
        _projects = projects;
        _selectedProjectId = selected;
        _data = prediction;
        _taskTitles = titles;
        _modelStatus = modelStatus;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _onProjectChanged(String? id) {
    if (id == null || id == _selectedProjectId) return;
    _load(projectId: id);
  }

  api.ApiProject? get _selectedProject {
    if (_selectedProjectId == null) return null;
    for (final p in _projects) {
      if (p.id == _selectedProjectId) return p;
    }
    return null;
  }

  Widget _metricCard({
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return TCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskRiskTile(Map<String, dynamic> risk) {
    final taskId = risk['task_id']?.toString() ?? '';
    final apiTitle = risk['task_title']?.toString() ?? '';
    final title = apiTitle.isNotEmpty
        ? apiTitle
        : (_taskTitles[taskId] ??
            (taskId.isNotEmpty ? 'Task #$taskId' : 'Task'));
    final prob = _delayPercentValue(risk['delay_probability'] as num?);
    final level = risk['risk_level']?.toString();
    final mlSource = risk['ml_source']?.toString() ?? '';
    final isMl = mlSource == 'ml_model';
    final reasons = risk['reasons'] as List<dynamic>? ?? [];
    final reasonText =
        reasons.isNotEmpty ? reasons.first.toString() : 'No details';

    return TCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: _selectedProject == null
          ? null
          : () {
              Navigator.pushNamed(
                context,
                R.projectDetails,
                arguments: _selectedProject!.toDisplayModel(),
              );
            },
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: _delayRiskColor(level), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${prob.round()}% · ${_delayRiskLabel(level)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TChip(
                      label: isMl ? 'ML model' : 'Heuristic',
                      bg: isMl
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.background,
                      textColor:
                          isMl ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ],
                ),
                Text(
                  reasonText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final delayPct = _delayPercentValue(_data?['delay_probability'] as num?);
    final riskLevel = _data?['risk_level']?.toString();
    final reasons = (_data?['reasons'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    final taskRisks = (_data?['task_risks'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
      ..sort((a, b) => _delayPercentValue(b['delay_probability'] as num?)
          .compareTo(_delayPercentValue(a['delay_probability'] as num?)));

    final highRiskTasks = taskRisks
        .where((t) =>
            _delayPercentValue(t['delay_probability'] as num?) >= 20)
        .toList();

    final mlSummary = _data?['ml_summary'] as Map<String, dynamic>?;
    final modelAvailable = _modelStatus?['model_available'] == true ||
        mlSummary?['model_available'] == true;
    final mlTasks = (mlSummary?['tasks_scored_with_ml'] as num?)?.toInt() ?? 0;
    final activeTasks = (mlSummary?['active_tasks'] as num?)?.toInt() ??
        taskRisks.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Insights (Delay Prediction)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        TButton(label: 'Retry', onTap: () => _load()),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_projects.isNotEmpty) ...[
                        const Text(
                          'Project',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          key: ValueKey(_selectedProjectId),
                          initialValue: _selectedProjectId,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: _projects
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(
                                    p.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _loading ? null : _onProjectChanged,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Icon(
                              modelAvailable
                                  ? Icons.psychology_outlined
                                  : Icons.info_outline,
                              color: modelAvailable
                                  ? AppColors.primary
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                modelAvailable
                                    ? 'Delay_Predictor.pkl is active — '
                                      'scoring uses live task & member data from the database.'
                                    : 'ML model file not found — using rule-based '
                                      'fallback until Delay_Predictor.pkl is installed.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (modelAvailable && activeTasks > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '$mlTasks of $activeTasks tasks scored with the ML model',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      _metricCard(
                        title: 'Average delay risk',
                        subtitle:
                            '${delayPct.round()}% across active tasks in this project',
                        accent: delayPct >= 40
                            ? AppColors.error
                            : delayPct >= 20
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                      _metricCard(
                        title: 'Overall risk level',
                        subtitle: _delayRiskLabel(riskLevel),
                        accent: _delayRiskColor(riskLevel),
                      ),
                      _metricCard(
                        title: 'Tasks needing attention',
                        subtitle: highRiskTasks.isEmpty
                            ? 'No high-risk active tasks in this project'
                            : '${highRiskTasks.length} task(s) above 20% delay risk',
                        accent: highRiskTasks.isEmpty
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      if (reasons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const TSectionHeader(title: 'Project insights'),
                        const SizedBox(height: 8),
                        ...reasons.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                                Expanded(
                                  child: Text(
                                    r,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (taskRisks.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const TSectionHeader(title: 'Tasks in this project'),
                        const SizedBox(height: 8),
                        ...taskRisks.map(_taskRiskTile),
                      ] else ...[
                        const SizedBox(height: 12),
                        const TCard(
                          child: Text(
                            'No active tasks in this project, or all tasks are completed.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ── AI Mentor ─────────────────────────────────────────────────────────────────
class AIMentorScreen extends StatefulWidget {
  const AIMentorScreen({super.key});
  @override
  State<AIMentorScreen> createState() => _AIMentorScreenState();
}

class _AIMentorScreenState extends State<AIMentorScreen> {
  bool _loading = true;
  String? _error;
  String _summary = '';
  List<String> _nextSteps = [];
  double _careerProgress = 0;

  static const _icons = [Icons.school_outlined, Icons.code, Icons.people_outline, Icons.trending_up];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AppServices>();
      final userId = context.read<SessionController>().currentUser?.id.toString() ?? '';
      if (userId.isEmpty) throw Exception('Not logged in');
      final result = await svc.ai.mentorRecommendations(userId).unwrap();
      if (!mounted) return;
      setState(() {
        _summary = result['career_summary']?.toString() ?? '';
        final raw = result['next_steps'];
        _nextSteps = raw is List ? raw.map((e) => e.toString()).toList() : [];
        _careerProgress = (result['career_path_percentage'] as num?)?.toDouble() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('AI Mentor',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _load)
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 12),
                    TButton(label: 'Retry', onTap: _load),
                  ]))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const AIBanner(
                      title: 'Your AI Mentor',
                      subtitle: 'Personalized guidance based on your progress'),
                  const SizedBox(height: 16),
                  if (_summary.isNotEmpty)
                    TCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Career Summary',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 15)),
                          const SizedBox(height: 8),
                          Text(_summary,
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.textSecondary)),
                          if (_careerProgress > 0) ...[
                            const SizedBox(height: 10),
                            Row(children: [
                              const Text('Career Progress',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              const Spacer(),
                              Text('${_careerProgress.toInt()}%',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 13)),
                            ]),
                            const SizedBox(height: 4),
                            TBar(value: _careerProgress / 100, color: AppColors.primary),
                          ],
                        ])),
                  TCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Recommended Next Steps',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 16)),
                    const SizedBox(height: 12),
                    if (_nextSteps.isEmpty)
                      const Text('No recommendations yet. Complete more tasks to unlock insights.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
                    else
                      ..._nextSteps.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Icon(
                                    _icons[e.key % _icons.length],
                                    color: AppColors.primary,
                                    size: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(e.value,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        fontSize: 13))),
                          ]))),
                  ])),
                  const SizedBox(height: 12),
                  TButton(
                      label: 'Open AI Mentor Chat',
                      onTap: () => Navigator.pushNamed(context, R.aiMentorChat)),
                ]),
    );
  }
}

// ── Team Recommendation ───────────────────────────────────────────────────────
class TeamRecommendationScreen extends StatelessWidget {
  const TeamRecommendationScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Team Recommendation',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: RepositoryLoader<List<UserModel>>(
        load: () => _fetchTeammateRecommendations(context),
        isEmpty: (users) => users.isEmpty,
        emptyMessage: 'No team recommendations found',
        builder: (context, users) =>
            ListView(padding: const EdgeInsets.all(16), children: [
          const AIBanner(
              title: 'AI Team Builder',
              subtitle: 'Optimal team composition for your project'),
          const SizedBox(height: 16),
          ...users.map((u) => TCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  TAvatar(initials: u.initials, radius: 24),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(u.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text(u.skills.take(3).join(', '),
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        TBar(value: u.rating / 5),
                      ])),
                  const SizedBox(width: 12),
                  Column(children: [
                    Text('${(u.rating * 20).toInt()}%',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    const Text('match',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ]),
              )),
        ]),
      ),
    );
  }
}

// ── Recommended Courses ───────────────────────────────────────────────────────
class RecommendedCoursesScreen extends StatelessWidget {
  const RecommendedCoursesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Recommended Courses',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: RepositoryLoader<List<Map<String, dynamic>>>(
        load: () => _fetchRecommendedCourses(context),
        isEmpty: (courses) => courses.isEmpty,
        emptyMessage: 'No recommended courses found',
        builder: (context, courses) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: courses.length,
          itemBuilder: (_, i) {
            final c = courses[i];
            final progress =
                c['progress'] is num ? (c['progress'] as num).toInt() : 0;
            final match = c['match'] is num ? (c['match'] as num).toInt() : 0;
            return TCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.play_circle_outline,
                        color: AppColors.primary, size: 28)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          (c['title'] ?? c['name'] ?? 'Recommended course')
                              .toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      Text((c['platform'] ?? c['provider'] ?? '').toString(),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 6),
                      TBar(value: progress / 100),
                      const SizedBox(height: 2),
                      Text('$progress% complete • $match% match',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primary)),
                    ])),
              ]),
            );
          },
        ),
      ),
    );
  }
}

// ── Skills Screen ─────────────────────────────────────────────────────────────
class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});
  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _skills = [];

  static const _palette = [
    AppColors.primary, AppColors.error, AppColors.success, AppColors.warning,
    Color(0xFF6366F1), Colors.teal, Colors.purple, Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final svc = context.read<AppServices>();
      final userId = context.read<SessionController>().currentUser?.id.toString() ?? '';
      if (userId.isEmpty) throw Exception('Not logged in');
      final result = await svc.ai.mentorInsights(userId).unwrap();
      if (!mounted) return;

      final gaps = result['skill_gaps'];
      final missing = (gaps is Map ? gaps['missing_skills'] : null) ?? result['missing_skills'];
      final weaknesses = result['weaknesses'];
      final strengths = result['strengths'];

      final List<Map<String, dynamic>> skills = [];

      void addList(dynamic raw, String level) {
        if (raw is List) {
          for (final item in raw) {
            final name = item is Map ? (item['name'] ?? item['skill'] ?? item.toString()) : item.toString();
            final score = item is Map ? ((item['score'] as num?)?.toDouble() ?? 0.7) : 0.7;
            skills.add({'name': name.toString(), 'level': level, 'score': score});
          }
        } else if (raw is String && raw.isNotEmpty) {
          for (final s in raw.split(',')) {
            final t = s.trim();
            if (t.isNotEmpty) skills.add({'name': t, 'level': level, 'score': 0.7});
          }
        }
      }

      addList(missing, 'To Learn');
      addList(weaknesses, 'Needs Work');
      addList(strengths, 'Strong');

      setState(() {
        _skills = skills;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Skills',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _loading ? null : _load)
          ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!, style: const TextStyle(color: AppColors.error)),
                    const SizedBox(height: 12),
                    TButton(label: 'Retry', onTap: _load),
                  ]))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const AIBanner(
                      title: 'Personalized Skill Map',
                      subtitle:
                          'Skills selected based on your performance, projects, and career trajectory'),
                  const SizedBox(height: 16),
                  if (_skills.isEmpty)
                    const TCard(
                        child: Text(
                            'Complete more projects and tasks to unlock AI skill insights.',
                            style: TextStyle(color: AppColors.textSecondary)))
                  else ...[
                    const TSectionHeader(title: 'Your Skills', action: 'From AI Analysis'),
                    const SizedBox(height: 12),
                    ..._skills.asMap().entries.map((e) {
                      final s = e.value;
                      final color = _palette[e.key % _palette.length];
                      final score = (s['score'] as double).clamp(0.0, 1.0);
                      final level = s['level'] as String;
                      return TCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(
                                child: Text(s['name'] as String,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary))),
                            TChip(
                                label: level,
                                bg: color.withValues(alpha: 0.1),
                                textColor: color),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Text('Relevance Score',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                            const Spacer(),
                            Text('↗ ${(score * 100).toInt()}%',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 4),
                          TBar(value: score, color: color),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, R.aiMentorChat),
                              style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10))),
                              child: const Text('Ask AI Mentor',
                                  style: TextStyle(color: AppColors.textPrimary)),
                            ),
                          ),
                        ]),
                      );
                    }),
                  ],
                ]),
    );
  }
}

// ── AI Mentor Chat ────────────────────────────────────────────────────────────
class AIMentorChatScreen extends StatefulWidget {
  const AIMentorChatScreen({super.key});
  @override
  State<AIMentorChatScreen> createState() => _AIMentorChatScreenState();
}

class _AIMentorChatScreenState extends State<AIMentorChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;
  final List<Map<String, dynamic>> _msgs = [
    {
      'isMe': false,
      'text':
          "Hi! I'm your AI Career Mentor. I'm here to help you grow in your career. What would you like to focus on today?",
      'time': '9:41 AM'
    },
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _now() {
    final t = DateTime.now();
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _send([String? presetText]) async {
    final text = presetText ?? _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _msgs.add({'isMe': true, 'text': text, 'time': _now()});
      _sending = true;
      if (presetText == null) _ctrl.clear();
    });
    _scrollToBottom();

    try {
      final svc = context.read<AppServices>();
      final history = _msgs
          .where((m) => !(m['isMe'] as bool) || _msgs.indexOf(m) < _msgs.length - 1)
          .map((m) => {
                'role': (m['isMe'] as bool) ? 'user' : 'assistant',
                'content': m['text'] as String,
              })
          .toList();

      final result = await svc.ai.mentorChat(
        question: text,
        history: history.length > 1
            ? history.sublist(0, history.length - 1)
            : const [],
      ).unwrap();

      if (!mounted) return;
      final reply = result.reply.isNotEmpty
          ? result.reply
          : 'I\'m here to help! Could you provide more context?';
      setState(() {
        _msgs.add({'isMe': false, 'text': reply, 'time': _now()});
        _sending = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _msgs.add({
          'isMe': false,
          'text': 'Sorry, I\'m having trouble connecting right now. Please try again.',
          'time': _now()
        });
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      {
        'label': 'What should I focus\non next?',
        'color': const Color(0xFF2D5FA6),
        'icon': Icons.track_changes
      },
      {
        'label': 'How do I get\npromoted?',
        'color': AppColors.success,
        'icon': Icons.trending_up
      },
      {
        'label': 'Recommend courses\nfor me',
        'color': Colors.purple,
        'icon': Icons.menu_book_outlined
      },
      {
        'label': 'Review my skill\ngaps',
        'color': Colors.orange,
        'icon': Icons.code
      },
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: Row(children: [
          Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Mentor',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 15)),
            Row(children: [
              Icon(Icons.circle, color: AppColors.success, size: 8),
              SizedBox(width: 4),
              Text('Online',
                  style: TextStyle(fontSize: 11, color: AppColors.success))
            ]),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
            child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          itemCount: _msgs.length + (_msgs.length == 1 ? 1 : 0) + (_sending ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == 1 && _msgs.length == 1) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Suggested questions:',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: suggestions
                          .map((s) => GestureDetector(
                                onTap: () => _send(
                                    (s['label'] as String).replaceAll('\n', ' ')),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border:
                                          Border.all(color: AppColors.border)),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                                color: s['color'] as Color,
                                                shape: BoxShape.circle),
                                            child: Icon(s['icon'] as IconData,
                                                color: Colors.white, size: 14)),
                                        const SizedBox(height: 8),
                                        Text(s['label'] as String,
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textPrimary,
                                                fontWeight: FontWeight.w500)),
                                      ]),
                                ),
                              ))
                          .toList(),
                    ),
                  ]);
            }
            final offset = (_msgs.length == 1 ? 1 : 0);
            if (_sending && i == _msgs.length + offset) {
              return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            width: 36, height: 36,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 18)),
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(16)),
                            child: const SizedBox(
                                width: 40, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))),
                      ]));
            }
            final m = _msgs[i];
            final isMe = m['isMe'] as bool;
            return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white, size: 18)),
                      if (!isMe) const SizedBox(width: 8),
                      Flexible(
                          child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                            Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: isMe
                                        ? AppColors.primary
                                        : AppColors.background,
                                    borderRadius: BorderRadius.circular(16)),
                                child: Text(m['text'] as String,
                                    style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        fontSize: 14))),
                            const SizedBox(height: 4),
                            Text(m['time'] as String,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary)),
                          ])),
                    ]));
          },
        )),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24)),
                      child: TextField(
                          controller: _ctrl,
                          onSubmitted: (_) => _send(),
                          decoration: const InputDecoration(
                              hintText: 'Ask your mentor anything...',
                              border: InputBorder.none,
                              isDense: true,
                              hintStyle: TextStyle(
                                  color: AppColors.textHint, fontSize: 13))))),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: _sending ? null : _send,
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: _sending ? AppColors.border : AppColors.primary,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 18))),
            ])),
      ]),
    );
  }
}

