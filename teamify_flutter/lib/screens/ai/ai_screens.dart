import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/models/models.dart' as api;
import '../../data/repositories/app_repositories.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';

Future<List<UserModel>> _fetchTeammateRecommendations(
    BuildContext context) async {
  final repos = context.read<AppRepositories>();
  final user = context.read<SessionController>().currentUser;
  final result = await repos.ai.recommendTeammates({
    'user_id': user?.id,
    'skills': user?.skills ?? const <String>[],
  });
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
  return repos.search
      .users('')
      .then((users) => users.map((user) => user.toDisplayModel()).toList());
}

Future<List<Map<String, dynamic>>> _fetchRecommendedCourses(
    BuildContext context) async {
  final userId = context.read<SessionController>().currentUser?.id ?? '';
  if (userId.isEmpty) return const [];
  final result = await context.read<AppRepositories>().ai.mentorCourses(userId);
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
                                            .withOpacity(0.1),
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
  final List<Map<String, dynamic>> _todos = [
    {
      'title': 'Review wireframes',
      'priority': 'High',
      'done': false,
      'project': 'Website Redesign'
    },
    {
      'title': 'Update API docs',
      'priority': 'Medium',
      'done': false,
      'project': 'AI Planner'
    },
    {
      'title': 'Team standup at 10 AM',
      'priority': 'High',
      'done': true,
      'project': 'General'
    },
    {
      'title': 'Code review for PR #42',
      'priority': 'Medium',
      'done': false,
      'project': 'Tech Crop'
    },
    {
      'title': 'Write unit tests',
      'priority': 'Low',
      'done': false,
      'project': 'Website Redesign'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Smart To-Do',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView.builder(
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
          final done = t['done'] as bool;
          return TCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() => _todos[i - 1]['done'] = !done),
                child: Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
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
                            fontSize: 11, color: AppColors.textSecondary)),
                  ])),
              TChip(
                  label: t['priority'] as String,
                  bg: t['priority'] == 'High'
                      ? AppColors.error.withOpacity(0.1)
                      : t['priority'] == 'Medium'
                          ? AppColors.warning.withOpacity(0.1)
                          : AppColors.border,
                  textColor: t['priority'] == 'High'
                      ? AppColors.error
                      : t['priority'] == 'Medium'
                          ? AppColors.warning
                          : AppColors.textSecondary),
            ]),
          );
        },
      ),
    );
  }
}

// ── AI Task Allocation ────────────────────────────────────────────────────────
class AITaskAllocationScreen extends StatelessWidget {
  const AITaskAllocationScreen({super.key});
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
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const AIBanner(
            title: 'AI Allocation Engine',
            subtitle: 'Matching tasks to the best team members'),
        const SizedBox(height: 16),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Model Details',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 16)),
          const SizedBox(height: 12),
          _row('Model', 'Machine Learning'),
          _row('Tools', 'Scikit-learn, Pandas, NumPy'),
          _row('Confidence', '92%'),
          _row('Skills Match', '96%'),
          _row('Active Tasks', '2'),
          _row('Performance', '94%'),
          _row('Workload', 'Balanced'),
        ])),
        const SizedBox(height: 12),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Recommended Assignment',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 16)),
          const SizedBox(height: 12),
          Row(children: [
            const TAvatar(initials: 'AS', radius: 28),
            const SizedBox(width: 14),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Alice Smith',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text('Best match for this task',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ])),
            TChip(
                label: '92%',
                bg: AppColors.success.withOpacity(0.1),
                textColor: AppColors.success,
                fontSize: 16),
          ]),
        ])),
        const SizedBox(height: 16),
        TButton(
            label: 'View Full Result',
            onTap: () => Navigator.pushNamed(context, R.aiSuggestedResult)),
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
  String _priority = 'High';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Set Priority',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Task Priority',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 16)),
                const SizedBox(height: 12),
                ...['High', 'Medium', 'Low'].map((p) {
                  final sel = _priority == p;
                  final c = p == 'High'
                      ? AppColors.error
                      : p == 'Medium'
                          ? AppColors.warning
                          : AppColors.success;
                  return GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: sel ? c.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: sel ? c : AppColors.border,
                              width: sel ? 2 : 1)),
                      child: Row(children: [
                        Icon(Icons.flag, color: c, size: 20),
                        const SizedBox(width: 12),
                        Text(p,
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
              ])),
          const Spacer(),
          TButton(
              label: 'Confirm Priority',
              onTap: () => Navigator.pushNamed(context, R.aiDeadline)),
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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Set Deadline',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const AIBanner(
              title: 'AI Suggestion',
              subtitle:
                  'Based on task complexity and team availability, deadline in 7 days is optimal'),
          const SizedBox(height: 16),
          TCard(
              child: Column(children: [
            const Text('Select Deadline',
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
          ])),
          const Spacer(),
          TButton(
              label: 'Confirm Deadline', onTap: () => Navigator.pop(context)),
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
              bg: AppColors.primary.withOpacity(0.1)),
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
class AIInsightsScreen extends StatelessWidget {
  const AIInsightsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('AI Insights',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ...<Map<String, dynamic>>[
          {
            'title': '↗ +15% Performance',
            'sub': 'You are performing 15% better than last week',
            'color': AppColors.success
          },
          {
            'title': '⚠ 2 Tasks At Risk',
            'sub': 'Frontend components may miss deadline',
            'color': AppColors.warning
          },
          {
            'title': '✓ Workload Balanced',
            'sub': 'Current task distribution is optimal',
            'color': AppColors.primary
          },
        ].map((i) => TCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                        color: i['color'] as Color,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(i['title'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      Text(i['sub'] as String,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ])),
              ]),
            )),
      ]),
    );
  }
}

