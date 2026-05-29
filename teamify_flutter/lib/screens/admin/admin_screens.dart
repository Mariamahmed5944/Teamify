export 'admin_dashboard_screen.dart';
export 'admin_projects_screen.dart';
export 'admin_tasks_screen.dart';
export 'admin_ai_screen.dart';
export 'admin_disputes_screen.dart';
export 'admin_notifications_screen.dart';
export 'admin_files_screen.dart';
export 'admin_logs_screen.dart';
export 'admin_security_screen.dart';
export 'admin_settings_screen.dart';

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/files/file_downloader.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../core/network/api_result.dart';
import '../../data/models/api_helpers.dart';
import '../../data/models/models.dart' as api;
import '../../models/models.dart';
import '../../core/cache/cache_manager.dart';
import '../../core/session/session_controller.dart';
import '../../services/app_services.dart';
import '../../services/ai_service.dart';
import '../../widgets/widgets.dart';

// ── Admin Bottom Nav ──────────────────────────────────────────────────────────
class _AdminBottomNav extends StatelessWidget {
  final int current;
  final BuildContext ctx;
  const _AdminBottomNav({required this.current, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      {
        'icon': Icons.home_outlined,
        'activeIcon': Icons.home,
        'label': 'Home',
        'route': R.adminHome
      },
      {
        'icon': Icons.analytics_outlined,
        'activeIcon': Icons.analytics,
        'label': 'Analytics',
        'route': R.analyst
      },
      {
        'icon': Icons.security_outlined,
        'activeIcon': Icons.security,
        'label': 'Security',
        'route': R.securityAlerts
      },
      {
        'icon': Icons.people_outline,
        'activeIcon': Icons.people,
        'label': 'Users',
        'route': R.adminUsers
      },
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4))
      ]),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final sel = current == i;
              return Expanded(
                  child: GestureDetector(
                onTap: () {
                  if (!sel) {
                    Navigator.pushReplacementNamed(
                        ctx, items[i]['route'] as String);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                          sel
                              ? items[i]['activeIcon'] as IconData
                              : items[i]['icon'] as IconData,
                          color:
                              sel ? AppColors.primary : AppColors.textSecondary,
                          size: 24),
                      const SizedBox(height: 2),
                      Text(items[i]['label'] as String,
                          style: TextStyle(
                              fontSize: 11,
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight:
                                  sel ? FontWeight.w600 : FontWeight.normal)),
                    ]),
              ));
            }),
          ),
        ),
      ),
    );
  }
}

// ── Admin Home ────────────────────────────────────────────────────────────────
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Future<_AdminHomeData>? _future;

  Future<_AdminHomeData> _load(BuildContext context) async {
    final services = context.read<AppServices>();
    final admin = services.admin;
    final summary = await admin.getReportSummary().unwrap();
    final alerts = await admin.listAlerts().unwrap();
    Map<String, dynamic> health = const {};
    try {
      health = await services.home.checkHealth().unwrap();
    } catch (_) {
      health = const {'status': 'error'};
    }
    final openAlerts =
        alerts.where((a) => a.status.toLowerCase() != 'resolved').length;
    final usersMap = summary['users'] as Map?;
    final usersTotal = usersMap?['total']?.toString() ?? '0';
    final freelancers = usersMap?['freelancers']?.toString() ?? '0';
    final students = usersMap?['students']?.toString() ?? '0';
    final serverOk =
        health['status']?.toString() == 'ok' &&
        health['database']?.toString() == 'ok';
    return _AdminHomeData(
      activeUsers: usersTotal,
      openAlerts: '$openAlerts',
      reportsCount:
          (summary['projects'] as Map?)?['total']?.toString() ?? '0',
      freelancersCount: freelancers,
      studentsCount: students,
      serverHealthy: serverOk,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load(context);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() { _future = _load(context); });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Center',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.security,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_future == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else
                  FutureBuilder<_AdminHomeData>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Text('Could not load stats: ${snap.error}',
                            style: const TextStyle(color: Colors.white70));
                      }
                      if (!snap.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        );
                      }
                      final d = snap.data!;
                      return Row(
                        children: [
                          _adminStat('Registered users', d.activeUsers,
                              Icons.people_outline),
                          const SizedBox(width: 12),
                          _adminStat('Open alerts', d.openAlerts,
                              Icons.warning_amber_outlined,
                              isAlert: true),
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  TSectionHeader(
                      title: 'Platform Analytics',
                      action: 'Full Report',
                      onAction: () => Navigator.pushNamed(context, R.analyst)),
                  const SizedBox(height: 16),
                  FutureBuilder<_AdminHomeData>(
                    future: _future,
                    builder: (context, snap) {
                      final d = snap.data;
                      final serverLabel = d == null
                          ? '…'
                          : (d.serverHealthy ? 'Live' : 'Offline');
                      final serverColor = d == null
                          ? AppColors.textSecondary
                          : (d.serverHealthy
                              ? AppColors.success
                              : AppColors.error);
                      return Row(
                        children: [
                          Expanded(
                            child: _analyticsCard('Server', serverLabel,
                                Icons.language, serverColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _analyticsCard(
                                'Projects (total)',
                                d?.reportsCount ?? '…',
                                Icons.description_outlined,
                                AppColors.primary),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const TSectionHeader(title: 'Management Hub'),
                  const SizedBox(height: 16),
                  FutureBuilder<_AdminHomeData>(
                    future: _future,
                    builder: (context, snap) {
                      final d = snap.data;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.35,
                        children: [
                          _hubCard(context, 'Users', Icons.group_outlined,
                              R.adminUsers,
                              subtitle: d != null
                                  ? '${d.activeUsers} registered'
                                  : null),
                          _hubCard(context, 'Roles', Icons.shield_outlined,
                              R.adminRoles,
                              subtitle: d != null
                                  ? '${d.freelancersCount} freelancers · ${d.studentsCount} students'
                                  : null),
                          _hubCard(context, 'Logs', Icons.list_alt_outlined,
                              R.loginLogs,
                              subtitle: d != null
                                  ? '${d.openAlerts} open alerts'
                                  : null),
                          _hubCard(context, 'Settings', Icons.settings_outlined,
                              R.settings,
                              subtitle: 'Platform preferences'),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _AdminBottomNav(current: 0, ctx: context),
    );
  }

  Widget _adminStat(String label, String val, IconData icon,
          {bool isAlert = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(icon,
                  color: isAlert ? Colors.orangeAccent : Colors.white70,
                  size: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                  Text(val,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _analyticsCard(String title, String val, IconData icon, Color color) =>
      TCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(val,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            Text(title,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );

  Widget _hubCard(BuildContext context, String title, IconData icon,
          String route, {String? subtitle}) =>
      TCard(
        onTap: () => Navigator.pushNamed(context, route),
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      );
}

class _AdminHomeData {
  final String activeUsers;
  final String openAlerts;
  final String reportsCount;
  final String freelancersCount;
  final String studentsCount;
  final bool serverHealthy;

  const _AdminHomeData({
    required this.activeUsers,
    required this.openAlerts,
    required this.reportsCount,
    required this.freelancersCount,
    required this.studentsCount,
    required this.serverHealthy,
  });
}

// ── Admin Users ───────────────────────────────────────────────────────────────
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<api.ApiUser>> _usersFuture;
  final _searchCtrl = TextEditingController();
  String _query = '';
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<api.ApiUser>> _loadUsers() async {
    final res = await context
        .read<AppServices>()
        .admin
        .listUsers(perPage: 200)
        .unwrap();
    final items = res['items'] as List? ?? [];
    if (mounted) {
      setState(() => _totalUsers = res['total'] as int? ?? items.length);
    }
    return items
        .map((item) => api.ApiUser.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void _retryUsers() {
    setState(() {
      _usersFuture = _loadUsers();
    });
  }

  Future<void> _openAddUser() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddUserScreen()),
    );
    if (created == true && mounted) _retryUsers();
  }

  void _openUserDetails(api.ApiUser u) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => UserDetailsAdminScreen(initialUser: u),
      ),
    ).then((removed) {
      if (removed == true && mounted) _retryUsers();
    });
  }

  Widget _userCard(api.ApiUser u) {
    final status = u.accountStatusLabel;
    final statusColor = u.accountStatus.toLowerCase() == 'approved'
        ? AppColors.success
        : u.isPending
            ? AppColors.warning
            : AppColors.error;
    final meta = <String>[
      if (u.email.isNotEmpty) u.email,
      if (u.phone.isNotEmpty) u.phone,
      if (u.userType.isNotEmpty) u.displayRole,
    ].join(' · ');

    return TCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: () => _openUserDetails(u),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                if (u.bio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    u.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (u.skills.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Skills: ${u.skillsSummary}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TChip(
                label: status,
                bg: statusColor.withValues(alpha: 0.12),
                textColor: statusColor,
              ),
              const SizedBox(height: 4),
              TChip(
                label: u.displayRole,
                bg: AppColors.primary.withValues(alpha: 0.1),
                textColor: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.canPop(context)
                ? Navigator.pop(context)
                : Navigator.pushReplacementNamed(context, R.adminHome)),
        title: const Text('Users Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.person_add_outlined,
                  color: AppColors.primary),
              onPressed: _openAddUser)
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_totalUsers > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '$_totalUsers users in database',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                    hintText: 'Search users...',
                    border: InputBorder.none,
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.textSecondary))),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<api.ApiUser>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(
                        snapshot.error?.toString() ?? 'Unable to load users.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: _retryUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final allUsers = snapshot.data!;
              final users = _query.isEmpty
                  ? allUsers
                  : allUsers.where((u) {
                      final name = u.primaryName.toLowerCase();
                      final role = u.displayRole.toLowerCase();
                      final email = u.email.toLowerCase();
                      final phone = u.phone.toLowerCase();
                      final bio = u.bio.toLowerCase();
                      return name.contains(_query) ||
                          role.contains(_query) ||
                          email.contains(_query) ||
                          phone.contains(_query) ||
                          bio.contains(_query);
                    }).toList();
              if (users.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                      child: Text(
                          _query.isEmpty ? 'No users found' : 'No results for "$_query"',
                          style: const TextStyle(color: AppColors.textSecondary))),
                );
              }
              return Column(
                children: users.map(_userCard).toList(),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _AdminBottomNav(current: 3, ctx: context),
    );
  }
}

// ── Admin Roles ───────────────────────────────────────────────────────────────
class AdminRolesScreen extends StatefulWidget {
  const AdminRolesScreen({super.key});
  @override
  State<AdminRolesScreen> createState() => _AdminRolesScreenState();
}

class _AdminRolesScreenState extends State<AdminRolesScreen> {
  Future<Map<String, dynamic>>? _future;

  static const _rolesMeta = [
    {
      'key': 'admin',
      'name': 'Admin',
      'perms': ['All Access', 'Manage Users', 'Security'],
      'color': AppColors.error,
    },
    {
      'key': 'freelancer',
      'name': 'Freelancer',
      'perms': ['Projects', 'Tasks', 'Chat', 'AI Tools'],
      'color': AppColors.primary,
    },
    {
      'key': 'student',
      'name': 'Student',
      'perms': ['View Projects', 'Tasks', 'Chat'],
      'color': AppColors.success,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() { _future = _load(); });
    });
  }

  Future<Map<String, dynamic>> _load() =>
      context.read<AppServices>().admin.getAnalyticsOverview().unwrap();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Role-Based Access',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: () => setState(() { _future = _load(); }),
            ),
          ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Could not load roles: ${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() { _future = _load(); }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final usersMap = snap.data?['users'] as Map?;
          final byType = (_future == null ||
                  snap.connectionState == ConnectionState.waiting)
              ? null
              : (usersMap?['by_type'] as Map?)?.cast<String, dynamic>();
          final byRole = (_future == null ||
                  snap.connectionState == ConnectionState.waiting)
              ? null
              : (usersMap?['by_role'] as Map?)?.cast<String, dynamic>();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _rolesMeta.length,
            itemBuilder: (_, i) {
              final r = _rolesMeta[i];
              final key = r['key'] as String;
              final color = r['color'] as Color;
              final perms = r['perms'] as List<String>;
              final memberCount = _roleMemberCount(key, byRole, byType);
              final count =
                  memberCount < 0 ? '…' : memberCount.toString();
              return TCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.shield_outlined,
                            color: color, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(r['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 16)),
                          Text('$count members',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ])),
                    IconButton(
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.primary),
                        onPressed: () => Navigator.pushNamed(
                            context, R.editRolePermissions,
                            arguments: {
                              ...r,
                              'count': memberCount < 0 ? 0 : memberCount,
                            })),
                  ]),
                  const SizedBox(height: 10),
                  const Text('Permissions:',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: perms
                          .map((p) => TChip(
                              label: p,
                              bg: color.withValues(alpha: 0.1),
                              textColor: color))
                          .toList()),
                ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Admin accounts use [by_role]; freelancer/student use [by_type].
  static int _roleMemberCount(
    String key,
    Map<String, dynamic>? byRole,
    Map<String, dynamic>? byType,
  ) {
    if (byRole == null && byType == null) return -1;
    if (key == 'admin') {
      return (byRole?['admin'] as num?)?.toInt() ?? 0;
    }
    return (byType?[key] as num?)?.toInt() ??
        (byType?[key.toLowerCase()] as num?)?.toInt() ??
        0;
  }
}

// ── Security Checklist ────────────────────────────────────────────────────────
class SecurityChecklistScreen extends StatefulWidget {
  const SecurityChecklistScreen({super.key});
  @override
  State<SecurityChecklistScreen> createState() =>
      _SecurityChecklistScreenState();
}

class _SecurityChecklistScreenState extends State<SecurityChecklistScreen> {
  final List<Map<String, dynamic>> _items = [
    {
      'label': 'Enable Two-Factor Authentication',
      'done': true,
      'priority': 'High'
    },
    {'label': 'Review Security Alerts', 'done': false, 'priority': 'High'},
    {'label': 'Update Password Policy', 'done': true, 'priority': 'Medium'},
    {'label': 'Audit User Permissions', 'done': false, 'priority': 'Medium'},
    {'label': 'Enable Login Monitoring', 'done': true, 'priority': 'High'},
    {'label': 'Configure Rate Limiting', 'done': false, 'priority': 'Low'},
    {'label': 'Backup Encryption Keys', 'done': true, 'priority': 'High'},
  ];
  @override
  Widget build(BuildContext context) {
    final done = _items.where((i) => i['done'] == true).length;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.canPop(context)
                  ? Navigator.pop(context)
                  : Navigator.pushReplacementNamed(context, R.adminHome)),
          title: const Text('Security Checklist',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TCard(
            child: Column(children: [
          Text('$done/${_items.length} completed',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TBar(
              value: done / _items.length, color: AppColors.success, height: 8),
        ])),
        const SizedBox(height: 12),
        ..._items.asMap().entries.map((e) {
          final i = e.value;
          final isDone = i['done'] as bool;
          final pri = i['priority'] as String;
          final priColor = pri == 'High'
              ? AppColors.error
              : pri == 'Medium'
                  ? AppColors.warning
                  : AppColors.success;
          return TCard(
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () => setState(() => _items[e.key]['done'] = !isDone),
                  child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          color: isDone ? AppColors.success : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  isDone ? AppColors.success : AppColors.border,
                              width: 2)),
                      child: isDone
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 14)
                          : null),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(i['label'] as String,
                        style: TextStyle(
                            color: isDone
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            decoration:
                                isDone ? TextDecoration.lineThrough : null))),
                TChip(
                    label: pri,
                    bg: priColor.withValues(alpha: 0.1),
                    textColor: priColor,
                    fontSize: 10),
              ]));
        }),
      ]),
    );
  }
}

