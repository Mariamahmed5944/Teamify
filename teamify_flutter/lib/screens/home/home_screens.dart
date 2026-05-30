import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../core/network/api_result.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../core/session/session_controller.dart';
import '../../data/models/api_helpers.dart';
import '../../data/models/models.dart' as api;
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';
import '../../core/notifications/notification_actions.dart';
import '../project/project_screens.dart';

Map<String, int> _homeDashboardCounts(Map<String, dynamic> dash) {
  final stats = dash['stats'] as Map<String, dynamic>? ?? {};
  return {
    'activeProjects': (stats['active_projects_count'] as num?)?.toInt() ??
        (stats['accessible_projects_count'] as num?)?.toInt() ??
        0,
    'completed': (stats['completed_tasks'] as num?)?.toInt() ?? 0,
    'inProgress': (stats['in_progress_tasks'] as num?)?.toInt() ?? 0,
  };
}

class FreelancerHomeScreen extends StatefulWidget {
  const FreelancerHomeScreen({super.key});

  @override
  State<FreelancerHomeScreen> createState() => _FreelancerHomeScreenState();
}

class _FreelancerHomeScreenState extends State<FreelancerHomeScreen> {
  int _dashVersion = 0;
  int _notifVersion = 0;
  int _liveUnread = -1;
  StreamSubscription<int>? _unreadSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindUnreadStream());
  }

  @override
  void dispose() {
    _unreadSub?.cancel();
    super.dispose();
  }

  void _bindUnreadStream() {
    _unreadSub ??= context
        .read<AppServices>()
        .notifications
        .unreadCountStream
        .listen((count) {
      if (mounted) setState(() => _liveUnread = count);
    });
  }

  void _bumpHomeData() {
    final userId = context.read<SessionController>().currentUser?.id;
    context.read<AppServices>().home.invalidateDashboard(userId: userId);
    setState(() {
      _dashVersion++;
      _notifVersion++;
    });
  }

  Future<Map<String, dynamic>> _loadDashboard() {
    final userId = context.read<SessionController>().currentUser?.id;
    return context
        .read<AppServices>()
        .home
        .getDashboard(userId: userId, forceRefresh: true)
        .unwrap();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _bumpHomeData();
          },
          child: RepositoryLoader<Map<String, dynamic>>(
            key: ValueKey(_dashVersion),
            load: _loadDashboard,
            builder: (context, dash) {
              final counts = _homeDashboardCounts(dash);
              final atRisk = dash['at_risk_tasks'] as List<dynamic>? ?? [];
              final unread =
                  (dash['unread_notifications'] as num?)?.toInt() ?? 0;
              final badgeUnread = _liveUnread >= 0 ? _liveUnread : unread;
              final activeCount = counts['activeProjects']!;
              final completed = counts['completed']!;
              final inProg = counts['inProgress']!;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                            onPressed: () async {
                              await Navigator.pushNamed(
                                  context, R.notifications);
                              if (!mounted) return;
                              _bumpHomeData();
                            },
                          ),
                          if (badgeUnread > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.red, shape: BoxShape.circle),
                                child: Text(
                                  badgeUnread > 9 ? '9+' : '$badgeUnread',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _miniStat(Icons.access_time_outlined, '$activeCount',
                          'Active Projects', AppColors.primary),
                      const SizedBox(width: 12),
                      _miniStat(Icons.check_circle_outline, '$completed',
                          'Tasks Done', AppColors.success),
                      const SizedBox(width: 12),
                      _miniStat(Icons.flag_outlined, '$inProg', 'In progress',
                          AppColors.warning),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AIBanner(
                    title: 'Workload overview',
                    subtitle: atRisk.isNotEmpty
                        ? '${atRisk.length} tasks flagged as at-risk — review due dates in Tasks.'
                        : 'No at-risk tasks on your latest dashboard sync.',
                    badge: badgeUnread > 0 ? '$badgeUnread unread' : '',
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
                  _HomeRecentActivityList(
                    key: ValueKey(_notifVersion),
                    onUpdated: _bumpHomeData,
                  ),
                ],
              );
            },
          ),
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
                      color: color.withValues(alpha: 0.3),
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

