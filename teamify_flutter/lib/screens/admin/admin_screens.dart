import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/models/models.dart' as api;
import '../../data/repositories/app_repositories.dart';
import '../../models/models.dart';
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
            color: Colors.black.withOpacity(0.08),
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
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Premium Admin Header
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
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.security,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    _adminStat('Active Users', '2,847', Icons.people_outline),
                    const SizedBox(width: 12),
                    _adminStat('Sec Alerts', '12', Icons.warning_amber_outlined,
                        isAlert: true),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TSectionHeader(
                    title: 'Platform Analytics',
                    action: 'Full Report',
                    onAction: () => Navigator.pushNamed(context, R.analyst)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _analyticsCard('Server', 'Global',
                            Icons.language, AppColors.success)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _analyticsCard('Reports', '142',
                            Icons.description_outlined, AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 24),
                const TSectionHeader(title: 'Management Hub'),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.4,
                  children: [
                    _hubCard(
                        context, 'Users', Icons.group_outlined, R.adminUsers),
                    _hubCard(
                        context, 'Roles', Icons.shield_outlined, R.adminRoles),
                    _hubCard(
                        context, 'Logs', Icons.list_alt_outlined, R.loginLogs),
                    _hubCard(context, 'Settings', Icons.settings_outlined,
                        R.settings),
                  ],
                ),
                const SizedBox(height: 32),
              ],
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
              color: Colors.white.withOpacity(0.1),
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

  Widget _hubCard(
          BuildContext context, String title, IconData icon, String route) =>
      TCard(
        onTap: () => Navigator.pushNamed(context, route),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      );
}