// ── Login Logs ────────────────────────────────────────────────────────────────
class LoginLogsScreen extends StatefulWidget {
  const LoginLogsScreen({super.key});
  @override
  State<LoginLogsScreen> createState() => _LoginLogsScreenState();
}

class _LoginLogsScreenState extends State<LoginLogsScreen> {
  String _filter = 'All';
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5FA),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.canPop(context)
                ? Navigator.pop(context)
                : Navigator.pushReplacementNamed(context, R.adminHome)),
        title: const Text('Login Logs',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.pushNamed(context, R.notifications)),
            const NotificationBadgeWidget(),
          ]),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                    hintText: 'Search by name or IP...',
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search,
                        color: AppColors.textSecondary, size: 20))),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
              children: ['All', 'Success', 'Failed'].map((f) {
            final sel = _filter == f;
            return GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                    color: sel ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border)),
                child: Text(f,
                    style: TextStyle(
                        color: sel ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            );
          }).toList()),
        ),
        Expanded(
          child: RepositoryLoader<List<LoginLog>>(
            load: () => context.read<AppServices>().admin.listLoginLogs().unwrap(),
            isEmpty: (logs) => logs.isEmpty,
            emptyMessage: 'No login logs found',
            builder: (context, logs) {
              final filteredLogs = logs.where((l) {
                // Status filter
                if (_filter == 'Success' && !l.isSuccess) return false;
                if (_filter == 'Failed' && l.isSuccess) return false;
                // Search filter
                if (_query.isNotEmpty) {
                  final nameMatch = l.userName.toLowerCase().contains(_query);
                  final ipMatch = l.ip.toLowerCase().contains(_query);
                  if (!nameMatch && !ipMatch) return false;
                }
                return true;
              }).toList();
              if (filteredLogs.isEmpty) {
                return Center(
                  child: Text(
                      _query.isNotEmpty
                          ? 'No results for "$_query"'
                          : 'No login logs found',
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                );
              }
              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredLogs.length,
                itemBuilder: (_, i) {
                  final l = filteredLogs[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(l.userName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        fontSize: 15))),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(l.time,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                  Text(l.date,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ]),
                          ]),
                          const SizedBox(height: 8),
                          TChip(
                              label: l.isSuccess ? '✓ Success' : '✕ Failed',
                              bg: l.isSuccess
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.error.withValues(alpha: 0.1),
                              textColor: l.isSuccess
                                  ? AppColors.success
                                  : AppColors.error),
                          const SizedBox(height: 8),
                          Row(children: [
                            const Icon(Icons.monitor_outlined,
                                size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(l.device,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ),
                            Text(l.ip,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ]),
                        ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ── Security Alerts ───────────────────────────────────────────────────────────
class SecurityAlertsScreen extends StatefulWidget {
  const SecurityAlertsScreen({super.key});

  @override
  State<SecurityAlertsScreen> createState() => _SecurityAlertsScreenState();
}

class _SecurityAlertsScreenState extends State<SecurityAlertsScreen> {
  Future<List<SecurityAlert>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<AppServices>().admin.listAlerts().unwrap();
    });
  }

  Future<void> _openAlert(SecurityAlert alert) async {
    final resolved = await Navigator.pushNamed(
      context,
      R.alertDetails,
      arguments: alert,
    );
    if (resolved == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5FA),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.canPop(context)
                ? Navigator.pop(context)
                : Navigator.pushReplacementNamed(context, R.adminHome)),
        title: const Text('Security Alerts',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _load,
          ),
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.pushNamed(context, R.notifications)),
            const NotificationBadgeWidget(),
          ]),
        ],
      ),
      body: FutureBuilder<List<SecurityAlert>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load alerts: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            );
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return const Center(
              child: Text('No security alerts found',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            itemBuilder: (_, i) {
              final a = alerts[i];
              final Color riskColor = a.risk.contains('HIGH')
                  ? AppColors.error
                  : a.risk.contains('MEDIUM')
                      ? AppColors.warning
                      : AppColors.success;
              final IconData alertIcon = a.risk.contains('HIGH')
                  ? Icons.warning_amber_outlined
                  : Icons.shield_outlined;
              return GestureDetector(
                onTap: () => _openAlert(a),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: riskColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(alertIcon, color: riskColor, size: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Expanded(
                                    child: Text(a.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                            fontSize: 15))),
                                const Icon(Icons.arrow_forward_ios,
                                    size: 14, color: AppColors.textSecondary),
                              ]),
                              Row(children: [
                                const Icon(Icons.person_outline,
                                    size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 2),
                                Text(a.user,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary))
                              ]),
                              const SizedBox(height: 6),
                              Text(a.description,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Row(children: [
                                TChip(
                                    label: a.risk,
                                    bg: riskColor.withValues(alpha: 0.1),
                                    textColor: riskColor,
                                    fontSize: 10),
                                const SizedBox(width: 6),
                                TChip(
                                    label: a.status,
                                    bg: a.status == 'New'
                                        ? AppColors.primary
                                            .withValues(alpha: 0.1)
                                        : AppColors.border,
                                    textColor: a.status == 'New'
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                    fontSize: 10),
                                const Spacer(),
                                const Icon(Icons.access_time,
                                    size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 2),
                                Text(a.time,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary)),
                              ]),
                            ])),
                      ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Alert Details (Modal style) ───────────────────────────────────────────────
class AlertDetailsScreen extends StatefulWidget {
  const AlertDetailsScreen({super.key});

  @override
  State<AlertDetailsScreen> createState() => _AlertDetailsScreenState();
}

class _AlertDetailsScreenState extends State<AlertDetailsScreen> {
  bool _resolving = false;