class _TeammateRecommendation {
  final api.ApiUser user;
  final double matchPercent;
  final List<String> highlightSkills;
  final String experienceLevel;

  const _TeammateRecommendation({
    required this.user,
    required this.matchPercent,
    required this.highlightSkills,
    this.experienceLevel = '',
  });
}

// ── Search Screen ─────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '', _tab = 'All';
  List<api.ApiProject> _remoteProjects = const [];
  List<api.ApiUser> _remoteUsers = const [];
  List<api.ApiTask> _remoteTasks = const [];
  Object? _loadError;
  bool _loadingSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  String _projectName(String projectId) {
    if (projectId.isEmpty) return '';
    for (final p in _remoteProjects) {
      if (p.id == projectId) return p.name;
    }
    return '';
  }

  bool _isSearchableTeammate(api.ApiUser u) {
    if (u.id.isEmpty) return false;
    final dn = u.displayName.toLowerCase();
    final email = u.email.toLowerCase();
    if (dn.startsWith('blacklist_') || dn.startsWith('guest')) return false;
    if (email.contains('blacklist') || email.startsWith('guest')) return false;
    return true;
  }

  List<api.ApiUser> get _browsableUsers =>
      _remoteUsers.where(_isSearchableTeammate).toList();

  api.ApiUser? _userById(String id) {
    for (final u in _remoteUsers) {
      if (u.id == id) return u;
    }
    return null;
  }

  Future<void> _showBestRecommendedUsers() async {
    final session = context.read<SessionController>();
    final meId = session.currentUser?.id ?? '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (_, scroll) => FutureBuilder<List<_TeammateRecommendation>>(
          future: _fetchBestRecommendations(meId),
          builder: (context, snap) {
            final recs = snap.data ?? const [];
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Best recommended teammates',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'AI-ranked by skills, experience & performance',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snap.hasError)
                  TCard(
                    child: Text(
                      snap.error.toString().replaceFirst('Exception: ', ''),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  )
                else if (recs.isEmpty)
                  const TCard(
                    child: Text(
                      'No recommendations yet. Add skills to your profile and complete tasks to improve matches.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...recs.map((r) => _bestRecommendCard(r)),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<List<_TeammateRecommendation>> _fetchBestRecommendations(
    String meId,
  ) async {
    final session = context.read<SessionController>();
    final skills = session.currentUser?.skills ?? const <String>[];
    final result = await context.read<AppServices>().ai.recommendTeammates({
      'user_id': meId,
      'skills': skills,
    }, topN: 5).unwrap();

    final raw = result['recommendations'] ??
        result['teammates'] ??
        result['users'] ??
        result['data'];
    if (raw is! List) return const [];

    final out = <_TeammateRecommendation>[];
    for (final item in raw.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final uid = map['user_id']?.toString() ?? '';
      if (uid.isEmpty || uid == meId) continue;

      final existing = _userById(uid);
      final user = existing ??
          api.ApiUser.fromJson({
            'id': uid,
            'display_name': map['display_name'],
            'full_name': map['full_name'],
            'user_type': map['user_type'],
            'professional_field': map['professional_field'],
            'experience_level': map['experience_level'],
            'skills': map['skills'],
          });
      if (!_isSearchableTeammate(user)) continue;

      final score = (map['match_percent'] as num?)?.toDouble() ??
          ((map['similarity_score'] as num?)?.toDouble() ?? 0) * 100;
      final recSkills = (map['skills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList() ??
          user.skills;

      out.add(_TeammateRecommendation(
        user: user,
        matchPercent: score.clamp(0, 100),
        highlightSkills: recSkills.take(6).toList(),
        experienceLevel: map['experience_level']?.toString() ?? '',
      ));
    }
    return out;
  }

  Widget _aiBestPicksBanner() {
    return TCard(
      margin: const EdgeInsets.only(bottom: 16),
      onTap: _showBestRecommendedUsers,
      color: AppColors.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'See best AI teammate picks',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Tap for top matches based on your profile',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_up, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _bestRecommendCard(_TeammateRecommendation rec) {
    final u = rec.user;
    return TCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () {
        Navigator.pop(context);
        _showTeammateProfile(u);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TAvatar(initials: u.initials, radius: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.primaryName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      u.displayRole,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${rec.matchPercent.round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'match',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (rec.highlightSkills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: rec.highlightSkills
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (rec.experienceLevel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                rec.experienceLevel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTeammateProfile(api.ApiUser u) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        builder: (_, scroll) => FutureBuilder<api.ApiUser?>(
          future: context
              .read<AppServices>()
              .users
              .getPublicProfile(u.id)
              .then((r) => r.data),
          builder: (context, snap) {
            final p = snap.data ?? u;
            final handle = p.displayName.isNotEmpty &&
                    p.displayName.toLowerCase() != 'user'
                ? '@${p.displayName}'
                : null;

            return ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TAvatar(initials: p.initials, radius: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.primaryName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (handle != null)
                            Text(
                              handle,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          const SizedBox(height: 6),
                          TChip(label: p.displayRole),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (p.bio.isNotEmpty) ...[
                    _profileSectionTitle('About'),
                    _profileInfoRow(Icons.info_outline, 'Bio', p.bio),
                  ],
                  _profileSectionTitle('Skills'),
                  _profileSkillsSection(p.skills),
                  _profileSectionTitle('Profile'),
                  _profileInfoRow(
                    Icons.person_outline,
                    'Account type',
                    p.userType.isNotEmpty
                        ? p.userType[0].toUpperCase() + p.userType.substring(1)
                        : p.displayRole,
                  ),
                  if (p.professionalField.isNotEmpty)
                    _profileInfoRow(
                      Icons.category_outlined,
                      'Professional field',
                      p.professionalField,
                    ),
                  if (p.experienceLevel.isNotEmpty)
                    _profileInfoRow(
                      Icons.trending_up,
                      'Experience level',
                      p.experienceLevel,
                    ),
                  if (p.availability.isNotEmpty)
                    _profileInfoRow(
                      Icons.schedule_outlined,
                      'Availability',
                      p.availability,
                    ),
                  if (p.memberExperienceYears > 0)
                    _profileInfoRow(
                      Icons.history,
                      'Years of experience',
                      '${p.memberExperienceYears}',
                    ),
                  if (p.isStudent) ...[
                    _profileSectionTitle('Education'),
                    if (p.major.isNotEmpty)
                      _profileInfoRow(
                        Icons.school_outlined,
                        'Major',
                        p.major,
                      ),
                    if (p.currentLevel.isNotEmpty)
                      _profileInfoRow(
                        Icons.grade_outlined,
                        'Current level',
                        p.currentLevel,
                      ),
                    if (p.lookingForTeam != null)
                      _profileInfoRow(
                        Icons.group_add_outlined,
                        'Looking for team',
                        p.lookingForTeam! ? 'Yes' : 'No',
                      ),
                  ],
                  if (p.reasonForJoining.isNotEmpty)
                    _profileInfoRow(
                      Icons.flag_outlined,
                      'Reason for joining',
                      p.reasonForJoining,
                    ),
                  if (p.tasksCompleted > 0 ||
                      p.qualityScore > 0 ||
                      p.attendanceRate > 0 ||
                      p.memberOnTimeRate > 0) ...[
                    _profileSectionTitle('Performance'),
                    if (p.tasksCompleted > 0)
                      _profileInfoRow(
                        Icons.task_alt_outlined,
                        'Tasks completed',
                        '${p.tasksCompleted}',
                      ),
                    if (p.qualityScore > 0)
                      _profileInfoRow(
                        Icons.star_outline,
                        'Quality score',
                        '${(p.qualityScore * 5).toStringAsFixed(1)} / 5',
                      ),
                    if (p.attendanceRate > 0)
                      _profileInfoRow(
                        Icons.event_available_outlined,
                        'Attendance rate',
                        '${(p.attendanceRate * 100).round()}%',
                      ),
                    if (p.memberOnTimeRate > 0)
                      _profileInfoRow(
                        Icons.timer_outlined,
                        'On-time rate',
                        '${(p.memberOnTimeRate * 100).round()}%',
                      ),
                  ],
                  if (p.joinedAt.isNotEmpty)
                    _profileInfoRow(
                      Icons.calendar_today_outlined,
                      'Member since',
                      p.joinedAt.length >= 10
                          ? p.joinedAt.substring(0, 10)
                          : p.joinedAt,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _profileSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _profileSkillsSection(List<String> skills) {
    if (skills.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'No skills listed yet.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: skills
            .map(
              (skill) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _profileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTaskDetail(api.ApiTask task) async {
    if (task.id.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc = context.read<AppServices>();
      final taskResult = await svc.tasks.getTask(task.id);
      if (!mounted) return;
      await taskResult.when(
        success: (fullTask) async {
          final pid = fullTask.projectId.isNotEmpty
              ? fullTask.projectId
              : task.projectId;
          if (pid.isEmpty) {
            messenger.showSnackBar(
              const SnackBar(content: Text('Task has no linked project.')),
            );
            return;
          }
          final projectResult = await svc.projects.getProject(pid);
          if (!mounted) return;
          await projectResult.when(
            success: (project) async {
              final userId =
                  context.read<SessionController>().currentUser?.id ?? '';
              final isOwner =
                  project.ownerId.isNotEmpty && project.ownerId == userId;
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => TaskDetailScreen(
                    initialTask: fullTask.toDisplayModel(),
                    projectId: pid,
                    isOwner: isOwner,
                  ),
                ),
              );
            },
            failure: (e) {
              messenger.showSnackBar(
                SnackBar(content: Text(e), backgroundColor: AppColors.error),
              );
            },
          );
        },
        failure: (e) {
          messenger.showSnackBar(
            SnackBar(content: Text(e), backgroundColor: AppColors.error),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _loadError = null;
    });
    try {
      final services = context.read<AppServices>();
      final results = await Future.wait([
        services.search.projects('').unwrap(),
        services.search.users('').unwrap(),
      ]);
      final projects = results[0] as List<api.ApiProject>;
      final users = results[1] as List<api.ApiUser>;

      final allTasks = <api.ApiTask>[];
      if (projects.isNotEmpty) {
        final taskResults = await Future.wait(
          projects.map(
            (p) => services.tasks.listTasks(
              projectId: p.id,
              forceRefresh: false,
            ),
          ),
        );
        for (final r in taskResults) {
          r.when(
            success: (tasks) => allTasks.addAll(tasks),
            failure: (_) {},
          );
        }
        allTasks.sort((a, b) {
          final ad = a.dueDate;
          final bd = b.dueDate;
          if (ad.isEmpty && bd.isEmpty) return a.title.compareTo(b.title);
          if (ad.isEmpty) return 1;
          if (bd.isEmpty) return -1;
          return ad.compareTo(bd);
        });
      }

      if (!mounted) return;
      setState(() {
        _remoteProjects = projects;
        _remoteUsers = users;
        _remoteTasks = allTasks;
        _loadError = null;
        _loadingSuggestions = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loadingSuggestions = false;
      });
    }
  }

  List<Map<String, dynamic>> get _results {
    if (_query.isEmpty) return [];
    final q = _query.toLowerCase();
    final r = <Map<String, dynamic>>[];
    if (_tab == 'All' || _tab == 'Projects') {
      for (final p in _remoteProjects) {
        if (p.name.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q)) {
          r.add({
            'type': 'Project',
            'title': p.name,
            'sub': p.category,
            'icon': Icons.folder_outlined,
            'project': p,
          });
        }
      }
    }
    if (_tab == 'All' || _tab == 'Teammates') {
      for (final u in _browsableUsers) {
        final name = u.primaryName;
        final skills = u.skills.join(' ').toLowerCase();
        if (name.toLowerCase().contains(q) ||
            u.displayName.toLowerCase().contains(q) ||
            u.professionalField.toLowerCase().contains(q) ||
            skills.contains(q)) {
          r.add({
            'type': 'Person',
            'title': name,
            'sub': u.displayRole,
            'icon': Icons.person_outline,
            'user': u,
          });
        }
      }
    }
    if (_tab == 'All' || _tab == 'Tasks') {
      for (final t in _remoteTasks) {
        if (t.title.toLowerCase().contains(q) ||
            t.description.toLowerCase().contains(q) ||
            t.status.toLowerCase().contains(q)) {
          final projectName = _projectName(t.projectId);
          r.add({
            'type': 'Task',
            'title': t.title,
            'sub': projectName.isNotEmpty
                ? 'In $projectName'
                : (t.status.isNotEmpty ? t.status : 'Task'),
            'icon': Icons.check_circle_outline,
            'task': t,
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
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Teammates', 'Projects', 'Tasks'].map((t) {
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
                            color: sel ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(t,
                          style: TextStyle(
                              color:
                                  sel ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Unable to load search data: $_loadError',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          TextButton(
                              onPressed: _loadSuggestions,
                              child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : _loadingSuggestions
                    ? const Center(child: CircularProgressIndicator())
                    : _query.isEmpty
                        ? _buildSuggestions()
                        : _results.isEmpty
                            ? Center(
                                child: Text('No results for "$_query"',
                                    style: const TextStyle(
                                        color: AppColors.textSecondary)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _results.length,
                                itemBuilder: (_, i) {
                                  final r = _results[i];
                                  final isPerson = r['type'] == 'Person';
                                  final task = r['task'] as api.ApiTask?;
                                  final user = r['user'] as api.ApiUser?;
                                  final project =
                                      r['project'] as api.ApiProject?;
                                  return TCard(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    onTap: task != null
                                        ? () => _openTaskDetail(task)
                                        : user != null
                                            ? () => _showTeammateProfile(user)
                                            : project != null
                                                ? () => Navigator.pushNamed(
                                                      context,
                                                      R.projectDetails,
                                                      arguments: project
                                                          .toDisplayModel(),
                                                    )
                                                : null,
                                    child: Row(
                                      children: [
                                        isPerson
                                            ? TAvatar(
                                                initials: user?.initials ??
                                                    (r['title'] as String)[0],
                                                radius: 22)
                                            : Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.1),
                                                    shape: BoxShape.circle),
                                                child: Icon(
                                                    r['icon'] as IconData,
                                                    color: AppColors.primary,
                                                    size: 20),
                                              ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(r['title'],
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors
                                                          .textPrimary)),
                                              Text(r['sub'],
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors
                                                          .textSecondary)),
                                            ],
                                          ),
                                        ),
                                        TChip(
                                            label:
                                                isPerson ? 'User' : r['type']),
                                      ],
                                    ),
                                  );
                                },
                              ),
          ),
        ],
      ),
      bottomNavigationBar:
          TBottomNav(current: 1, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }

  Widget _buildSuggestions() {
    if (_tab == 'Projects') {
      final projects = _remoteProjects.map((p) => p.toDisplayModel()).toList();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TSectionHeader(title: 'Suggested Projects'),
          const SizedBox(height: 12),
          ...projects.map((p) => _projectCard(p)),
        ],
      );
    } else if (_tab == 'Teammates') {
      final users = _browsableUsers;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _aiBestPicksBanner(),
          const TSectionHeader(title: 'Recommended Teammates'),
          const SizedBox(height: 12),
          if (users.isEmpty)
            const TCard(
              child: Text(
                'No teammates to show yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...users.map(_personCard),
        ],
      );
    } else if (_tab == 'Tasks') {
      final suggested = _remoteTasks.take(10).toList();
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TSectionHeader(title: 'Suggested Tasks'),
          const SizedBox(height: 12),
          if (suggested.isEmpty)
            const TCard(
              child: Text(
                'No tasks yet. Create tasks in your projects to see them here.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...suggested.map(_taskCard),
        ],
      );
    } else {
      // 'All' tab
      final projects = _remoteProjects.map((p) => p.toDisplayModel()).toList();
      final users = _browsableUsers;
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TSectionHeader(title: 'Suggested Projects'),
          const SizedBox(height: 12),
          ...projects.take(2).map((p) => _projectCard(p)),
          const SizedBox(height: 24),
          _aiBestPicksBanner(),
          const TSectionHeader(title: 'Recommended People'),
          const SizedBox(height: 12),
          ...users.take(3).map(_personCard),
        ],
      );
    }
  }

  Widget _projectCard(dynamic p) => TCard(
        margin: const EdgeInsets.only(bottom: 10),
        onTap: () =>
            Navigator.pushNamed(context, R.projectDetails, arguments: p),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
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

  Widget _personCard(api.ApiUser u) => TCard(
        margin: const EdgeInsets.only(bottom: 10),
        onTap: () => _showTeammateProfile(u),
        child: Row(
          children: [
            TAvatar(initials: u.initials, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    u.primaryName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    u.displayRole,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (u.skills.isNotEmpty)
                    Text(
                      u.skillsSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      );

  Widget _taskCard(api.ApiTask t) {
    final projectName = _projectName(t.projectId);
    final due = t.dueDate.isNotEmpty ? 'Due: ${t.dueDate}' : 'No due date';
    final sub = projectName.isNotEmpty
        ? '$due · $projectName'
        : (t.status.isNotEmpty ? '$due · ${t.status}' : due);

    return TCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => _openTaskDetail(t),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ── Student Home ──────────────────────────────────────────────────────────────
class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.currentUser;
    final displayName = user?.fullName ?? user?.displayName ?? 'Student';

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
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: const Center(
                      child: Icon(Icons.person_outline,
                          color: AppColors.primary, size: 26))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15)),
                Row(children: [
                  const Icon(Icons.school_outlined,
                      size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(user?.email ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary))
                ]),
              ]),
            ])),
            const SizedBox(height: 6),
            RepositoryLoader<Map<String, dynamic>>(
              load: () {
                final userId =
                    context.read<SessionController>().currentUser?.id;
                return context
                    .read<AppServices>()
                    .home
                    .getDashboard(userId: userId, forceRefresh: true)
                    .unwrap();
              },
              builder: (context, dash) {
                final counts = _homeDashboardCounts(dash);
                final atRisk = dash['at_risk_tasks'] as List<dynamic>? ?? [];
                final activeCount = counts['activeProjects']!;
                final completed = counts['completed']!;
                final inProg = counts['inProgress']!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      _stat(Icons.book_outlined, '$activeCount', 'Active',
                          AppColors.primary),
                      const SizedBox(width: 10),
                      _stat(Icons.check_circle_outline, '$completed', 'Done',
                          AppColors.success),
                      const SizedBox(width: 10),
                      _stat(Icons.flag_outlined, '$inProg', 'Active tasks',
                          AppColors.warning),
                    ]),
                    const SizedBox(height: 6),
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
                            Text('Workload pulse',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                            atRisk.isNotEmpty
                                ? '${atRisk.length} tasks may need attention soon.'
                                : 'No at-risk tasks detected on your latest sync.',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
                          color: Colors.white.withValues(alpha: 0.2),
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
                    Icon(Icons.search, color: Color(0xFF3B6BB3), size: 26),
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
            const _HomeRecentActivityList(),
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
  List<api.ApiNotification> _notifications = [];
  bool _loading = true;
  String? _error;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await context
          .read<AppServices>()
          .notifications
          .listNotifications(forceRefresh: true)
          .unwrap();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _markReadLocally(String id) {
    setState(() {
      _notifications = _notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList();
    });
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAll = true);
    try {
      await context.read<AppServices>().notifications.markAllRead().unwrap();
      if (!mounted) return;
      setState(() {
        _notifications =
            _notifications.map((n) => n.copyWith(isRead: true)).toList();
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update notifications: $e')),
      );
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

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
        title: const Text('Notifications',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.textPrimary)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TButton(
              label: _markingAll ? 'Updating…' : '✓ Mark all as read',
              outline: true,
              onTap: _markingAll ? null : _markAllRead,
            ),
          ),
          Expanded(
            child: _loading && _notifications.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _notifications.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: _load,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _notifications.isEmpty
                        ? const Center(
                            child: Text(
                              "You're all caught up! No notifications.",
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _notifications.length,
                            itemBuilder: (_, i) {
                              final n = _notifications[i];

                    Color iconBg;
                    IconData icon;
                    Color iconColor;
                    final titleLower = n.title.toLowerCase();

                    if (titleLower.contains('task') ||
                        titleLower.contains('assigned')) {
                      iconBg = const Color(0xFFEFF6FF);
                      icon = Icons.check_circle_outline;
                      iconColor = AppColors.primary;
                    } else if (titleLower.contains('ai') ||
                        titleLower.contains('delay') ||
                        titleLower.contains('warning')) {
                      iconBg = const Color(0xFFFEF2F2);
                      icon = Icons.error_outline;
                      iconColor = const Color(0xFFDC2626);
                    } else if (titleLower.contains('deadline') ||
                        titleLower.contains('due')) {
                      iconBg = const Color(0xFFFFFBEB);
                      icon = Icons.calendar_today_outlined;
                      iconColor = const Color(0xFFD97706);
                    } else if (titleLower.contains('message') ||
                        titleLower.contains('chat')) {
                      iconBg = const Color(0xFFF0FDF4);
                      icon = Icons.chat_bubble_outline;
                      iconColor = const Color(0xFF16A34A);
                    } else if (titleLower.contains('team') ||
                        titleLower.contains('added')) {
                      iconBg = const Color(0xFFF5F3FF);
                      icon = Icons.people_outline;
                      iconColor = const Color(0xFF7C3AED);
                    } else if (titleLower.contains('security') ||
                        titleLower.contains('login') ||
                        titleLower.contains('device')) {
                      iconBg = const Color(0xFFFEF2F2);
                      icon = Icons.security_outlined;
                      iconColor = const Color(0xFFDC2626);
                    } else {
                      iconBg = AppColors.primary.withValues(alpha: 0.1);
                      icon = Icons.notifications_none;
                      iconColor = AppColors.primary;
                    }

                    return TCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      onTap: () => handleNotificationTap(
                        context,
                        n,
                        onMarkReadLocally: _markReadLocally,
                        onUpdated: _load,
                      ),
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
                                    Expanded(
                                      child: Text(n.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                              fontSize: 14)),
                                    ),
                                    if (!n.isRead)
                                      Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(n.body,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                if (n.createdAt.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(formatRelativeTime(n.createdAt),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textHint)),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 20, color: AppColors.textHint),
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

/// Recent notifications on the home dashboard (tap opens task details when linked).
class _HomeRecentActivityList extends StatelessWidget {
  const _HomeRecentActivityList({super.key, this.onUpdated});

  final VoidCallback? onUpdated;

  static const double _maxHeight = 180;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _maxHeight,
      child: RepositoryLoader<List<api.ApiNotification>>(
        load: () => context
            .read<AppServices>()
            .notifications
            .listNotifications(forceRefresh: true)
            .unwrap(),
        isEmpty: (items) => items.isEmpty,
        emptyMessage: 'No recent notifications',
        builder: (context, items) => ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length > 3 ? 3 : items.length,
          itemBuilder: (_, i) {
            final a = items[i];
            return TCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => handleNotificationTap(
                context,
                a,
                onUpdated: onUpdated,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          a.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        a.createdAt.isNotEmpty
                            ? formatRelativeTime(a.createdAt)
                            : '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