// ── AI Mentor ─────────────────────────────────────────────────────────────────
class AIMentorScreen extends StatelessWidget {
  const AIMentorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('AI Mentor',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const AIBanner(
            title: 'Your AI Mentor',
            subtitle: 'Personalized guidance based on your progress'),
        const SizedBox(height: 16),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Today\'s Recommendations',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 16)),
          const SizedBox(height: 12),
          ...<Map<String, dynamic>>[
            {
              'icon': Icons.school_outlined,
              'title': 'Learn System Design',
              'sub': 'Next step for senior developer growth'
            },
            {
              'icon': Icons.code,
              'title': 'Practice TypeScript',
              'sub': 'Based on your recent React projects'
            },
            {
              'icon': Icons.people_outline,
              'title': 'Join Code Review',
              'sub': 'Improve code quality skills'
            },
          ].map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(r['icon'] as IconData,
                        color: AppColors.primary, size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(r['title'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 13)),
                      Text(r['sub'] as String,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ])),
              ]))),
        ])),
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
                        color: AppColors.primary.withOpacity(0.1),
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
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> skills = [
      {
        'name': 'Advanced TypeScript',
        'level': 'Intermediate',
        'score': 0.95,
        'desc': 'Based on your React work and code patterns',
        'color': AppColors.primary
      },
      {
        'name': 'System Design',
        'level': 'Advanced',
        'score': 0.88,
        'desc': 'Next step for senior developer growth',
        'color': AppColors.error
      },
      {
        'name': 'GraphQL APIs',
        'level': 'Intermediate',
        'score': 0.82,
        'desc': 'Complement your REST API skills',
        'color': AppColors.success
      },
      {
        'name': 'Performance Optimization',
        'level': 'Advanced',
        'score': 0.78,
        'desc': 'Strengthen your frontend expertise',
        'color': AppColors.warning
      },
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Skills',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const AIBanner(
            title: 'Personalized Recommendations',
            subtitle:
                'Skills selected based on your current performance, projects, and career trajectory'),
        const SizedBox(height: 16),
        const TSectionHeader(
            title: 'Top Skills', action: 'Sorted by relevance'),
        const SizedBox(height: 12),
        ...skills.map((s) => TCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(s['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary))),
                      TChip(
                          label: s['level'] as String,
                          bg: (s['color'] as Color).withOpacity(0.1),
                          textColor: s['color'] as Color),
                    ]),
                    const SizedBox(height: 4),
                    Text(s['desc'] as String,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Text('Relevance Score',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      const Spacer(),
                      Text('↗ ${((s['score'] as double) * 100).toInt()}%',
                          style: TextStyle(
                              fontSize: 12,
                              color: s['color'] as Color,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 4),
                    TBar(
                        value: s['score'] as double,
                        color: s['color'] as Color),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        child: const Text('Explore Skill',
                            style: TextStyle(color: AppColors.textPrimary)),
                      ),
                    ),
                  ]),
            )),
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
  final List<Map<String, dynamic>> _msgs = [
    {
      'isMe': false,
      'text':
          "Hi! I'm your AI Career Mentor. I'm here to help you grow in your career. What would you like to focus on today?",
      'time': '9:41 AM'
    },
  ];

  void _send() {
    if (_ctrl.text.isEmpty) return;
    setState(() {
      _msgs.add({'isMe': true, 'text': _ctrl.text, 'time': 'Now'});
      _ctrl.clear();
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
          padding: const EdgeInsets.all(16),
          itemCount: _msgs.length + (_msgs.length == 1 ? 1 : 0),
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
                                onTap: () => setState(() => _msgs.add({
                                      'isMe': true,
                                      'text': (s['label'] as String)
                                          .replaceAll('\n', ' '),
                                      'time': 'Now'
                                    })),
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
                          decoration: const InputDecoration(
                              hintText: 'Ask your mentor anything...',
                              border: InputBorder.none,
                              isDense: true,
                              hintStyle: TextStyle(
                                  color: AppColors.textHint, fontSize: 13))))),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: _send,
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 18))),
            ])),
      ]),
    );
  }
}