  Future<void> _markResolved(SecurityAlert alert) async {
    if (alert.isResolved || _resolving) return;
    setState(() => _resolving = true);
    try {
      await context.read<AppServices>().admin.resolveAlert(alert.id).unwrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert marked as resolved')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not resolve alert: $e')),
      );
    } finally {
      if (mounted) setState(() => _resolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! SecurityAlert) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(children: [
          GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black54)),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(24),
                child: SafeArea(child: Text('No alert selected.')),
              ),
            ),
          ),
        ]),
      );
    }
    final a = args;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.black54)),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Alert Details',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const Spacer(),
                      GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close,
                              color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 16),
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Activity Information',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      fontSize: 15)),
                              const SizedBox(height: 14),
                              _infoRow(Icons.shield_outlined, 'Alert Title',
                                  a.title),
                              _infoRow(Icons.person_outline, 'User Involved',
                                  a.user),
                              _infoRow(Icons.warning_amber_outlined,
                                  'Risk Level', a.risk),
                              _infoRow(
                                  Icons.access_time, 'Detection Time', a.time),
                            ])),
                    const SizedBox(height: 12),
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Timeline of Attempts',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      fontSize: 15)),
                              const SizedBox(height: 12),
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(children: [
                                      Container(
                                          width: 10,
                                          height: 10,
                                          decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle)),
                                      Container(
                                          width: 2,
                                          height: 30,
                                          color: AppColors.border)
                                    ]),
                                    const SizedBox(width: 10),
                                    const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('09:15 AM',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color:
                                                      AppColors.textPrimary)),
                                          Text('First failed login attempt',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary)),
                                          Text('203.0.113.42',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.primary)),
                                        ]),
                                  ]),
                            ])),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                          child: TButton(
                              label: 'Ignore',
                              outline: true,
                              onTap: _resolving
                                  ? null
                                  : () => Navigator.pop(context, false))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TButton(
                              label: _resolving
                                  ? 'Updating…'
                                  : (a.isResolved
                                      ? 'Resolved'
                                      : 'Mark as Resolved'),
                              onTap: a.isResolved || _resolving
                                  ? null
                                  : () => _markResolved(a))),
                    ]),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ]),
        ]));
  }
}

// ── Security Monitor ──────────────────────────────────────────────────────────
class SecurityMonitorScreen extends StatefulWidget {
  const SecurityMonitorScreen({super.key});

  @override
  State<SecurityMonitorScreen> createState() => _SecurityMonitorScreenState();
}

class _SecurityMonitorScreenState extends State<SecurityMonitorScreen> {
  Future<_SecurityMonitorData>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() { _future = _load(); });
    });
  }

  Future<_SecurityMonitorData> _load() async {
    final admin = context.read<AppServices>().admin;
    final ai = context.read<AppServices>().ai;
    final alerts = await admin.listAlerts().unwrap();
    final activity = await admin.getAdminActivity().unwrap();
    
    AnomalyReport? anomalyReport;
    try {
      anomalyReport = await ai.detectAnomaly({}).unwrap();
    } catch (e) {
      // Ignore AI failure and proceed with other data
    }
    
    return _SecurityMonitorData(
      alerts: alerts, 
      activity: activity.cast<Map<String, dynamic>>(), 
      anomalyReport: anomalyReport,
    );
  }

  void _refresh() { setState(() { _future = _load(); }); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Security Monitor',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _refresh,
          )
        ],
      ),
      body: FutureBuilder<_SecurityMonitorData>(
        future: _future,
        builder: (context, snap) {
          if (_future == null ||
              snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off,
                      color: AppColors.textSecondary, size: 40),
                  const SizedBox(height: 8),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary)),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final data = snap.data ?? const _SecurityMonitorData(alerts: [], activity: []);
          final unresolvedAlerts =
              data.alerts.where((a) => a.status != 'Resolved').toList();
          final recentActivity = data.activity.take(5).toList();
          final anomalies = data.anomalyReport?.anomalies ?? [];

          return RefreshIndicator(
            onRefresh: () async { _refresh(); },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('AI powered threat detection',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                
                // ── AI Anomaly Detection ────────────────────────────────────
                if (anomalies.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, color: AppColors.error, size: 20),
                            SizedBox(width: 8),
                            Text('AI Anomaly Detected',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppColors.error)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...anomalies.take(3).map((anomaly) {
                          final Color color = anomaly.severity == 'critical' 
                              ? AppColors.error 
                              : anomaly.severity == 'high' 
                                  ? Colors.orange 
                                  : AppColors.warning;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.warning_amber_outlined, color: color, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(anomaly.type,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary)),
                                      Text(anomaly.description,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── High-risk alert summary card ──────────────────────────
                if (unresolvedAlerts.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.warning_amber_outlined,
                            color: AppColors.error, size: 28),
                      ),
                      const SizedBox(height: 12),
                      Text(
                          '${unresolvedAlerts.length} Unresolved Alert${unresolvedAlerts.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary)),
                      Text(unresolvedAlerts.first.title,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                      const SizedBox(height: 12),
                      TButton(
                        label: 'View All Alerts',
                        outline: true,
                        onTap: () =>
                            Navigator.pushNamed(context, R.securityAlerts),
                      ),
                    ]),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.2)),
                    ),
                    child: const Column(children: [
                      Icon(Icons.check_circle_outline,
                          color: AppColors.success, size: 36),
                      SizedBox(height: 8),
                      Text('No Active Threats',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textPrimary)),
                      Text('All systems are operating normally.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ]),
                  ),
                ],

                // ── Live Activity ──────────────────────────────────────────
                const SizedBox(height: 24),
                const Text('Recent Activity',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                if (recentActivity.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No recent activity',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  ...recentActivity.map((item) {
                    final action = item['action']?.toString() ?? '';
                    final entity = item['entity']?.toString() ?? '';
                    final details = item['details']?.toString() ?? '';
                    final createdAt = item['created_at']?.toString() ?? '';
                    return _liveItem(
                      _iconForAction(action),
                      '$action — $entity',
                      details.isNotEmpty ? details : entity,
                      _formatAgo(createdAt),
                    );
                  }),

                // ── Active alerts list ─────────────────────────────────────
                if (unresolvedAlerts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    const Text('Active Alerts',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Text('${unresolvedAlerts.length}',
                        style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 12),
                  ...unresolvedAlerts.take(3).map(
                        (a) => _alertItem(a.title),
                      ),
                ],

                // ── Suggested actions ──────────────────────────────────────
                const SizedBox(height: 24),
                const Text('Suggested Actions',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                _suggestedAction(context, 'Manage 2FA', R.twoFAStatus),
                _suggestedAction(context, 'View Security Alerts',
                    R.securityAlerts),
                _suggestedAction(
                    context, 'Review Activity Logs', R.loginLogs),

                // ── AI assistant prompt ────────────────────────────────────
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, R.askAI),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color:
                              AppColors.primary.withValues(alpha: 0.1)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.chat_bubble_outline,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('AI Security Assistant',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary)),
                              Text('Ask AI about this activity',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }

  static IconData _iconForAction(String action) {
    switch (action.toUpperCase()) {
      case 'LOGIN':
        return Icons.login;
      case 'LOGOUT':
        return Icons.logout;
      case 'CREATE':
        return Icons.add_circle_outline;
      case 'DELETE':
      case 'DELETE_TASK':
        return Icons.delete_outline;
      case 'UPDATE':
      case 'UPDATE_STATUS':
        return Icons.edit_outlined;
      default:
        return Icons.history;
    }
  }

  static String _formatAgo(String isoString) =>
      formatRelativeTime(isoString).toLowerCase();

  Widget _liveItem(
          IconData icon, String title, String sub, String time) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                  color: AppColors.background, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                Text(sub,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ])),
          Text(time,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11)),
        ]),
      );

  Widget _alertItem(String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textPrimary))),
        ]),
      );

  Widget _suggestedAction(BuildContext context, String label,
          String route,
          {Color color = AppColors.primary}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton(
          onPressed: () => Navigator.pushNamed(context, route),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text(label,
              style:
                  TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      );
}

class _SecurityMonitorData {
  final List<SecurityAlert> alerts;
  final List<Map<String, dynamic>> activity;
  final AnomalyReport? anomalyReport;
  const _SecurityMonitorData({
    required this.alerts, 
    required this.activity,
    this.anomalyReport,
  });
}




// ── Rate Limiting ─────────────────────────────────────────────────────────────
class RateLimitingScreen extends StatefulWidget {
  const RateLimitingScreen({super.key});
  @override
  State<RateLimitingScreen> createState() => _RateLimitingScreenState();
}

class _RateLimitingScreenState extends State<RateLimitingScreen> {
  double _apiLimit = 100;
  double _loginLimit = 5;
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Rate Limiting',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TCard(
            child: Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Enable Rate Limiting',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text('Protect against brute force attacks',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          Switch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              activeThumbColor: AppColors.primary),
        ])),
        const SizedBox(height: 12),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('API Requests / Minute',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('${_apiLimit.toInt()} requests',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
          Slider(
              value: _apiLimit,
              min: 10,
              max: 500,
              divisions: 49,
              onChanged: (v) => setState(() => _apiLimit = v),
              activeColor: AppColors.primary),
        ])),
        const SizedBox(height: 12),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Login Attempts / Hour',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('${_loginLimit.toInt()} attempts',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
          Slider(
              value: _loginLimit,
              min: 1,
              max: 20,
              divisions: 19,
              onChanged: (v) => setState(() => _loginLimit = v),
              activeColor: AppColors.primary),
        ])),
        const SizedBox(height: 16),
        TButton(label: 'Save Settings', onTap: () {}),
      ]),
    );
  }
}

// ── Encryption Status ─────────────────────────────────────────────────────────
class EncryptionStatusScreen extends StatelessWidget {
  const EncryptionStatusScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Encryption Status',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TCard(
            child: Row(children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.lock_outline,
                  color: AppColors.success, size: 28)),
          const SizedBox(width: 14),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('All Data Encrypted',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 16)),
                Text('Military-grade encryption active',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
        ])),
        const SizedBox(height: 16),
        ...<Map<String, String>>[
          {
            'label': 'Database Encryption',
            'alg': 'AES-256',
            'status': 'Active'
          },
          {
            'label': 'File Storage Encryption',
            'alg': 'RSA-2048',
            'status': 'Active'
          },
          {'label': 'API Communication', 'alg': 'TLS 1.3', 'status': 'Active'},
          {'label': 'Backup Encryption', 'alg': 'AES-256', 'status': 'Active'},
        ].map((e) => TCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              const Icon(Icons.lock_outline,
                  color: AppColors.success, size: 20),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(e['label']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    Text(e['alg']!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ])),
              TChip(
                  label: e['status']!,
                  bg: AppColors.success.withValues(alpha: 0.1),
                  textColor: AppColors.success),
            ]))),
      ]),
    );
  }
}

// ── 2FA Status ────────────────────────────────────────────────────────────────
class TwoFAStatusScreen extends StatefulWidget {
  const TwoFAStatusScreen({super.key});
  @override
  State<TwoFAStatusScreen> createState() => _TwoFAStatusScreenState();
}

class _TwoFAStatusScreenState extends State<TwoFAStatusScreen> {
  bool _enabled = true;
  String _method = 'Authenticator App';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Two-Factor Authentication',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TCard(
            child: Row(children: [
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('2FA Enabled',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 16)),
                Text('Extra layer of security for your account',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ])),
          Switch(
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              activeThumbColor: AppColors.primary),
        ])),
        const SizedBox(height: 12),
        const Text('Authentication Method',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        ...['Authenticator App', 'SMS', 'Email'].map((m) => GestureDetector(
              onTap: () => setState(() => _method = m),
              child: TCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(
                        _method == m
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: AppColors.primary,
                        size: 20),
                    const SizedBox(width: 12),
                    Text(m,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ])),
            )),
        const SizedBox(height: 16),
        TButton(label: 'Save Settings', onTap: () {}),
      ]),
    );
  }
}

// ── Analyst / Analytics ───────────────────────────────────────────────────────
class AnalystScreen extends StatefulWidget {
  const AnalystScreen({super.key});
  @override
  State<AnalystScreen> createState() => _AnalystScreenState();
}