// ── Admin Users ───────────────────────────────────────────────────────────────
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<UserModel>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _loadUsers();
  }

  Future<List<UserModel>> _loadUsers() {
    return context
        .read<AppRepositories>()
        .admin
        .listUsers()
        .then((users) => users.map((user) => user.toDisplayModel()).toList());
  }

  void _retryUsers() {
    setState(() {
      _usersFuture = _loadUsers();
    });
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
              onPressed: () => Navigator.pushNamed(context, R.addUser))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border)),
            child: const TextField(
                decoration: InputDecoration(
                    hintText: 'Search users...',
                    border: InputBorder.none,
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.textSecondary))),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<UserModel>>(
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
              final users = snapshot.data!;
              if (users.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                      child: Text('No users found',
                          style: TextStyle(color: AppColors.textSecondary))),
                );
              }
              return Column(
                children: users
                    .map((u) => TCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          onTap: () => Navigator.pushNamed(
                              context, R.adminUserDetails,
                              arguments: u),
                          child: Row(children: [
                            TAvatar(initials: u.initials, radius: 22),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(u.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary)),
                                  Text(u.role,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ])),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  TChip(
                                      label: u.role,
                                      bg: AppColors.primary.withOpacity(0.1),
                                      textColor: AppColors.primary),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    const Icon(Icons.star,
                                        size: 12, color: Colors.amber),
                                    const SizedBox(width: 2),
                                    Text('${u.rating}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary))
                                  ]),
                                ]),
                          ]),
                        ))
                    .toList(),
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
class AdminRolesScreen extends StatelessWidget {
  const AdminRolesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> roles = [
      {
        'name': 'Admin',
        'count': 1,
        'perms': ['All Access', 'Manage Users', 'Security'],
        'color': AppColors.error
      },
      {
        'name': 'Freelancer',
        'count': 2,
        'perms': ['Projects', 'Tasks', 'Chat', 'AI Tools'],
        'color': AppColors.primary
      },
      {
        'name': 'Student',
        'count': 2,
        'perms': ['View Projects', 'Tasks', 'Chat'],
        'color': AppColors.success
      },
    ];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Role-Based Access',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: roles.length,
        itemBuilder: (_, i) {
          final r = roles[i];
          return TCard(
            margin: const EdgeInsets.only(bottom: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: (r['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.shield_outlined,
                        color: r['color'] as Color, size: 22)),
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
                      Text('${r['count']} members',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ])),
                IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 18, color: AppColors.primary),
                    onPressed: () => Navigator.pushNamed(
                        context, R.editRolePermissions,
                        arguments: r)),
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
                  children: (r['perms'] as List<String>)
                      .map((p) => TChip(
                          label: p,
                          bg: (r['color'] as Color).withOpacity(0.1),
                          textColor: r['color'] as Color))
                      .toList()),
            ]),
          );
        },
      ),
    );
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
                    bg: priColor.withOpacity(0.1),
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
            Positioned(
                top: 8,
                right: 8,
                child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Center(
                        child: Text('2',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold))))),
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
            child: const TextField(
                decoration: InputDecoration(
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
            load: () => context.read<AppRepositories>().admin.listLoginLogs(),
            isEmpty: (logs) => logs.isEmpty,
            emptyMessage: 'No login logs found',
            builder: (context, logs) {
              final filteredLogs = logs.where((l) {
                if (_filter == 'Success') return l.isSuccess;
                if (_filter == 'Failed') return !l.isSuccess;
                return true;
              }).toList();
              if (filteredLogs.isEmpty) {
                return const Center(
                  child: Text('No login logs found',
                      style: TextStyle(color: AppColors.textSecondary)),
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
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.error.withOpacity(0.1),
                              textColor: l.isSuccess
                                  ? AppColors.success
                                  : AppColors.error),
                          const SizedBox(height: 8),
                          Row(children: [
                            Icon(
                                l.device.contains('Desktop')
                                    ? Icons.desktop_windows_outlined
                                    : Icons.phone_android_outlined,
                                size: 14,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(l.device,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const Spacer(),
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
class SecurityAlertsScreen extends StatelessWidget {
  const SecurityAlertsScreen({super.key});
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
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.pushNamed(context, R.notifications)),
            Positioned(
                top: 8,
                right: 8,
                child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Center(
                        child: Text('2',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold))))),
          ]),
        ],
      ),
      body: RepositoryLoader<List<SecurityAlert>>(
        load: () => context.read<AppRepositories>().admin.listAlerts(),
        isEmpty: (alerts) => alerts.isEmpty,
        emptyMessage: 'No security alerts found',
        builder: (context, alerts) => ListView.builder(
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
              onTap: () =>
                  Navigator.pushNamed(context, R.alertDetails, arguments: a),
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
                              color: riskColor.withOpacity(0.1),
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
                                  bg: riskColor.withOpacity(0.1),
                                  textColor: riskColor,
                                  fontSize: 10),
                              const SizedBox(width: 6),
                              TChip(
                                  label: a.status,
                                  bg: a.status == 'New'
                                      ? AppColors.primary.withOpacity(0.1)
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
        ),
      ),
    );
  }
}

// ── Alert Details (Modal style) ───────────────────────────────────────────────
class AlertDetailsScreen extends StatelessWidget {
  const AlertDetailsScreen({super.key});
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
                              onTap: () => Navigator.pop(context))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TButton(
                              label: 'Mark as Resolved',
                              onTap: () => Navigator.pop(context))),
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
class SecurityMonitorScreen extends StatelessWidget {
  const SecurityMonitorScreen({super.key});

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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('AI powered threat detection',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),

          // Suspicious Activity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.error.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.error.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.cancel_outlined,
                      color: AppColors.error, size: 28),
                ),
                const SizedBox(height: 12),
                const Text('Suspicious Activity Detected',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary)),
                const Text('john.doe@company.com',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      Text('Last Login',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                      Text('2:14 PM',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13))
                    ]),
                    Column(children: [
                      Text('Location',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                      Text('New York, US',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13))
                    ]),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Live Activity',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _liveItem(Icons.login, 'Login', '2:14 PM - New York', '2m ago'),
          _liveItem(Icons.description_outlined, 'File Access',
              'Downloaded 15 files', '5m ago'),
          _liveItem(Icons.location_on_outlined, 'Location', 'IP: 192.168.1.1',
              '8m ago'),

          const SizedBox(height: 24),
          const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
            SizedBox(width: 8),
            Text('Active Alerts',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
          ]),
          const SizedBox(height: 12),
          _alertItem('Unusual login from new location'),
          _alertItem('High file download activity detected'),

          const SizedBox(height: 24),
          const Text('Suggested Actions',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _suggestedAction(context, 'Enable 2FA', R.twoFAStatus),
          _suggestedAction(context, 'Force Logout', R.forceLogout,
              color: AppColors.error),
          _suggestedAction(context, 'Review Activity', R.reviewActivity),

          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, R.askAI),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
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
                                fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }

  Widget _liveItem(IconData icon, String title, String sub, String time) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
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
                          color: AppColors.textSecondary, fontSize: 12)),
                ])),
            Text(time,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      );

  Widget _alertItem(String text) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

  Widget _suggestedAction(BuildContext context, String label, String route,
          {Color color = AppColors.primary}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: OutlinedButton(
          onPressed: () => Navigator.pushNamed(context, route),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color.withOpacity(0.3)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            minimumSize: const Size(double.infinity, 48),
          ),
          child: Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ),
      );
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
                  color: AppColors.success.withOpacity(0.1),
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
                  bg: AppColors.success.withOpacity(0.1),
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
class AnalystScreen extends StatelessWidget {
  const AnalystScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              const Text('Analytics',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const Text('Platform insights',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              _analyticStat(Icons.people_outline, 'Total Users', '2,847',
                  '↗ +12%', AppColors.success),
              const SizedBox(height: 12),
              _analyticStat(Icons.check_circle_outline, 'Task Completion',
                  '84%', '↗ +5%', AppColors.success),
              const SizedBox(height: 12),
              _analyticStat(Icons.access_time_outlined, 'Avg Response Time',
                  '2.4h', '↘ -18%', AppColors.success),
              const SizedBox(height: 24),
              const Text('User Activity',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              TCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Last 7 days',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                              Text('Weekly view',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.primary)),
                            ]),
                        const SizedBox(height: 60),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun'
                            ]
                                .map((d) => Text(d,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.textSecondary)))
                                .toList()),
                      ])),
              const SizedBox(height: 24),
              const Text('Task Completion Rate',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              TCard(
                  child: Column(children: [
                _rateRow('On Time', '72%', 0.72, AppColors.success),
                const SizedBox(height: 12),
                _rateRow('Delayed', '18%', 0.18, AppColors.warning),
                const SizedBox(height: 12),
                _rateRow('Overdue', '10%', 0.10, AppColors.error),
              ])),
              const SizedBox(height: 24),
              const Text('Workload Distribution',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              TCard(
                  child: Column(children: [
                _workRow('Frontend Team', 0.85),
                const SizedBox(height: 12),
                _workRow('Backend Team', 0.68),
                const SizedBox(height: 12),
                _workRow('Design Team', 0.72),
                const SizedBox(height: 12),
                _workRow('QA Team', 0.55),
              ])),
              const SizedBox(height: 20),
            ]),
      ),
      bottomNavigationBar: _AdminBottomNav(current: 1, ctx: context),
    );
  }

  Widget _analyticStat(IconData icon, String label, String value, String trend,
      Color trendColor) {
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
              ])),
          Text(trend,
              style: TextStyle(
                  fontSize: 12,
                  color: trendColor,
                  fontWeight: FontWeight.w600)),
        ]));
  }

  Widget _rateRow(String label, String pct, double val, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        Text(pct,
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      TBar(value: val, color: color, height: 6),
    ]);
  }

  Widget _workRow(String team, double val) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(team,
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
        Text('${(val * 100).toInt()}%',
            style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      TBar(value: val, color: AppColors.primary, height: 6),
    ]);
  }
}