class _AnalystScreenState extends State<AnalystScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() { _future = _load(); });
      }
    });
  }

  Future<Map<String, dynamic>> _load() =>
      context.read<AppServices>().admin.getAnalyticsOverview().unwrap();

  void _refresh() { setState(() { _future = _load(); }); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            final data = snap.data ?? {};
            final users = (data['users'] as Map?) ?? {};
            final projects = (data['projects'] as Map?) ?? {};
            final tasks = (data['tasks'] as Map?) ?? {};

            final totalUsers = users['total']?.toString() ?? '—';
            final activeUsers = users['active']?.toString() ?? '—';
            final totalProjects = projects['total']?.toString() ?? '—';
            final activeProjects = projects['active']?.toString() ?? '—';
            final totalTasks = (tasks['total'] as num?)?.toInt() ?? 0;
            final doneTasks = (tasks['done'] as num?)?.toInt() ?? 0;
            final overdueTasks = tasks['overdue']?.toString() ?? '—';
            final completionRate = tasks['completion_rate'] != null
                ? '${tasks['completion_rate']}%'
                : '—';
            final completionVal = totalTasks > 0
                ? (doneTasks / totalTasks).clamp(0.0, 1.0).toDouble()
                : 0.0;

            // project status breakdown
            final byStatus =
                (projects['by_status'] as Map?)?.cast<String, dynamic>() ?? {};

            final isLoading = _future == null ||
                snap.connectionState == ConnectionState.waiting;
            final hasError = snap.hasError;

            return RefreshIndicator(
              onRefresh: () async {
                final data = await _load();
                if (mounted) setState(() => _future = Future.value(data));
              },
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Analytics',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      if (isLoading)
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: AppColors.primary),
                          onPressed: _refresh,
                        ),
                    ],
                  ),
                  const Text('Platform insights',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),

                  if (hasError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(children: [
                        const Icon(Icons.cloud_off,
                            color: AppColors.textSecondary, size: 40),
                        const SizedBox(height: 8),
                        Text('Could not load analytics: ${snap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        TextButton(
                            onPressed: _refresh,
                            child: const Text('Retry')),
                      ]),
                    ),

                  const SizedBox(height: 20),

                  // ── Key stats ──────────────────────────────────────────────
                  _analyticStat(
                      Icons.people_outline,
                      'Total Users',
                      isLoading ? '…' : totalUsers,
                      isLoading ? '' : 'Active: $activeUsers',
                      AppColors.success),
                  const SizedBox(height: 12),
                  _analyticStat(
                      Icons.folder_outlined,
                      'Total Projects',
                      isLoading ? '…' : totalProjects,
                      isLoading ? '' : 'Active: $activeProjects',
                      AppColors.primary),
                  const SizedBox(height: 12),
                  _analyticStat(
                      Icons.check_circle_outline,
                      'Task Completion',
                      isLoading ? '…' : completionRate,
                      isLoading ? '' : 'Overdue: $overdueTasks',
                      AppColors.success),

                  const SizedBox(height: 24),
                  const Text('Task Completion Rate',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  TCard(
                    child: Column(children: [
                      _rateRow('On Time', completionVal, AppColors.success),
                      const SizedBox(height: 12),
                      _rateRow(
                          'Overdue',
                          totalTasks > 0
                              ? (((tasks['overdue'] as num?)?.toInt() ?? 0) /
                                  totalTasks)
                                  .clamp(0.0, 1.0)
                                  .toDouble()
                              : 0.0,
                          AppColors.error),
                    ]),
                  ),

                  if (byStatus.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Project Status Breakdown',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    TCard(
                      child: Column(
                        children: byStatus.entries.map((e) {
                          final count = (e.value as num?)?.toInt() ?? 0;
                          final total = byStatus.values.fold<int>(
                              0, (s, v) => s + ((v as num?)?.toInt() ?? 0));
                          final ratio =
                              total > 0 ? count / total : 0.0;
                          final color = e.key == 'active'
                              ? AppColors.success
                              : e.key == 'completed'
                                  ? AppColors.primary
                                  : AppColors.warning;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _statusRow(
                                e.key, count.toString(), ratio.toDouble(),
                                color),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _AdminBottomNav(current: 1, ctx: context),
    );
  }

  Widget _analyticStat(IconData icon, String label, String value, String sub,
      Color color) {
    return TCard(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.primary, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                if (sub.isNotEmpty)
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
              ])),
          Icon(Icons.trending_up, color: color, size: 20),
        ]));
  }

  Widget _rateRow(String label, double val, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        Text('${(val * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      TBar(value: val.clamp(0.0, 1.0), color: color, height: 6),
    ]);
  }

  Widget _statusRow(String label, String count, double ratio, Color color) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label[0].toUpperCase() + label.substring(1),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textPrimary)),
            Text(count,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 4),
          TBar(value: ratio.clamp(0.0, 1.0), color: color, height: 5),
        ]),
      ),
    ]);
  }
}



// ── Secure Files ──────────────────────────────────────────────────────────────
class SecurityFilesScreen extends StatefulWidget {
  const SecurityFilesScreen({super.key});
  @override
  State<SecurityFilesScreen> createState() => _SecurityFilesScreenState();
}

class _SecurityFilesScreenState extends State<SecurityFilesScreen> {
  bool _uploading = false;
  int _listVersion = 0;
  String? _busyFileId;

  String _formatUploadedAt(String iso) {
    if (iso.isEmpty) return 'Unknown date';
    final dt = DateTime.tryParse(iso);
    if (dt == null) {
      return iso.contains('T') ? iso.split('T').first : iso;
    }
    final local = dt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  Future<void> _pickAndUpload() async {
    final svc = context.read<AppServices>();
    final result =
        await FilePicker.pickFiles(allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path;
    final bytes = picked.bytes;
    if (path == null && bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot access file data.')),
      );
      return;
    }
    setState(() => _uploading = true);
    try {
      final res = await svc.files.uploadFile(
        filePath: path ?? '',
        filename: picked.name,
        fileBytes: bytes,
      );
      if (!mounted) return;
      res.when(
        success: (_) {
          setState(() {
            _uploading = false;
            _listVersion++;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${picked.name} uploaded'),
              backgroundColor: AppColors.success,
            ),
          );
        },
        failure: (e) {
          setState(() => _uploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e), backgroundColor: AppColors.error),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _mimeFor(String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return 'application/pdf';
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  Future<void> _download(api.ApiFile file) async {
    setState(() => _busyFileId = file.id);
    try {
      final result =
          await context.read<AppServices>().files.downloadFile(file.id);
      if (!mounted) return;
      await result.when(
        success: (bytes) async {
          if (bytes.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Download returned empty file')),
            );
            return;
          }
          await saveDownloadedBytes(
            filename: file.name,
            bytes: Uint8List.fromList(bytes),
            mimeType: _mimeFor(file.name),
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} downloaded')),
          );
        },
        failure: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e), backgroundColor: AppColors.error),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _busyFileId = null);
    }
  }

  Future<void> _confirmDelete(api.ApiFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('Remove "${file.name}" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busyFileId = file.id);
    try {
      final result =
          await context.read<AppServices>().files.deleteFile(file.id);
      if (!mounted) return;
      result.when(
        success: (_) {
          setState(() => _listVersion++);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${file.name} deleted')),
          );
        },
        failure: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e), backgroundColor: AppColors.error),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _busyFileId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5FA),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Secure Files',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () => setState(() => _listVersion++),
          ),
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.pushNamed(context, R.notifications)),
            const NotificationBadgeWidget(),
          ]),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(children: [
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.upload_outlined,
                    color: AppColors.primary, size: 32)),
            const SizedBox(height: 12),
            const Text('Upload Files',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 16)),
            const Text('Drag and drop or click to browse',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TButton(
              label: _uploading ? 'Uploading…' : 'Select Files',
              onTap: _uploading ? () {} : _pickAndUpload,
            ),
          ]),
        ),
        const SizedBox(height: 20),
        const Text('Uploaded Files',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        SizedBox(
          height: 500,
          child: RepositoryLoader<List<api.ApiFile>>(
            key: ValueKey(_listVersion),
            load: () => context
                .read<AppServices>()
                .admin
                .listAllFiles(perPage: 200)
                .unwrap(),
            isEmpty: (files) => files.isEmpty,
            emptyMessage: 'No files in database',
            builder: (context, files) => ListView.builder(
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = files[i];
                final busy = _busyFileId == f.id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.description_outlined,
                                  color: AppColors.primary, size: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(f.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary)),
                                Text(
                                    f.size.isNotEmpty ? f.size : 'Unknown size',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                if (f.uploadedBy.isNotEmpty)
                                  Text(
                                    'Uploaded by ${f.uploadedBy}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary),
                                  ),
                              ])),
                          busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18, color: AppColors.textSecondary),
                                  onPressed: () => _confirmDelete(f),
                                ),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          TChip(
                              label: '🔒 Encrypted',
                              bg: AppColors.success.withValues(alpha: 0.1),
                              textColor: AppColors.success,
                              fontSize: 11),
                          const SizedBox(width: 6),
                          TChip(
                              label: f.hasIntegrityHash ? '✓ Verified' : '⚠ No Hash',
                              bg: f.hasIntegrityHash
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.warning.withValues(alpha: 0.1),
                              textColor: f.hasIntegrityHash
                                  ? AppColors.success
                                  : AppColors.warning,
                              fontSize: 11),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Text(
                              _formatUploadedAt(f.createdAt),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const Spacer(),
                          GestureDetector(
                              onTap: busy ? null : () => _download(f),
                              child: Row(children: [
                                if (busy)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  const Icon(Icons.download_outlined,
                                      size: 16, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                    busy ? 'Please wait…' : 'Download',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600)),
                              ])),
                        ]),
                      ]),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Security Center ───────────────────────────────────────────────────────────

class _SecurityCenterData {
  final List<SecurityAlert> alerts;

  const _SecurityCenterData({required this.alerts});
}

class SecurityCenterScreen extends StatefulWidget {
  const SecurityCenterScreen({super.key});

  @override
  State<SecurityCenterScreen> createState() => _SecurityCenterScreenState();
}

class _SecurityCenterScreenState extends State<SecurityCenterScreen> {
  Future<_SecurityCenterData>? _future;
  final Set<String> _dismissedAlertIds = {};
  static const _dismissCacheBox = 'security_center';
  static const _dismissCacheKey = 'dismissed_alert_ids';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDismissedIds();
      _load();
    });
  }

  Future<void> _loadDismissedIds() async {
    final cache = context.read<CacheManager>();
    final stored = await cache.getMap(
      _dismissCacheBox,
      _dismissCacheKey,
      maxAge: const Duration(days: 365),
    );
    if (!mounted || stored == null) return;
    final ids = stored['ids'];
    if (ids is List) {
      setState(() {
        _dismissedAlertIds
          ..clear()
          ..addAll(ids.map((e) => e.toString()));
      });
    }
  }

  Future<void> _dismissBanner(SecurityAlert alert) async {
    setState(() => _dismissedAlertIds.add(alert.id));
    final cache = context.read<CacheManager>();
    await cache.putMap(
      _dismissCacheBox,
      _dismissCacheKey,
      {'ids': _dismissedAlertIds.toList()},
    );
  }

  void _load() {
    setState(() {
      _future = _fetchData();
    });
  }

  Future<_SecurityCenterData> _fetchData() async {
    final admin = context.read<AppServices>().admin;
    final alerts = await admin.listAlerts().unwrap();
    return _SecurityCenterData(alerts: alerts);
  }

  List<SecurityAlert> _openAlerts(List<SecurityAlert> all) =>
      all.where((a) => !a.isResolved).toList();

  Future<void> _openFirstAlert(SecurityAlert alert) async {
    final resolved = await Navigator.pushNamed(
      context,
      R.alertDetails,
      arguments: alert,
    );
    if (resolved == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5FA),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                size: 18, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Security Center',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _load,
          ),
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () async {
                  await Navigator.pushNamed(context, R.notifications);
                  if (mounted) setState(() {});
                }),
            const NotificationBadgeWidget(),
          ])
        ],
      ),
      body: FutureBuilder<_SecurityCenterData>(
        future: _future,
        builder: (context, snapshot) {
          if (_future == null ||
              (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load security data: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            );
          }

          final data = snapshot.data ?? const _SecurityCenterData(alerts: []);
          final alerts = data.alerts;
          final openAlerts = _openAlerts(alerts);
          SecurityAlert? bannerAlert;
          for (final alert in openAlerts) {
            if (!_dismissedAlertIds.contains(alert.id)) {
              bannerAlert = alert;
              break;
            }
          }
          final showBanner = bannerAlert != null && !snapshot.hasError;
          final visibleOpenCount = openAlerts
              .where((a) => !_dismissedAlertIds.contains(a.id))
              .length;

          final alert = bannerAlert;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (showBanner && alert != null)
              _SecurityCenterBanner(
                alert: alert,
                onViewDetails: () => _openFirstAlert(alert),
                onDismiss: () => _dismissBanner(alert),
              )
            else
              const SizedBox.shrink(),
            if (showBanner) const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                const Text('Welcome to Security Center',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                Text(
                    visibleOpenCount == 0
                        ? 'No open security alerts. Your platform looks secure.'
                        : '$visibleOpenCount open alert${visibleOpenCount == 1 ? '' : 's'} need review.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 16),
            _secItem(
                context,
                Icons.description_outlined,
                const Color(0xFFEEF2FF),
                AppColors.primary,
                'Login Logs',
                'View all login attempts',
                R.loginLogs),
            const SizedBox(height: 10),
            _secItem(
                context,
                Icons.history,
                const Color(0xFFF3E5F5),
                const Color(0xFF7B1FA2),
                'Activity Log',
                'Search login, files, and alerts',
                R.reviewActivity),
            const SizedBox(height: 10),
            Stack(children: [
              _secItem(
                  context,
                  Icons.warning_amber_outlined,
                  const Color(0xFFFFF8EE),
                  AppColors.warning,
                  'Security Alerts',
                  visibleOpenCount == 0
                      ? 'No open alerts'
                      : '$visibleOpenCount open alert${visibleOpenCount == 1 ? '' : 's'}',
                  R.securityAlerts),
              if (visibleOpenCount > 0)
                Positioned(
                    top: 12,
                    right: 50,
                    child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: Center(
                            child: Text('$visibleOpenCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold))))),
            ]),
            const SizedBox(height: 10),
            _secItem(
                context,
                Icons.upload_outlined,
                const Color(0xFFE8F5E9),
                AppColors.success,
                'Secure Files',
                'Upload and download encrypted files',
                R.securityFiles),
            const SizedBox(height: 10),
            _secItem(
                context,
                Icons.info_outline,
                const Color(0xFFEEF2FF),
                AppColors.primary,
                'Security Overview',
                'Learn about our security measures',
                R.securityOverview),
          ]);
        },
      ),
    );
  }

  Widget _secItem(BuildContext ctx, IconData icon, Color iconBg,
      Color iconColor, String title, String sub, String route) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(ctx, route),
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 22)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text(sub,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ])),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: AppColors.textSecondary),
          ])),
    );
  }
}

class _SecurityCenterBanner extends StatelessWidget {
  final SecurityAlert alert;
  final VoidCallback onViewDetails;
  final VoidCallback onDismiss;

  const _SecurityCenterBanner({
    required this.alert,
    required this.onViewDetails,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.shield_outlined, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(alert.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                        fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(alert.description,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            GestureDetector(
                onTap: onViewDetails,
                child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('View Details',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)))),
            const SizedBox(height: 8),
            GestureDetector(
                onTap: onDismiss,
                child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border)),
                    child: const Text('Dismiss',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)))),
          ]),
    );
  }
}

// ── Security Overview ─────────────────────────────────────────────────────────

class _SecurityOverviewStep {
  final IconData icon;
  final String title;
  final String sub;
  final String route;

  const _SecurityOverviewStep({
    required this.icon,
    required this.title,
    required this.sub,
    required this.route,
  });
}

class SecurityOverviewScreen extends StatefulWidget {
  const SecurityOverviewScreen({super.key});

  @override
  State<SecurityOverviewScreen> createState() => _SecurityOverviewScreenState();
}

class _SecurityOverviewScreenState extends State<SecurityOverviewScreen> {
  Future<Map<String, dynamic>>? _future;

  static const _steps = [
    _SecurityOverviewStep(
      icon: Icons.key_outlined,
      title: '1. Login',
      sub: 'View login attempts and audit trail',
      route: R.loginLogs,
    ),
    _SecurityOverviewStep(
      icon: Icons.lock_outline,
      title: '2. Encryption',
      sub: 'File encryption and secure transfers',
      route: R.encryptionStatus,
    ),
    _SecurityOverviewStep(
      icon: Icons.storage_outlined,
      title: '3. Storage',
      sub: 'Secure files and uploads',
      route: R.securityFiles,
    ),
    _SecurityOverviewStep(
      icon: Icons.visibility_outlined,
      title: '4. Monitoring',
      sub: 'Review platform activity',
      route: R.reviewActivity,
    ),
    _SecurityOverviewStep(
      icon: Icons.notifications_outlined,
      title: '5. Alerts',
      sub: 'Open security alerts',
      route: R.securityAlerts,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  void _refresh() {
    setState(() {
      _future = context.read<AppServices>().admin.getSecuritySummary().unwrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Security Overview',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: _refresh,
            ),
          ]),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final loading = _future == null ||
              (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData);
          final metrics =
              (snapshot.data?['metrics'] as Map?)?.cast<String, dynamic>();
          final recentLogins = snapshot.data?['logins'] as List? ?? [];

          return ListView(padding: const EdgeInsets.all(16), children: [
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16)),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Data is Protected',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  SizedBox(height: 6),
                  Text(
                      'We use industry-standard security measures to keep your information safe.',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ])),
        const SizedBox(height: 20),
        const Text('Hashing vs Encryption',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: TCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                const Icon(Icons.key_outlined,
                    color: AppColors.primary, size: 28),
                const SizedBox(height: 8),
                const Text('Hashing',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15)),
                const Text(
                    'One-way conversion of data into a fixed-size string. Cannot be reversed.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Used for:\nPasswords, checksums',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary))),
              ]))),
          const SizedBox(width: 10),
          Expanded(
              child: TCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                const Icon(Icons.lock_outline,
                    color: AppColors.primary, size: 28),
                const SizedBox(height: 8),
                const Text('Encryption',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15)),
                const Text(
                    'Two-way conversion that can be decrypted with the correct key.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Used for:\nFiles, messages, data',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary))),
              ]))),
        ]),
        const SizedBox(height: 16),
        if (snapshot.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Could not load live metrics: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 520;
            final steps = _securityStepsCard(context);
            final status = _liveStatusCard(
              loading: loading,
              metrics: metrics,
              recentLoginCount: recentLogins.length,
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: steps),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: status),
                ],
              );
            }
            return Column(
              children: [
                status,
                const SizedBox(height: 12),
                steps,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.shield_outlined, color: AppColors.success, size: 20),
            SizedBox(width: 8),
            Text('Best Practices',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.textPrimary))
          ]),
          const Text('Keep your account secure',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          ...[
            'Use strong, unique passwords',
            'Enable two-factor authentication',
            'Review login activity regularly',
            'Report suspicious activity immediately',
            'Keep your devices updated'
          ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(t,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary))
              ]))),
        ])),
          ]);
        },
      ),
    );
  }

  Widget _securityStepsCard(BuildContext context) {
    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Security pipeline',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap a step to open the related screen',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ..._steps.map((step) => _stepTile(context, step)),
        ],
      ),
    );
  }

  Widget _stepTile(BuildContext context, _SecurityOverviewStep step) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.pushNamed(context, step.route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(step.icon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        step.sub,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _liveStatusCard({
    required bool loading,
    required Map<String, dynamic>? metrics,
    required int recentLoginCount,
  }) {
    final failed = (metrics?['failed_logins'] as num?)?.toInt();
    final locked = (metrics?['locked_users'] as num?)?.toInt();
    final alerts = (metrics?['suspicious_activity_alerts'] as num?)?.toInt();
    final sessions = (metrics?['active_sessions'] as num?)?.toInt();

    return TCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live security status',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Real-time metrics from your database',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _metricRow(
            Icons.warning_amber_outlined,
            'Failed logins',
            loading ? '…' : '${failed ?? 0}',
            AppColors.error,
          ),
          _metricRow(
            Icons.lock_person_outlined,
            'Locked accounts',
            loading ? '…' : '${locked ?? 0}',
            AppColors.warning,
          ),
          _metricRow(
            Icons.notifications_active_outlined,
            'Open alerts',
            loading ? '…' : '${alerts ?? 0}',
            AppColors.primary,
          ),
          _metricRow(
            Icons.login,
            'Recent logins (sample)',
            loading ? '…' : '$recentLoginCount',
            AppColors.success,
          ),
          if (!loading && sessions != null)
            _metricRow(
              Icons.devices,
              'Active users (24h)',
              '$sessions',
              AppColors.textSecondary,
            ),
        ],
      ),
    );
  }

  Widget _metricRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Security Monitor ──────────────────────────────────────────────────────────