// ── Secure Files ──────────────────────────────────────────────────────────────
class SecurityFilesScreen extends StatelessWidget {
  const SecurityFilesScreen({super.key});
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
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.pushNamed(context, R.notifications)),
            Positioned(
                top: 8,
                right: 8,
                child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Center(
                        child: Text('2',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold))))),
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
                    color: AppColors.primary.withOpacity(0.08),
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
            TButton(label: 'Select Files', onTap: () {}),
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
            load: () => context.read<AppRepositories>().files.listFiles(),
            isEmpty: (files) => files.isEmpty,
            emptyMessage: 'No uploaded files found',
            builder: (context, files) => ListView.builder(
              itemCount: files.length,
              itemBuilder: (_, i) {
                final f = files[i];
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
                                  color: AppColors.primary.withOpacity(0.1),
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
                              ])),
                          IconButton(
                              icon: const Icon(Icons.close,
                                  size: 18, color: AppColors.textSecondary),
                              onPressed: () {}),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          TChip(
                              label: '🔒 Encrypted',
                              bg: AppColors.success.withOpacity(0.1),
                              textColor: AppColors.success,
                              fontSize: 11),
                          const SizedBox(width: 6),
                          TChip(
                              label: '✓ Verified',
                              bg: AppColors.success.withOpacity(0.1),
                              textColor: AppColors.success,
                              fontSize: 11),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Text(
                              f.createdAt.isNotEmpty
                                  ? f.createdAt
                                  : 'Unknown date',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const Spacer(),
                          GestureDetector(
                              onTap: () {},
                              child: const Row(children: [
                                Icon(Icons.download_outlined,
                                    size: 16, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text('Download',
                                    style: TextStyle(
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
class SecurityCenterScreen extends StatelessWidget {
  const SecurityCenterScreen({super.key});
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
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary),
                onPressed: () {}),
            Positioned(
                top: 8,
                right: 8,
                child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Center(
                        child: Text('2',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold))))),
          ])
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withOpacity(0.3))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.shield_outlined, color: Colors.orange, size: 18),
              SizedBox(width: 8),
              Text('Suspicious Activity Detected',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 13))
            ]),
            const SizedBox(height: 4),
            const Text(
                'We noticed a login from an unfamiliar location. Was this you?',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            Row(children: [
              GestureDetector(
                  onTap: () => Navigator.pushNamed(context, R.reviewActivity),
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('View Details',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)))),
              const SizedBox(width: 10),
              GestureDetector(
                  onTap: () {},
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border)),
                      child: const Text('Dismiss',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 12)))),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(16)),
          child: const Column(children: [
            Text('Welcome to Security Center',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            SizedBox(height: 6),
            Text('Monitor and manage your account security from one place.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
        Stack(children: [
          _secItem(
              context,
              Icons.warning_amber_outlined,
              const Color(0xFFFFF8EE),
              AppColors.warning,
              'Security Alerts',
              'Suspicious activity notifications',
              R.securityAlerts),
          Positioned(
              top: 12,
              right: 50,
              child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: const Center(
                      child: Text('2',
                          style: TextStyle(
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
      ]),
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

// ── Security Overview ─────────────────────────────────────────────────────────
class SecurityOverviewScreen extends StatelessWidget {
  const SecurityOverviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Security Overview',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
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
        TCard(
            child: Column(children: [
          ...[
            {
              'icon': Icons.key_outlined,
              'title': '1. Login',
              'sub': 'User enters credentials'
            },
            {
              'icon': Icons.lock_outline,
              'title': '2. Encryption',
              'sub': 'Data is encrypted in transit'
            },
            {
              'icon': Icons.storage_outlined,
              'title': '3. Storage',
              'sub': 'Secure database storage'
            },
            {
              'icon': Icons.visibility_outlined,
              'title': '4. Monitoring',
              'sub': 'Continuous activity tracking'
            },
            {
              'icon': Icons.notifications_outlined,
              'title': '5. Alerts',
              'sub': 'Suspicious activity notification'
            },
          ].map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(s['icon'] as IconData,
                        color: AppColors.primary, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(s['title'] as String,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 13)),
                      Text(s['sub'] as String,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ])),
                const Icon(Icons.arrow_forward_ios,
                    size: 12, color: AppColors.textSecondary),
              ]))),
        ])),
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
      ]),
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
                border: Border.all(color: AppColors.error.withOpacity(0.3))),
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
                        color: AppColors.primary.withOpacity(0.08),
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
                border: Border.all(color: AppColors.error.withOpacity(0.2))),
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
                border: Border.all(color: AppColors.warning.withOpacity(0.2))),
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
                          ? AppColors.error.withOpacity(0.3)
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
                              color: AppColors.error.withOpacity(0.1),
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
                        color: Colors.black.withOpacity(0.06), blurRadius: 20)
                  ]),
              child: Column(children: [
                Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
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
class ReviewActivityScreen extends StatefulWidget {
  const ReviewActivityScreen({super.key});
  @override
  State<ReviewActivityScreen> createState() => _ReviewActivityScreenState();
}

class _ReviewActivityScreenState extends State<ReviewActivityScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Activity Log',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12)),
              child: const TextField(
                  decoration: InputDecoration(
                      hintText: 'Search activity...',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search,
                          color: AppColors.textSecondary, size: 18))),
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
            child: ListView(padding: const EdgeInsets.all(16), children: [
          ...[
            {
              'icon': Icons.login,
              'title': 'Login from new location',
              'time': '2m ago',
              'alert': true,
              'color': AppColors.error
            },
            {
              'icon': Icons.download_outlined,
              'title': 'Downloaded 15 files',
              'time': '5m ago',
              'alert': true,
              'color': AppColors.error
            },
            {
              'icon': Icons.location_on_outlined,
              'title': 'Location changed to New York',
              'time': '8m ago',
              'alert': false,
              'color': AppColors.primary
            },
            {
              'icon': Icons.check_circle_outline,
              'title': 'Successful login',
              'time': '1h ago',
              'alert': false,
              'color': AppColors.primary
            },
            {
              'icon': Icons.description_outlined,
              'title': 'Accessed secure document',
              'time': '2h ago',
              'alert': false,
              'color': AppColors.primary
            },
          ].map((a) => GestureDetector(
                onTap: () {
                  if (a['alert'] as bool) {
                    Navigator.pushNamed(context, R.askAI);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Activity: ${a['title']}')));
                  }
                },
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
                              color: (a['color'] as Color).withOpacity(0.1),
                              shape: BoxShape.circle),
                          child: Icon(a['icon'] as IconData,
                              color: a['color'] as Color, size: 18)),
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
                            Text(a['time'] as String,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)),
                          ])),
                      if (a['alert'] as bool)
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20)),
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
            onTap: () => Navigator.pushNamed(context, R.askAI),
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
                      child: const Icon(Icons.warning_amber_outlined,
                          color: Colors.white, size: 18)),
                  const SizedBox(width: 12),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('AI Insight',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 13)),
                        Text(
                            'AI detected unusual behavior in recent login patterns',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
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
                                content: Text('Issue reported successfully!')));
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
              onTap: () => Navigator.pushNamed(context, R.askAI)),
        ])),
      ]),
      bottomNavigationBar: _AdminBottomNav(current: 2, ctx: context),
    );
  }
}