class SecurityMentorScreen extends StatelessWidget {
  const SecurityMentorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Security Monitor',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(16),
            child: Padding(
                padding: EdgeInsets.only(left: 16, bottom: 6),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('AI-powered threat detection',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary))))),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ]),
                    child: const Icon(Icons.cancel_outlined,
                        color: Colors.red, size: 20)),
                const SizedBox(width: 10),
                const Text('Suspicious Activity Detected',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontSize: 14))
              ]),
              const SizedBox(height: 6),
              const Text('john.doe@company.com',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Last Login',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary)),
                              Text('2:34 PM',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary))
                            ]))),
                const SizedBox(width: 8),
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Location',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary)),
                              Text('New York, US',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary))
                            ]))),
              ]),
            ])),
        const SizedBox(height: 16),
        const Text('Live Activity',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        TCard(
            child: Column(children: [
          ...[
            {
              'icon': Icons.login,
              'title': 'Login',
              'sub': '2:34 PM - New York',
              'time': '2m ago'
            },
            {
              'icon': Icons.description_outlined,
              'title': 'File Access',
              'sub': 'Downloaded 15 files',
              'time': '5m ago'
            },
            {
              'icon': Icons.location_on_outlined,
              'title': 'Location',
              'sub': 'IP: 192.168.1.1',
              'time': '8m ago'
            },
          ].map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle),
                    child: Icon(a['icon'] as IconData,
                        color: AppColors.primary, size: 16)),
                const SizedBox(width: 10),
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
                              fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                Text(a['time'] as String,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ]))),
        ])),
        const SizedBox(height: 12),
        const Row(children: [
          Icon(Icons.warning_amber_outlined,
              color: AppColors.warning, size: 18),
          SizedBox(width: 6),
          Text('Active Alerts',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary))
        ]),
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2))),
            child: const Row(children: [
              Icon(Icons.warning_amber_outlined,
                  color: AppColors.error, size: 18),
              SizedBox(width: 8),
              Text('Unusual login from new location',
                  style: TextStyle(color: AppColors.error, fontSize: 13))
            ])),
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.2))),
            child: const Row(children: [
              Icon(Icons.warning_amber_outlined,
                  color: AppColors.warning, size: 18),
              SizedBox(width: 8),
              Text('High file download activity detected',
                  style: TextStyle(color: AppColors.warning, fontSize: 13))
            ])),
        const SizedBox(height: 16),
        const Text('Suggested Actions',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        TButton(
            label: 'Enable 2FA',
            outline: true,
            onTap: () => Navigator.pushNamed(context, R.twoFAStatus)),
        const SizedBox(height: 8),
        OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, R.forceLogout),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size(double.infinity, 52)),
            child: const Text('Force Logout',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        TButton(
            label: 'Review Activity',
            outline: true,
            onTap: () => Navigator.pushNamed(context, R.reviewActivity)),
        const SizedBox(height: 10),
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 18)),
              const SizedBox(width: 12),
              const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Security Assistant',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 13)),
                    Text('Ask AI about this activity',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
            ])),
      ]),
    );
  }
}

// ── Force Logout ──────────────────────────────────────────────────────────────
class ForceLogoutScreen extends StatelessWidget {
  const ForceLogoutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final devices = [
      {
        'icon': Icons.phone_android_outlined,
        'name': 'iPhone 14 Pro',
        'loc': 'New York, US',
        'time': 'Active now',
        'suspicious': true
      },
      {
        'icon': Icons.desktop_windows_outlined,
        'name': 'MacBook Pro',
        'loc': 'San Francisco, US',
        'time': '2 hours ago',
        'suspicious': false
      },
      {
        'icon': Icons.desktop_windows_outlined,
        'name': 'Chrome Browser',
        'loc': 'Los Angeles, US',
        'time': '1 day ago',
        'suspicious': false
      },
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Force Logout',
              style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const PreferredSize(
              preferredSize: Size.fromHeight(16),
              child: Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 6),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Manage active sessions on your account',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)))))),
      body: Column(children: [
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: devices.length,
          itemBuilder: (_, i) {
            final d = devices[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: (d['suspicious'] as bool)
                          ? AppColors.error.withValues(alpha: 0.3)
                          : AppColors.border)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(d['icon'] as IconData,
                          color: (d['suspicious'] as bool)
                              ? AppColors.error
                              : AppColors.primary,
                          size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(d['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            Text(d['loc'] as String,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            Text(d['time'] as String,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ])),
                    ]),
                    if (d['suspicious'] as bool) ...[
                      const SizedBox(height: 6),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('Suspicious',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600))),
                    ],
                  ]),
            );
          },
        )),
        Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TButton(
                  label: 'Logout This Session',
                  outline: true,
                  onTap: () => Navigator.pop(context)),
              const SizedBox(height: 8),
              TButton(
                  label: 'Logout All Devices',
                  onTap: () =>
                      Navigator.pushNamed(context, R.logoutAllDevices)),
            ])),
      ]),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }
}

// ── Logout All Devices Confirmation ───────────────────────────────────────────
class LogoutAllDevicesScreen extends StatelessWidget {
  const LogoutAllDevicesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Force Logout',
              style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const PreferredSize(
              preferredSize: Size.fromHeight(16),
              child: Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 6),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Manage active sessions on your account',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)))))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06), blurRadius: 20)
                  ]),
              child: Column(children: [
                Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_outlined,
                        color: Colors.orange, size: 32)),
                const SizedBox(height: 16),
                const Text('Are you sure?',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                const Text(
                    "This will log out all devices. You'll need to sign in again on each device.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(
                            context, R.login, (_) => false),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 52)),
                        child: const Text('Yes, Logout All',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)))),
                const SizedBox(height: 10),
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size(double.infinity, 52)),
                        child: const Text('Cancel',
                            style: TextStyle(color: AppColors.textPrimary)))),
              ]),
            ),
          ]),
        ),
      ),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }
}

// ── Review Activity ───────────────────────────────────────────────────────────

class _ActivityLogEntry {
  final String title;
  final String timeLabel;
  final String category;
  final bool isAlert;
  final IconData icon;
  final Color color;
  final SecurityAlert? linkedAlert;
  final DateTime sortTime;

  const _ActivityLogEntry({
    required this.title,
    required this.timeLabel,
    required this.category,
    required this.isAlert,
    required this.icon,
    required this.color,
    this.linkedAlert,
    required this.sortTime,
  });
}

class _ReviewActivityData {
  final List<_ActivityLogEntry> entries;
  final AnomalyReport? anomaly;

  const _ReviewActivityData({
    required this.entries,
    this.anomaly,
  });
}

List<_ActivityLogEntry> _buildActivityEntries({
  required List<LoginLog> loginLogs,
  required List<Map<String, dynamic>> activity,
  required List<SecurityAlert> alerts,
}) {
  final entries = <_ActivityLogEntry>[];

  for (final log in loginLogs) {
    final failed = log.status.toLowerCase() == 'failed';
    entries.add(_ActivityLogEntry(
      title: failed
          ? 'Failed login attempt: ${log.userName}'
          : 'Successful login: ${log.userName}',
      timeLabel: '${log.date} ${log.time}',
      category: 'Login',
      isAlert: failed,
      icon: failed ? Icons.login : Icons.check_circle_outline,
      color: failed ? AppColors.error : AppColors.primary,
      sortTime: DateTime.tryParse(log.date) ?? DateTime.now(),
    ));
  }

  for (final item in activity) {
    final entity = (item['entity']?.toString() ?? '').toLowerCase();
    final action = item['action']?.toString() ?? 'Action';
    final details = item['details']?.toString() ?? '';
    final createdAt = item['created_at']?.toString() ?? '';
    final isFile = entity.contains('file');
    final isAlertEntity = entity.contains('alert');
    entries.add(_ActivityLogEntry(
      title: details.isNotEmpty ? details : '$action on ${item['entity']}',
      timeLabel: formatRelativeTime(createdAt).isNotEmpty
          ? formatRelativeTime(createdAt)
          : createdAt,
      category: isFile
          ? 'Files'
          : isAlertEntity
              ? 'Alerts'
              : 'All',
      isAlert: action.toUpperCase().contains('FAIL') ||
          action.toUpperCase().contains('ALERT'),
      icon: isFile
          ? Icons.description_outlined
          : isAlertEntity
              ? Icons.warning_amber_outlined
              : Icons.history,
      color: isAlertEntity ? AppColors.error : AppColors.primary,
      sortTime: DateTime.tryParse(createdAt) ?? DateTime.now(),
    ));
  }

  for (final alert in alerts) {
    entries.add(_ActivityLogEntry(
      title: alert.title,
      timeLabel: alert.time,
      category: 'Alerts',
      isAlert: !alert.isResolved,
      icon: Icons.warning_amber_outlined,
      color: alert.risk.contains('HIGH') ? AppColors.error : AppColors.warning,
      linkedAlert: alert,
      sortTime: DateTime.tryParse(alert.time.replaceFirst(' ', 'T')) ??
          DateTime.now(),
    ));
  }

  entries.sort((a, b) => b.sortTime.compareTo(a.sortTime));
  return entries;
}

class ReviewActivityScreen extends StatefulWidget {
  const ReviewActivityScreen({super.key});
  @override
  State<ReviewActivityScreen> createState() => _ReviewActivityScreenState();
}

class _ReviewActivityScreenState extends State<ReviewActivityScreen> {
  String _filter = 'All';
  final _searchCtrl = TextEditingController();
  Future<_ReviewActivityData>? _future;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startLoad();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startLoad() {
    setState(() {
      _future = _load();
    });
  }

  Future<_ReviewActivityData> _load() async {
    final admin = context.read<AppServices>().admin;
    final ai = context.read<AppServices>().ai;

    final loginLogsResult = await admin.listLoginLogs();
    final activityResult = await admin.getAdminActivity();
    final alertsResult = await admin.listAlerts();

    final loginLogs = loginLogsResult.data ?? const <LoginLog>[];
    final activityList = activityResult.data ?? [];
    final List<Map<String, dynamic>> activity = activityList.cast<Map<String, dynamic>>();
    final alerts = alertsResult.data ?? const <SecurityAlert>[];

    AnomalyReport? anomaly;
    try {
      final anomalyResult = await ai
          .detectAnomaly({})
          .timeout(const Duration(seconds: 12));
      anomaly = anomalyResult.data;
    } catch (_) {}

    return _ReviewActivityData(
      entries: _buildActivityEntries(
        loginLogs: loginLogs,
        activity: activity,
        alerts: alerts,
      ),
      anomaly: anomaly,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  List<_ActivityLogEntry> _filtered(List<_ActivityLogEntry> entries) {
    final query = _searchCtrl.text.trim().toLowerCase();
    return entries.where((e) {
      if (_filter != 'All' && e.category != _filter) return false;
      if (query.isNotEmpty && !e.title.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
  }

  void _openEntry(_ActivityLogEntry entry) {
    if (entry.linkedAlert != null) {
      Navigator.pushNamed(
        context,
        R.alertDetails,
        arguments: entry.linkedAlert,
      ).then((resolved) {
        if (resolved == true) _refresh();
      });
      return;
    }
    if (entry.isAlert) {
      Navigator.pushNamed(
        context,
        R.askAI,
        arguments: {'context': entry.title},
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(entry.title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Activity Log',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: _refresh,
            ),
          ]),
      body: FutureBuilder<_ReviewActivityData>(
        future: _future,
        builder: (context, snapshot) {
          if (_future == null ||
              (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Could not load activity: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
              ),
            );
          }

          final data = snapshot.data ??
              const _ReviewActivityData(entries: []);
          final items = _filtered(data.entries);
          final insight = data.anomaly?.summary.isNotEmpty == true
              ? data.anomaly!.summary
              : (items.any((e) => e.isAlert)
                  ? 'AI detected unusual behavior in recent login patterns.'
                  : 'No suspicious activity detected recently.');

          return Column(children: [
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Search activity...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.search,
                            color: AppColors.textSecondary, size: 18)),
                  ),
                )),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                        children: ['All', 'Login', 'Files', 'Alerts'].map((f) {
                      final sel = _filter == f;
                      return GestureDetector(
                          onTap: () => setState(() => _filter = f),
                          child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.primary
                                      : AppColors.background,
                                  shape: BoxShape.circle),
                              child: Text(f,
                                  style: TextStyle(
                                      color: sel
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13))));
                    }).toList()))),
            Expanded(
                child: RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _future;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No activity found for this filter.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    ...items.map((a) => GestureDetector(
                          onTap: () => _openEntry(a),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: a.color.withValues(alpha: 0.1),
                                        shape: BoxShape.circle),
                                    child: Icon(a.icon,
                                        color: a.color, size: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(a.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                              fontSize: 13)),
                                      Text(a.timeLabel,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary)),
                                    ])),
                                if (a.isAlert)
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: AppColors.error
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20)),
                                      child: const Text('Alert',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.error,
                                              fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, R.askAI,
                        arguments: {'context': insight}),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.tips_and_updates_outlined,
                                  color: Colors.white, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const Text('AI Insight',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        fontSize: 13)),
                                Text(insight,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TButton(
                    label: 'Report Issue',
                    outline: true,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Report Issue',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const TextField(
                            decoration: InputDecoration(
                              hintText: 'Describe the issue...',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Issue reported successfully!')));
                              },
                              child: const Text('Submit'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  TButton(
                      label: 'Ask AI',
                      onTap: () => Navigator.pushNamed(context, R.askAI,
                          arguments: {'context': insight})),
                ],
              ),
            )),
          ]);
        },
      ),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }
}

class _AskChatMessage {
  final bool fromUser;
  final String text;
  const _AskChatMessage({required this.fromUser, required this.text});
}

// ── Ask AI ────────────────────────────────────────────────────────────────────
class AskAIScreen extends StatefulWidget {
  const AskAIScreen({super.key});
  @override
  State<AskAIScreen> createState() => _AskAIScreenState();
}

class _AskAIScreenState extends State<AskAIScreen> {
  final _inputCtrl = TextEditingController();
  final List<_AskChatMessage> _messages = [];
  AnomalyReport? _anomaly;
  List<SecurityAlert> _alerts = const [];
  String _insight = 'Loading security insights…';
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    final seedContext =
        args is Map ? args['context']?.toString() : null;

    try {
      final admin = context.read<AppServices>().admin;
      final ai = context.read<AppServices>().ai;
      final alerts = await admin.listAlerts().unwrap();
      AnomalyReport? anomaly;
      try {
        anomaly = await ai.detectAnomaly({}).unwrap();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _anomaly = anomaly;
        _insight = seedContext ??
            anomaly?.summary ??
            (alerts.isNotEmpty
                ? alerts.first.description
                : 'No unusual activity detected in recent logs.');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _insight = 'Could not load security insights: $e';
        _loading = false;
      });
    }
  }

  Future<String> _answer(String question) async {
    final q = question.toLowerCase();
  final openAlerts =
        _alerts.where((a) => !a.isResolved).toList();

    if (q.contains('risk')) {
      final score = _anomaly?.riskScore ?? 0;
      return 'Risk score: ${score.toStringAsFixed(0)}/100. '
          '${openAlerts.length} unresolved alert(s). '
          '${_anomaly?.isAnomalous == true ? "Anomaly detected." : "No critical anomaly."}';
    }
    if (q.contains('suspicious') || q.contains('flagged') || q.contains('why')) {
      if (_anomaly != null && _anomaly!.anomalies.isNotEmpty) {
        return _anomaly!.anomalies
            .map((a) => '${a.type}: ${a.description}')
            .join('\n');
      }
      if (openAlerts.isNotEmpty) {
        return openAlerts
            .take(3)
            .map((a) => '${a.title}: ${a.description}')
            .join('\n');
      }
      return _insight;
    }
    if (q.contains('view activity')) {
      return 'Open Activity Log to review login attempts, file access, and alerts.';
    }
    if (q.contains('take action')) {
      return openAlerts.isEmpty
          ? 'No open alerts require action right now.'
          : 'Review Security Alerts and mark items as resolved when handled.';
    }

    final userId = context.read<SessionController>().currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      try {
        final reply = await context.read<AppServices>().ai.mentorChat(
              question:
                  'Security analyst question about platform activity: $question\nContext: $_insight',
            ).unwrap();
        if (reply.reply.trim().isNotEmpty) return reply.reply;
      } catch (_) {}
    }

    return _insight.isNotEmpty
        ? _insight
        : 'No additional insights available for that question.';
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputCtrl.text).trim();
    if (text.isEmpty || _sending) return;
    if (preset == null) _inputCtrl.clear();
    setState(() {
      _messages.add(_AskChatMessage(fromUser: true, text: text));
      _sending = true;
    });
    try {
      final reply = await _answer(text);
      if (!mounted) return;
      setState(() {
        _messages.add(_AskChatMessage(fromUser: false, text: reply));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Ask AI',
              style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const PreferredSize(
              preferredSize: Size.fromHeight(16),
              child: Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 6),
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          'Get insights about user activity and security alerts',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)))))),
      body: Column(children: [
        Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.tips_and_updates_outlined,
                                  color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text('AI Insight',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                            fontSize: 13)),
                                    Text(_insight,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ])),
                            ])),
                    const SizedBox(height: 16),
                    ..._messages.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Align(
                            alignment: m.fromUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: m.fromUser
                                    ? AppColors.primary
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                m.text,
                                style: TextStyle(
                                  color: m.fromUser
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        )),
                    if (_sending)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Text('Suggested questions',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'Why is this suspicious?',
                          'Show risk level',
                          'View Activity',
                          'Take Action',
                        ]
                            .map((q) => GestureDetector(
                                onTap: _sending
                                    ? null
                                    : () {
                                        if (q == 'View Activity') {
                                          Navigator.pushNamed(
                                              context, R.reviewActivity);
                                          return;
                                        }
                                        if (q == 'Take Action') {
                                          Navigator.pushNamed(
                                              context, R.securityAlerts);
                                          return;
                                        }
                                        _send(q);
                                      },
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: AppColors.border)),
                                    child: Text(q,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500)))))
                            .toList()),
                  ])),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Expanded(
                  child: TextField(
                controller: _inputCtrl,
                enabled: !_loading && !_sending,
                decoration: InputDecoration(
                  hintText: 'Ask about this activity...',
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: _loading || _sending ? null : () => _send(),
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: _loading || _sending
                              ? AppColors.border
                              : AppColors.primary,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.send,
                          color: Colors.white, size: 18))),
            ])),
      ]),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }
}

// ── 2FA Enable Screen ─────────────────────────────────────────────────────────
class TwoFAEnableScreen extends StatelessWidget {
  const TwoFAEnableScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Back',
              style: TextStyle(fontWeight: FontWeight.w500))),
      body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 36)),
            const SizedBox(height: 16),
            const Text('Enable 2FA',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Text('Add an extra layer of security to your account',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Phone Number',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        fontSize: 15))),
            const SizedBox(height: 8),
            TextField(
                decoration: InputDecoration(
                    hintText: '+1 (555) 000-0000',
                    hintStyle: const TextStyle(color: AppColors.textHint),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primary)))),
            const Spacer(),
            TButton(
                label: 'Send Code',
                onTap: () => Navigator.pushNamed(context, R.twoFAVerify)),
          ])),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }
}

// ── 2FA Verify Screen ─────────────────────────────────────────────────────────
class TwoFAVerifyScreen extends StatefulWidget {
  const TwoFAVerifyScreen({super.key});
  @override
  State<TwoFAVerifyScreen> createState() => _TwoFAVerifyScreenState();
}

class _TwoFAVerifyScreenState extends State<TwoFAVerifyScreen> {
  int _countdown = 0;

  void _resendCode() {
    if (_countdown > 0) return;
    setState(() => _countdown = 60);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Code resent to your phone!'),
      backgroundColor: AppColors.primary,
    ));
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Back',
              style: TextStyle(fontWeight: FontWeight.w500))),
      body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 36)),
            const SizedBox(height: 16),
            const Text('Enable 2FA',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Text('Add an extra layer of security to your account',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    6,
                    (index) => Container(
                          width: 40,
                          height: 48,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(10)),
                          child: TextField(
                            autofocus: index == 0,
                            onChanged: (v) {
                              if (v.length == 1 && index < 5) {
                                FocusScope.of(context).nextFocus();
                              }
                            },
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                                border: InputBorder.none, counterText: ''),
                          ),
                        ))),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _countdown == 0 ? _resendCode : null,
              child: RichText(
                  text: TextSpan(
                text: "Didn't receive the code? ",
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14),
                children: [
                  TextSpan(
                    text:
                        _countdown > 0 ? 'Resend in ${_countdown}s' : 'Resend',
                    style: TextStyle(
                      color: _countdown > 0
                          ? AppColors.textHint
                          : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                ],
              )),
            ),
            const Spacer(),
            TButton(
                label: 'Verify Code',
                onTap: () => Navigator.pushNamed(context, R.twoFASuccess)),
          ])),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }
}

// ── 2FA Success Screen ────────────────────────────────────────────────────────
class TwoFASuccessScreen extends StatelessWidget {
  const TwoFASuccessScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Back',
              style: TextStyle(fontWeight: FontWeight.w500))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.shield_outlined,
                    color: AppColors.primary, size: 36)),
            const SizedBox(height: 16),
            const Text('Enable 2FA',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Text('Add an extra layer of security to your account',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center),
            const Spacer(),
            Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: AppColors.success, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 36)),
            const SizedBox(height: 16),
            const Text('2FA Enabled Successfully',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Text('Your account is now more secure',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const Spacer(),
            TButton(
                label: 'Done',
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context, R.adminHome, (_) => false)),
          ],
        ),
      ),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }
}

// ── Add User Screen ──────────────────────────────────────────────────────────
class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});
  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'Freelancer';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _saving = true);
    final res = await context.read<AppServices>().admin.createUser(
          fullName: name,
          email: email,
          password: password,
          role: _role,
        );
    if (!mounted) return;
    setState(() => _saving = false);

    res.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User account created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      },
      failure: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Add New User',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Full Name',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                    controller: _nameCtrl,
                    decoration: _dec('Enter full name', Icons.person_outline)),
                const SizedBox(height: 16),
                const Text('Email Address',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        _dec('Enter email address', Icons.email_outlined)),
                const SizedBox(height: 16),
                const Text('Assign Role',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border)),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                    value: _role,
                    isExpanded: true,
                    items: ['Admin', 'Freelancer', 'Student']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: _saving ? null : (v) => setState(() => _role = v!),
                  )),
                ),
                const SizedBox(height: 16),
                const Text('Temporary Password',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration:
                        _dec('Min 8 chars, 1 uppercase, 1 digit', Icons.lock_outline)),
              ])),
          const SizedBox(height: 24),
          TButton(
              label: _saving ? 'Creating…' : 'Create User Account',
              onTap: _saving ? null : _create),
          const SizedBox(height: 10),
          TButton(
              label: 'Cancel',
              outline: true,
              onTap: _saving ? null : () => Navigator.pop(context)),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: const Color(0xFFF5F5FA),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
      );
}

// ── User Details Admin ───────────────────────────────────────────────────────
class UserDetailsAdminScreen extends StatefulWidget {
  final api.ApiUser? initialUser;