// ── Ask AI ────────────────────────────────────────────────────────────────────
class AskAIScreen extends StatefulWidget {
  const AskAIScreen({super.key});
  @override
  State<AskAIScreen> createState() => _AskAIScreenState();
}

class _AskAIScreenState extends State<AskAIScreen> {
  bool _answered = false;

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
            child: ListView(padding: const EdgeInsets.all(16), children: [
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14)),
              child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.tips_and_updates_outlined,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('AI Insight',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 13)),
                          Text(
                              'Unusual behavior detected due to login from Germany at 2:13 AM, outside normal hours (9AM–5PM).',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ])),
                  ])),
          const SizedBox(height: 16),
          Align(
              alignment: Alignment.centerRight,
              child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16)),
                  child: const Text('Why was this login flagged?',
                      style: TextStyle(color: Colors.white, fontSize: 13)))),
          const SizedBox(height: 12),
          if (_answered)
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14)),
                child: const Text(
                    'This login was flagged because it occurred from a new location and outside the user\'s usual login hours.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.textPrimary))),
          const SizedBox(height: 16),
          const Text('Suggested questions',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                'Why is this suspicious?',
                'Show risk level',
                'View Activity',
                'Take Action'
              ]
                  .map((q) => GestureDetector(
                      onTap: () => setState(() => _answered = true),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border)),
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
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(24)),
                      child: const Text('Ask about this activity...',
                          style: TextStyle(
                              color: AppColors.textHint, fontSize: 13)))),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: () => setState(() => _answered = true),
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
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
                    color: AppColors.primary.withOpacity(0.08),
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
                    color: AppColors.primary.withOpacity(0.08),
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
                    color: AppColors.primary.withOpacity(0.08),
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
  String _role = 'Freelancer';
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
                    decoration: _dec('Enter full name', Icons.person_outline)),
                const SizedBox(height: 16),
                const Text('Email Address',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
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
                    onChanged: (v) => setState(() => _role = v!),
                  )),
                ),
                const SizedBox(height: 16),
                const Text('Temporary Password',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                    obscureText: true,
                    decoration:
                        _dec('Enter temporary password', Icons.lock_outline)),
              ])),
          const SizedBox(height: 24),
          TButton(
              label: 'Create User Account',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('User account created successfully!')));
                Navigator.pop(context);
              }),
          const SizedBox(height: 10),
          TButton(
              label: 'Cancel',
              outline: true,
              onTap: () => Navigator.pop(context)),
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
class UserDetailsAdminScreen extends StatelessWidget {
  const UserDetailsAdminScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! UserModel) {
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
    final u = args;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('User Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {})
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TCard(
            child: Column(children: [
              TAvatar(initials: u.initials, radius: 40),
              const SizedBox(height: 12),
              Text(u.name,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text(u.role,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TChip(
                      label: 'Active',
                      bg: AppColors.success.withOpacity(0.1),
                      textColor: AppColors.success),
                  const SizedBox(width: 8),
                  Row(children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('${u.rating}',
                        style: const TextStyle(fontWeight: FontWeight.bold))
                  ]),
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
                u.email.isNotEmpty ? u.email : 'Unknown'),
            const Divider(height: 1, color: AppColors.border),
            _infoRow(Icons.calendar_today_outlined, 'Joined Date', 'Unknown'),
            const Divider(height: 1, color: AppColors.border),
            _infoRow(Icons.history, 'Last Activity', '2 hours ago'),
          ])),
          const SizedBox(height: 16),
          const TSectionHeader(title: 'Statistics'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _statCard('Projects', '${u.projectsCount}',
                    Icons.folder_outlined, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: _statCard('Tasks Done', '0', Icons.check_circle_outline,
                    AppColors.success)),
          ]),
          const SizedBox(height: 24),
          const TSectionHeader(title: 'Admin Actions'),
          const SizedBox(height: 12),
          TCard(
              padding: EdgeInsets.zero,
              child: Column(children: [
                _actionTile(Icons.person_outline, 'View User Profile', () {}),
                _actionTile(Icons.swap_horiz, 'Change User Role', () {}),
                _actionTile(Icons.block, 'Suspend User', () {},
                    isDestructive: true),
                _actionTile(Icons.lock_reset, 'Reset Password', () {}),
                _actionTile(Icons.delete_outline, 'Delete User',
                    () => _confirmDelete(context),
                    isDestructive: true),
              ])),
          const SizedBox(height: 32),
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

  Widget _statCard(String label, String val, IconData icon, Color color) =>
      TCard(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(val,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
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

  void _confirmDelete(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Delete User?'),
              content: const Text(
                  'This action is permanent and cannot be undone. All user data will be lost.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text('Delete',
                        style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold))),
              ],
            ));
  }
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
                          color: (_role!['color'] as Color).withOpacity(0.1),
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