  const UserDetailsAdminScreen({super.key, this.initialUser});

  @override
  State<UserDetailsAdminScreen> createState() => _UserDetailsAdminScreenState();
}

class _UserDetailsAdminScreenState extends State<UserDetailsAdminScreen> {
  api.ApiUser? _user;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_user != null) return;
    if (widget.initialUser != null) {
      _user = widget.initialUser;
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is api.ApiUser) {
      _user = args;
    } else if (args is UserModel) {
      _user = api.ApiUser(
        id: args.id,
        displayName: args.name,
        fullName: args.name,
        email: args.email,
        role: args.role.toLowerCase(),
        userType: args.role.toLowerCase(),
        skills: args.skills,
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _updateStatus(String action, {String reason = ''}) async {
    final u = _user!;
    await _run(() async {
      await context
          .read<AppServices>()
          .admin
          .updateUserStatus(u.id, action, reason: reason)
          .unwrap();
      String newStatus = u.accountStatus;
      switch (action) {
        case 'approve':
        case 'unlock':
          newStatus = 'approved';
          break;
        case 'suspend':
          newStatus = 'suspended';
          break;
        case 'lock':
          newStatus = 'locked';
          break;
        case 'reject':
          newStatus = 'rejected';
          break;
      }
      setState(() => _user = api.ApiUser(
            id: u.id,
            displayName: u.displayName,
            fullName: u.fullName,
            email: u.email,
            role: u.role,
            userType: u.userType,
            skills: u.skills,
            professionalField: u.professionalField,
            availability: u.availability,
            experienceLevel: u.experienceLevel,
            joinedAt: u.joinedAt,
            phone: u.phone,
            bio: u.bio,
            avatarFileId: u.avatarFileId,
            accountStatus: newStatus,
          ));
      _snack('User account updated ($action)');
    });
  }

  Future<void> _changeRole(String role) async {
    final u = _user!;
    await _run(() async {
      await context.read<AppServices>().admin.changeUserRole(u.id, role).unwrap();
      setState(() => _user = api.ApiUser(
            id: u.id,
            displayName: u.displayName,
            fullName: u.fullName,
            email: u.email,
            role: role,
            userType: u.userType,
            skills: u.skills,
            professionalField: u.professionalField,
            availability: u.availability,
            experienceLevel: u.experienceLevel,
            joinedAt: u.joinedAt,
            phone: u.phone,
            bio: u.bio,
            avatarFileId: u.avatarFileId,
            accountStatus: u.accountStatus,
          ));
      _snack('Role updated to $role');
    });
  }

  Future<void> _resetPassword(String password) async {
    final u = _user!;
    await _run(() async {
      await context
          .read<AppServices>()
          .admin
          .resetUserPassword(u.id, password)
          .unwrap();
      _snack('Password reset successfully');
    });
  }

  Future<void> _deleteUser() async {
    if (_busy) return;
    final u = _user!;
    setState(() => _busy = true);
    final res = await context.read<AppServices>().admin.deleteUser(u.id);
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      success: (_) {
        _snack('User deleted');
        Navigator.pop(context, true);
      },
      failure: (msg) => _snack(msg, error: true),
    );
  }

  void _showViewProfile() {
    final u = _user!;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (_, scroll) => FutureBuilder<api.ApiUser?>(
          future: context.read<AppServices>().users.getPublicProfile(u.id).then(
                (r) => r.data,
              ),
          builder: (context, snap) {
            final p = snap.data ?? u;
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
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
                Text(
                  p.primaryName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '@${p.displayName}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (snap.connectionState == ConnectionState.waiting)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  _infoRow(Icons.email_outlined, 'Email', p.email),
                  _infoRow(Icons.phone_outlined, 'Phone',
                      p.phone.isNotEmpty ? p.phone : '—'),
                  _infoRow(Icons.info_outline, 'Bio',
                      p.bio.isNotEmpty ? p.bio : '—'),
                  _infoRow(Icons.work_outline, 'Type', p.displayRole),
                  if (p.skills.isNotEmpty)
                    _infoRow(Icons.lightbulb_outline, 'Skills', p.skillsSummary),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showRoleDialog() {
    final u = _user!;
    final systemRole = u.role.toLowerCase();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        var sel = systemRole;
        if (!['admin', 'member', 'guest'].contains(sel)) sel = 'member';
        return StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            title: const Text('Change User Role'),
            content: DropdownButtonFormField<String>(
              initialValue: sel,
              items: const [
                DropdownMenuItem(value: 'member', child: Text('Member')),
                DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                DropdownMenuItem(value: 'guest', child: Text('Guest')),
              ],
              onChanged: (v) => setDialog(() => sel = v ?? sel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _changeRole(sel);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuspendDialog() {
    final status = _user!.accountStatus.toLowerCase();
    final isRestricted = status == 'suspended' || status == 'locked';

    if (isRestricted) {
      _updateStatus('unlock');
      return;
    }

    final reasonCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend User?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            hintText: 'Reason (optional)',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus('suspend', reason: reasonCtrl.text.trim());
            },
            child: const Text(
              'Suspend',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog() {
    final passwordCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: passwordCtrl,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'New password (min 8 chars, 1 upper, 1 digit)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final pw = passwordCtrl.text.trim();
              if (!RegExp(r'^(?=.*[A-Z])(?=.*\d).{8,}$').hasMatch(pw)) {
                _snack(
                  'Password must be 8+ chars with uppercase and digit',
                  error: true,
                );
                return;
              }
              Navigator.pop(ctx);
              _resetPassword(pw);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    final u = _user!;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete User?'),
        content: Text(
          'Permanently delete ${u.primaryName}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUser();
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('User Management',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No user selected or data is invalid.',
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
    final u = user;
    final statusColor = u.accountStatus.toLowerCase() == 'approved'
        ? AppColors.success
        : u.isPending
            ? AppColors.warning
            : AppColors.error;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('User Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Stack(
        children: [
          ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TCard(
            child: Column(children: [
              TAvatar(initials: u.initials, radius: 40),
              const SizedBox(height: 12),
              Text(u.primaryName,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text('@${u.displayName}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TChip(
                      label: u.accountStatusLabel,
                      bg: statusColor.withValues(alpha: 0.1),
                      textColor: statusColor),
                  const SizedBox(width: 8),
                  TChip(
                      label: u.displayRole,
                      bg: AppColors.primary.withValues(alpha: 0.1),
                      textColor: AppColors.primary),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const TSectionHeader(title: 'Account Information'),
          const SizedBox(height: 12),
          TCard(
              child: Column(children: [
            _infoRow(Icons.email_outlined, 'Email Address',
                u.email.isNotEmpty ? u.email : '—'),
            const Divider(height: 1, color: AppColors.border),
            _infoRow(Icons.phone_outlined, 'Phone',
                u.phone.isNotEmpty ? u.phone : '—'),
            const Divider(height: 1, color: AppColors.border),
            _infoRow(Icons.info_outline, 'Bio',
                u.bio.isNotEmpty ? u.bio : '—'),
            const Divider(height: 1, color: AppColors.border),
            _infoRow(Icons.work_outline, 'Professional field',
                u.professionalField.isNotEmpty ? u.professionalField : '—'),
            const Divider(height: 1, color: AppColors.border),
            _infoRow(Icons.calendar_today_outlined, 'Joined',
                u.joinedAt.isNotEmpty ? u.joinedAt.split('T').first : '—'),
            if (u.skills.isNotEmpty) ...[
              const Divider(height: 1, color: AppColors.border),
              _infoRow(Icons.lightbulb_outline, 'Skills', u.skillsSummary),
            ],
          ])),
          const SizedBox(height: 24),
          const TSectionHeader(title: 'Admin Actions'),
          const SizedBox(height: 12),
          TCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _actionTile(
                  Icons.person_outline,
                  'View User Profile',
                  _busy ? () {} : _showViewProfile,
                ),
                _actionTile(
                  Icons.swap_horiz,
                  'Change User Role',
                  _busy ? () {} : _showRoleDialog,
                ),
                _actionTile(
                  Icons.block,
                  u.accountStatus.toLowerCase() == 'suspended' ||
                          u.accountStatus.toLowerCase() == 'locked'
                      ? 'Unlock User'
                      : 'Suspend User',
                  _busy ? () {} : _showSuspendDialog,
                  isDestructive:
                      u.accountStatus.toLowerCase() != 'suspended' &&
                          u.accountStatus.toLowerCase() != 'locked',
                ),
                _actionTile(
                  Icons.lock_reset,
                  'Reset Password',
                  _busy ? () {} : _showResetPasswordDialog,
                ),
                _actionTile(
                  Icons.delete_outline,
                  'Delete User',
                  _busy ? () {} : _confirmDelete,
                  isDestructive: true,
                ),
              ])),
          const SizedBox(height: 32),
        ],
      ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
          ]),
        ]),
      );

  Widget _actionTile(IconData icon, String label, VoidCallback onTap,
          {bool isDestructive = false}) =>
      ListTile(
        onTap: onTap,
        leading: Icon(icon,
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
            size: 20),
        title: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color:
                    isDestructive ? AppColors.error : AppColors.textPrimary)),
        trailing: const Icon(Icons.arrow_forward_ios,
            size: 14, color: AppColors.textHint),
      );
}

// ── Edit Role Permissions ────────────────────────────────────────────────────
class EditRolePermissionsScreen extends StatefulWidget {
  const EditRolePermissionsScreen({super.key});
  @override
  State<EditRolePermissionsScreen> createState() =>
      _EditRolePermissionsScreenState();
}

class _EditRolePermissionsScreenState extends State<EditRolePermissionsScreen> {
  Map<String, dynamic>? _role;
  List<String> _perms = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_role == null) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _role = args;
        _perms = List<String>.from(_role!['perms'] as List<String>);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Text('Edit ${_role!['name']} Role',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TCard(
                    child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: (_role!['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.shield_outlined,
                          color: _role!['color'] as Color, size: 24)),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_role!['name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${_role!['count']} active members',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                ])),
                const SizedBox(height: 24),
                const TSectionHeader(title: 'Permissions Management'),
                const SizedBox(height: 12),
                TCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      ...[
                        'Manage Users',
                        'Manage Roles',
                        'View Reports',
                        'Security Monitoring',
                        'Platform Analytics',
                        'Projects',
                        'Tasks',
                        'Chat',
                        'AI Tools',
                        'Files'
                      ].map((p) => CheckboxListTile(
                            title:
                                Text(p, style: const TextStyle(fontSize: 14)),
                            value: _perms.contains(p),
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(
                                () => v! ? _perms.add(p) : _perms.remove(p)),
                          )),
                    ])),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [
              BoxShadow(
                  color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))
            ]),
            child: SafeArea(
                child: Row(children: [
              Expanded(
                  child: TButton(
                      label: 'Cancel',
                      outline: true,
                      onTap: () => Navigator.pop(context))),
              const SizedBox(width: 12),
              Expanded(
                  child: TButton(
                      label: 'Save Changes',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Permissions updated successfully')));
                        Navigator.pop(context);
                      })),
            ])),
          ),
        ],
      ),
    );
  }
}
