import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../core/network/api_result.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme_controller.dart';
import '../../services/app_services.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../../data/models/api_user.dart';
import '../../data/models/api_helpers.dart';

// ── Profile stats parsing (GET /api/users/<id>/stats) ─────────────────────────
class ProfileDisplayStats {
  final String projects;
  final String tasksDone;
  final String score;
  final String location;
  final String joined;
  final String roleTitle;
  final num commitment;
  final num teamwork;
  final num quality;

  const ProfileDisplayStats({
    required this.projects,
    required this.tasksDone,
    required this.score,
    required this.location,
    required this.joined,
    required this.roleTitle,
    required this.commitment,
    required this.teamwork,
    required this.quality,
  });
}

int _profileInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.round();
  return int.tryParse(v.toString()) ?? 0;
}

String _profileFormatScore(dynamic v) {
  if (v == null) return '0';
  final n = v is num ? v.toDouble() : double.tryParse(v.toString());
  if (n == null) return '0';
  if (n == n.roundToDouble()) return '${n.round()}';
  return n.toStringAsFixed(1);
}

String _profileDefaultRole(ApiUser user, String fallback) {
  if (user.professionalField.isNotEmpty) return user.professionalField;
  if (user.experienceLevel.isNotEmpty) {
    return '${user.experienceLevel} ${user.displayRole}';
  }
  return fallback;
}

String _profileDefaultJoined(ApiUser user) {
  if (user.joinedAt.isEmpty) return 'Member';
  final dt = DateTime.tryParse(user.joinedAt);
  if (dt == null) return 'Member';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return 'Member since ${months[dt.month - 1]} ${dt.year}';
}

ProfileDisplayStats profileDisplayStats(
  ApiUser user,
  Map<String, dynamic> raw, {
  required String defaultRole,
  required String defaultLocation,
}) {
  final summary = raw['summary'] as Map<String, dynamic>? ?? {};
  final tasks = raw['tasks'] as Map<String, dynamic>? ?? {};
  final ratings = raw['ratings'] as Map<String, dynamic>? ?? {};
  final projects = raw['projects'] as Map<String, dynamic>? ?? {};
  final performance = raw['performance'] as Map<String, dynamic>? ?? {};

  final projectsCount = _profileInt(
    summary['projects'] ??
        summary['completed_projects'] ??
        projects['accessible_count'],
  );
  final tasksDone = _profileInt(
    summary['tasks_done'] ?? summary['completed_tasks'] ?? tasks['completed'],
  );

  dynamic scoreVal =
      summary['score'] ?? summary['rating'] ?? ratings['average'];
  if (scoreVal == null && performance['quality_score'] != null) {
    scoreVal = (performance['quality_score'] as num) * 5;
  }

  final location = summary['location']?.toString().trim().isNotEmpty == true
      ? summary['location'].toString()
      : (user.availability.isNotEmpty ? user.availability : defaultLocation);

  final joined = summary['joined']?.toString().trim().isNotEmpty == true
      ? summary['joined'].toString()
      : _profileDefaultJoined(user);

  final roleTitle = summary['role_title']?.toString().trim().isNotEmpty == true
      ? summary['role_title'].toString()
      : _profileDefaultRole(user, defaultRole);

  final onTime = performance['on_time_rate'];
  final commitment = _profileInt(
    summary['commitment'] ?? (onTime is num ? onTime * 100 : null),
  );
  final teamwork = _profileInt(summary['teamwork']);
  final quality = _profileInt(
    summary['quality'] ??
        ((performance['quality_score'] as num?) != null
            ? (performance['quality_score'] as num) * 100
            : null),
  );

  return ProfileDisplayStats(
    projects: '$projectsCount',
    tasksDone: '$tasksDone',
    score: _profileFormatScore(scoreVal),
    location: location,
    joined: joined,
    roleTitle: roleTitle,
    commitment: commitment,
    teamwork: teamwork > 0 ? teamwork : commitment,
    quality: quality > 0 ? quality : commitment,
  );
}

// ── Profile Base Widget ───────────────────────────────────────────────────────
class _ProfileBase extends StatelessWidget {
  final String name, role, initials, email, location, joined;
  final String projects, tasksDone, score;
  final bool isAdmin;
  const _ProfileBase({
    required this.name,
    required this.role,
    required this.initials,
    required this.email,
    required this.location,
    required this.joined,
    required this.projects,
    required this.tasksDone,
    required this.score,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Profile',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const Text('Manage your account',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            TCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    TAvatar(initials: initials, radius: 28),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  fontSize: 16)),
                          Text(role,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary)),
                        ])),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, R.editProfile),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('Edit Profile',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500))),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  _infoRow(Icons.email_outlined, email),
                  const SizedBox(height: 6),
                  _infoRow(Icons.location_on_outlined, location),
                  const SizedBox(height: 6),
                  _infoRow(Icons.calendar_today_outlined, joined),
                ])),
            const SizedBox(height: 12),
            Row(children: [
              _statBox(projects, 'Projects'),
              const SizedBox(width: 10),
              _statBox(tasksDone, 'Tasks Done'),
              const SizedBox(width: 10),
              _statBox(score, 'Score'),
            ]),
            const SizedBox(height: 16),
            const Text('Account',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            _menuTile(context, Icons.settings_outlined, 'Settings',
                onTap: () => Navigator.pushNamed(context, R.settings)),
            const SizedBox(height: 8),
            _menuTile(
                context, Icons.auto_fix_high_outlined, 'AI Resume Builder',
                onTap: () => Navigator.pushNamed(context, R.resumeBuilder)),
            const SizedBox(height: 8),
            _menuTile(context, Icons.folder_copy_outlined, 'My Projects',
                onTap: () => Navigator.pushNamed(context, R.projectsList)),
            const SizedBox(height: 8),
            _menuTile(context, Icons.logout, 'Log Out', onTap: () async {
              await context.read<AppServices>().auth.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, R.roleSelection, (_) => false);
              }
            }, color: Colors.red),
            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar:
          TBottomNav(current: 4, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(text,
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]);

  Widget _statBox(String value, String label) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ));

  Widget _menuTile(BuildContext ctx, IconData icon, String title,
      {required VoidCallback onTap, Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icon, size: 20, color: color ?? AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: color ?? AppColors.textPrimary))),
          Icon(Icons.arrow_forward_ios,
              size: 14, color: color ?? AppColors.textSecondary),
        ]),
      ),
    );
  }
}

// ── Profile stats loader (fresh from API + Hive cache) ────────────────────────
class _ProfileStatsLoader extends StatefulWidget {
  final ApiUser user;
  final String defaultRole;
  final String defaultLocation;
  final bool isAdmin;
  final Widget Function(
    BuildContext context,
    ProfileDisplayStats stats,
    VoidCallback refresh,
    bool refreshing,
  ) builder;

  const _ProfileStatsLoader({
    required this.user,
    required this.defaultRole,
    required this.defaultLocation,
    required this.builder,
    this.isAdmin = false,
  });

  @override
  State<_ProfileStatsLoader> createState() => _ProfileStatsLoaderState();
}

class _ProfileStatsLoaderState extends State<_ProfileStatsLoader> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load(forceRefresh: true));
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      if (_stats == null) {
        _loading = true;
      } else {
        _refreshing = true;
      }
      _error = null;
    });

    final users = context.read<AppServices>().users;
    final result = await users.getUserStats(
      widget.user.id,
      forceRefresh: forceRefresh,
    );

    if (!mounted) return;
    result.when(
      success: (data) {
        setState(() {
          _stats = data;
          _loading = false;
          _refreshing = false;
          _error = null;
        });
      },
      failure: (e) {
        setState(() {
          _loading = false;
          _refreshing = false;
          _error = e;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _stats == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => _load(forceRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final raw = _stats ?? {};
    final display = profileDisplayStats(
      widget.user,
      raw,
      defaultRole: widget.defaultRole,
      defaultLocation: widget.defaultLocation,
    );
    return widget.builder(
      context,
      display,
      () => _load(forceRefresh: true),
      _refreshing,
    );
  }
}

// ── Freelancer Profile ────────────────────────────────────────────────────────
class FreelancerProfileScreen extends StatelessWidget {
  const FreelancerProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.currentUser;
    final name = user?.fullName ?? user?.displayName ?? 'Freelancer';
    final initials = name.length >= 2
        ? '${name.split(' ').first[0]}${name.split(' ').length > 1 ? name.split(' ')[1][0] : name[1]}'
        : name[0];

    if (user == null) return const SizedBox.shrink();

    return _ProfileStatsLoader(
      user: user,
      defaultRole: 'Freelance Developer',
      defaultLocation: 'Remote',
      builder: (context, d, refresh, refreshing) {
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: _ProfileBase(
            name: name,
            role: d.roleTitle,
            initials: initials.toUpperCase(),
            email: user.email,
            location: d.location,
            joined: d.joined,
            projects: d.projects,
            tasksDone: d.tasksDone,
            score: d.score,
          ),
        );
      },
    );
  }
}

// ── Student Profile ───────────────────────────────────────────────────────────
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.currentUser;
    final name = user?.fullName ?? user?.displayName ?? 'Student';
    final initials = name.length >= 2
        ? '${name.split(' ').first[0]}${name.split(' ').length > 1 ? name.split(' ')[1][0] : name[1]}'
        : name[0];

    if (user == null) return const SizedBox.shrink();

    return _ProfileStatsLoader(
      user: user,
      defaultRole: 'Student Developer',
      defaultLocation: 'University',
      builder: (context, d, refresh, _) {
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: _ProfileBase(
            name: name,
            role: d.roleTitle,
            initials: initials.toUpperCase(),
            email: user.email,
            location: d.location,
            joined: d.joined,
            projects: d.projects,
            tasksDone: d.tasksDone,
            score: d.score,
          ),
        );
      },
    );
  }
}

// ── Admin Profile ─────────────────────────────────────────────────────────────
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final user = session.currentUser;
    final name = user?.fullName ?? user?.displayName ?? 'Admin';
    final initials = name.length >= 2
        ? '${name.split(' ').first[0]}${name.split(' ').length > 1 ? name.split(' ')[1][0] : name[1]}'
        : name[0];

    if (user == null) return const SizedBox.shrink();

    return _ProfileStatsLoader(
      user: user,
      defaultRole: 'System Administrator',
      defaultLocation: 'Remote',
      isAdmin: true,
      builder: (context, d, refresh, _) {
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: _ProfileBase(
            name: name,
            role: d.roleTitle,
            initials: initials.toUpperCase(),
            email: user.email,
            location: d.location,
            joined: d.joined,
            projects: d.projects,
            tasksDone: d.tasksDone,
            score: d.score,
            isAdmin: true,
          ),
        );
      },
    );
  }
}

// ── Edit Profile ──────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _email;
  final _phone = TextEditingController();
  final _bio = TextEditingController();

  String? _avatarFileId;
  Uint8List? _avatarBytes;
  bool _loadingProfile = true;
  bool _saving = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<SessionController>().currentUser;
    _name = TextEditingController(text: user?.fullName ?? '');
    _username = TextEditingController(text: user?.displayName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    // Phone/bio/avatar come from the server for this user only (not session cache).
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final session = context.read<SessionController>();
    final svc = context.read<AppServices>().users;
    final sessionUserId = session.currentUser?.id;

    final res = await svc.getProfile(
      userId: sessionUserId,
      forceRefresh: true,
    );
    if (!mounted) return;
    res.when(
      success: (user) {
        if (user == null) {
          setState(() => _loadingProfile = false);
          return;
        }
        // Ignore stale cache if it belongs to another account.
        if (sessionUserId != null &&
            user.id.isNotEmpty &&
            user.id != sessionUserId) {
          setState(() => _loadingProfile = false);
          return;
        }
        _name.text = user.fullName;
        _username.text = user.displayName;
        _email.text = user.email;
        _phone.text = user.phone;
        _bio.text = user.bio;
        _avatarFileId =
            user.avatarFileId.isNotEmpty ? user.avatarFileId : null;
        _avatarBytes = null;
        setState(() => _loadingProfile = false);
        _loadAvatarBytes(_avatarFileId);
      },
      failure: (_) => setState(() => _loadingProfile = false),
    );
  }

  Future<void> _loadAvatarBytes(String? fileId) async {
    if (fileId == null || fileId.isEmpty) return;
    final res =
        await context.read<AppServices>().files.downloadFile(fileId);
    if (!mounted) return;
    res.when(
      success: (bytes) {
        if (bytes.isEmpty) return;
        setState(() => _avatarBytes = Uint8List.fromList(bytes));
      },
      failure: (_) {},
    );
  }

  Future<void> _pickAvatar() async {
    final fileService = context.read<AppServices>().files;
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path;
    final bytes = picked.bytes;
    if (path == null && bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Cannot access image data.')),
      );
      return;
    }

    setState(() {
      _uploadingAvatar = true;
      if (bytes != null) _avatarBytes = bytes;
    });
    final uploadRes = await fileService.uploadFile(
      filePath: path ?? '',
      filename: picked.name,
      fileBytes: bytes,
    );
    if (!mounted) return;

    uploadRes.when(
      success: (file) {
        if (!mounted) return;
        setState(() {
          _avatarFileId = file.id;
          _uploadingAvatar = false;
        });
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Photo selected — tap Save Changes to keep it'),
            backgroundColor: AppColors.success,
          ),
        );
      },
      failure: (msg) {
        if (!mounted) return;
        setState(() => _uploadingAvatar = false);
        messenger.showSnackBar(
          SnackBar(content: Text(msg)),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final username = _username.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username is required')),
      );
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]{3,30}$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Username must be 3–30 characters: letters, numbers, underscores only',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final svc = context.read<AppServices>().users;
    final session = context.read<SessionController>();

    final payload = <String, dynamic>{
      'full_name': _name.text.trim(),
      'display_name': username,
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'bio': _bio.text.trim(),
    };
    if (_avatarFileId != null) {
      payload['avatar_file_id'] = int.tryParse(_avatarFileId!) ?? _avatarFileId;
    }

    final res = await svc.updateProfile(payload);
    if (!mounted) return;

    setState(() => _saving = false);

    res.when(
      success: (user) {
        if (user != null) session.setCurrentUser(user);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile saved'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      },
      failure: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      },
    );
  }

  ImageProvider? get _avatarImage {
    if (_avatarBytes == null || _avatarBytes!.isEmpty) return null;
    return MemoryImage(_avatarBytes!);
  }

  @override
  Widget build(BuildContext context) {
    final initials =
        _name.text.isNotEmpty ? _name.text[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Stack(
                    children: [
                      TAvatar(
                        initials: initials,
                        radius: 40,
                        backgroundImage: _avatarImage,
                      ),
                      if (_uploadingAvatar)
                        const Positioned.fill(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.black38,
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _uploadingAvatar ? null : _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                          controller: _name,
                          decoration: _inputDec('Your full name')),
                      const SizedBox(height: 12),
                      const Text('Username',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      const Text(
                        'Unique handle — letters, numbers, and underscores only',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _username,
                          decoration: _inputDec('e.g. mohamed_dev'),
                          autocorrect: false,
                          enableSuggestions: false),
                      const SizedBox(height: 12),
                      const Text('Email',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _email,
                          decoration: _inputDec('Your email'),
                          keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 12),
                      const Text('Phone',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _phone,
                          decoration: _inputDec('Your phone'),
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      const Text('Bio',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _bio,
                          maxLines: 3,
                          decoration: _inputDec('About you')),
                    ])),
                const SizedBox(height: 16),
                TButton(
                  label: _saving ? 'Saving…' : 'Save Changes',
                  onTap: _saving ? null : _save,
                ),
                const SizedBox(height: 8),
                TButton(
                    label: 'Cancel',
                    outline: true,
                    onTap: () => Navigator.pop(context)),
              ],
            ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary)),
      );
}

// ── Completed Projects ────────────────────────────────────────────────────────
class CompletedProjectsScreen extends StatelessWidget {
  const CompletedProjectsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Completed Projects',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: RepositoryLoader<List<ProjectModel>>(
        load: () async {
          final list = await context
              .read<AppServices>()
              .projects
              .listCompletedProjects()
              .unwrap();
          return list.map((project) => project.toDisplayModel()).toList();
        },
        isEmpty: (projects) => projects.isEmpty,
        emptyMessage: 'No completed projects found',
        builder: (context, projects) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (_, i) {
            final p = projects[i];
            return TCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.folder_outlined,
                          color: AppColors.primary, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text(p.company,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ])),
                  TChip(
                      label: '${p.progress}%',
                      bg: AppColors.success.withValues(alpha: 0.1),
                      textColor: AppColors.success),
                ]));
          },
        ),
      ),
    );
  }
}

// ── Ratings ───────────────────────────────────────────────────────────────────
class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  Future<_RatingViewModel>? _future;

  Future<_RatingViewModel> _fetch() async {
    final userId = context.read<SessionController>().currentUser?.id ?? '';
    final services = context.read<AppServices>();
    if (userId.isEmpty) {
      return const _RatingViewModel(avg: 0, reviews: []);
    }
    final avg = await services.ratings.getUserAverageRating(userId).unwrap();
    final reviews = await services.ratings.getUserRatings(userId).unwrap();
    return _RatingViewModel(avg: avg, reviews: reviews);
  }

  void _reload() {
    setState(() {
      _future = _fetch();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Ratings & Reviews',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: _future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<_RatingViewModel>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(snap.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                          TextButton(
                            onPressed: _reload,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final vm = snap.data!;
                final avgStr = vm.avg > 0 ? vm.avg.toStringAsFixed(1) : '—';
                final fullStars = vm.avg.round().clamp(0, 5);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TCard(
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Column(children: [
                            Text(avgStr,
                                style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary)),
                            Row(
                                children: List.generate(
                                    5,
                                    (i) => Icon(
                                        i < fullStars
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                        size: 20))),
                            Text(
                                vm.reviews.isEmpty
                                    ? 'No reviews yet'
                                    : 'Based on ${vm.reviews.length} review${vm.reviews.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ]),
                        ])),
                    const SizedBox(height: 12),
                    if (vm.reviews.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'When teammates rate you on completed projects, scores appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...vm.reviews.map((r) {
                        final score = (r['score'] as num?)?.toInt() ?? 0;
                        final comment = r['comment']?.toString() ?? '';
                        final created = r['created_at']?.toString() ?? '';
                        return TCard(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const TAvatar(initials: 'R', radius: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        const Text('Teammate',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                                fontSize: 13)),
                                        Row(
                                            children: List.generate(
                                                score.clamp(0, 5),
                                                (_) => const Icon(Icons.star,
                                                    size: 12,
                                                    color: Colors.amber))),
                                      ])),
                                  Text(
                                      created.contains('T')
                                          ? created.split('T').first
                                          : created,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ]),
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(comment,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ]),
                        );
                      }),
                  ],
                );
              },
            ),
    );
  }
}

class _RatingViewModel {
  final double avg;
  final List<Map<String, dynamic>> reviews;

  const _RatingViewModel({required this.avg, required this.reviews});
}

// ── Performance (Courses / Performance / Feedback tabs) ───────────────────────
class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});
  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20)),
          dividerColor: Colors.transparent,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Courses'),
            Tab(text: 'Performance'),
            Tab(text: 'Feedback')
          ],
        ),
      ),
      body: TabBarView(
          controller: _tab,
          children: const [_CoursesTab(), _PerfTab(), _FeedbackTab()]),
      bottomNavigationBar:
          TBottomNav(current: 4, onTap: (i) => handleFreelancerNav(context, i)),
    );
  }
}

class _CoursesTab extends StatelessWidget {
  const _CoursesTab();
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Courses',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const Text('AI-recommended for you',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 12),
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.star_outline,
                    color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            const Expanded(
                child: Text(
                    'These courses are personalized based on your career goals and current skill level',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary))),
          ])),
      const SizedBox(height: 20),
      const Text('Continue Learning',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      TCard(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('System Design Fundamentals',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 15))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: const Text('Advanced',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.purple,
                      fontWeight: FontWeight.w600))),
        ]),
        const Text('Tech Academy · 24 lessons',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        const TBar(value: 0.42, color: AppColors.primary, height: 6),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Lesson 10 of 24',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          GestureDetector(
              onTap: () {},
              child: const Text('Continue →',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600))),
        ]),
      ])),
      const SizedBox(height: 16),
      const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Recommended for You',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
      ]),
      const SizedBox(height: 10),
      ...[
        {
          'title': 'Advanced React Patterns',
          'level': 'Intermediate',
          'platform': 'Frontend Masters',
          'duration': '8 hours',
          'rating': '4.8',
          'reviews': '1,243',
          'levelColor': AppColors.accent
        },
        {
          'title': 'Database Optimization',
          'level': 'Advanced',
          'platform': 'SQL Academy',
          'duration': '12 hours',
          'rating': '4.9',
          'reviews': '856',
          'levelColor': Colors.purple
        },
        {
          'title': 'API Design Best Practices',
          'level': 'Intermediate',
          'platform': 'Web Development Pro',
          'duration': '6 hours',
          'rating': '4.7',
          'reviews': '2,104',
          'levelColor': AppColors.accent
        },
      ].map((c) => TCard(
          margin: const EdgeInsets.only(bottom: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(c['title'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary))),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: (c['levelColor'] as Color).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(c['level'] as String,
                      style: TextStyle(
                          fontSize: 11,
                          color: c['levelColor'] as Color,
                          fontWeight: FontWeight.w600))),
            ]),
            Text('${c['platform']} · ${c['duration']}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text('${c['rating']} (${c['reviews']})',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              GestureDetector(
                  onTap: () {},
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Enroll',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)))),
            ]),
          ]))),
    ]);
  }
}

class _PerfTab extends StatefulWidget {
  const _PerfTab();
  @override
  State<_PerfTab> createState() => _PerfTabState();
}

class _PerfTabState extends State<_PerfTab> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _load(forceRefresh: true));
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final user = context.read<SessionController>().currentUser;
    if (user == null) return;
    setState(() => _loading = _stats == null);
    final result = await context.read<AppServices>().users.getUserStats(
          user.id,
          forceRefresh: forceRefresh,
        );
    if (!mounted) return;
    result.when(
      success: (data) => setState(() {
        _stats = data;
        _loading = false;
      }),
      failure: (_) => setState(() => _loading = false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().currentUser;
    if (user == null) return const SizedBox.shrink();
    if (_loading && _stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final d = profileDisplayStats(
      user,
      _stats ?? {},
      defaultRole: user.displayRole,
      defaultLocation: 'Remote',
    );
    final score = d.score;
    final commitment = d.commitment;
    final teamwork = d.teamwork;
    final quality = d.quality;

    return ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Performance',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const Text('AI-generated rating',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      const SizedBox(height: 16),
      TCard(
          child: Column(children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
              gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF2D5FA6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(score,
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const Text('Overall Score',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ),
        const SizedBox(height: 12),
        const Text('Performance overview',
            style: TextStyle(
                fontSize: 13,
                color: AppColors.success,
                fontWeight: FontWeight.w600)),
      ])),
      const SizedBox(height: 16),
      const Text('Performance Metrics',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      ...[
        {
          'icon': Icons.remove_red_eye_outlined,
          'label': 'Commitment',
          'value': commitment,
          'color': AppColors.success
        },
        {
          'icon': Icons.people_outline,
          'label': 'Teamwork',
          'value': teamwork,
          'color': AppColors.primary
        },
        {
          'icon': Icons.chat_bubble_outline,
          'label': 'Quality',
          'value': quality,
          'color': AppColors.primaryDark
        },
      ].map((m) => TCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Icon(m['icon'] as IconData, color: m['color'] as Color, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m['label'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary)),
                        Text('${m['value']}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                      ]),
                  const SizedBox(height: 6),
                  TBar(
                      value: ((m['value'] as num).toDouble()) / 100,
                      color: m['color'] as Color,
                      height: 6),
                ])),
          ]))),
      const SizedBox(height: 8),
      const Text('6-Month Trend',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
      const SizedBox(height: 10),
      TCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            const SizedBox(height: 60),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
                    .map((m) => Text(m,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)))
                    .toList()),
          ])),
    ]);
  }
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();
  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  int _stars = 0;
  final _ctrl = TextEditingController();
  bool _aiAssisting = false;
  bool _submitting = false;
  int _listVersion = 0;
  String _aiSuggestion =
      'Consider mentioning specific achievements or areas for improvement to make your feedback more actionable.';

  Future<void> _runAiAssist() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select a star rating first, then use AI assist.')));
      return;
    }
    setState(() => _aiAssisting = true);
    try {
      final result =
          await context.read<AppServices>().ai.generateFeedbackAssist(
                rating: _stars,
              );
      if (!mounted) return;
      result.when(
        success: (data) {
          final draft = data['draft'] ?? '';
          final tip = data['suggestion'] ?? '';
          setState(() {
            if (draft.isNotEmpty) _ctrl.text = draft;
            if (tip.isNotEmpty) _aiSuggestion = tip;
          });
        },
        failure: (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e), backgroundColor: AppColors.error),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _aiAssisting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return RepositoryLoader<List<Map<String, dynamic>>>(
      key: ValueKey(_listVersion),
      load: () => context
          .read<AppServices>()
          .feedback
          .getUserFeedback(user.id, forceRefresh: _listVersion > 0)
          .unwrap(),
      builder: (context, feedbackList) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Feedback',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const Text('Share your thoughts',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          TCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Rate Your Experience',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                Row(
                    children: List.generate(
                        5,
                        (i) => GestureDetector(
                              onTap: () => setState(() => _stars = i + 1),
                              child: Icon(
                                  i < _stars ? Icons.star : Icons.star_border,
                                  color: Colors.amber,
                                  size: 32),
                            ))),
                const SizedBox(height: 12),
                const Text('Your Feedback',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F5FA),
                      borderRadius: BorderRadius.circular(10)),
                  child: Stack(children: [
                    TextField(
                        controller: _ctrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                            hintText: 'Share your thoughts...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(12))),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: TextButton.icon(
                        onPressed: _aiAssisting ? null : _runAiAssist,
                        icon: _aiAssisting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome,
                                size: 14, color: AppColors.primary),
                        label: Text(
                          _aiAssisting ? '…' : 'AI assist',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                TButton(
                    label: _submitting ? 'Submitting…' : '✈ Submit Feedback',
                    onTap: _submitting
                        ? null
                        : () async {
                            if (_stars == 0) return;
                            final feedback =
                                context.read<AppServices>().feedback;
                            final messenger =
                                ScaffoldMessenger.of(context);
                            setState(() => _submitting = true);
                            try {
                              await feedback
                                  .submitFeedback(
                                    targetUserId: user.id,
                                    projectId: '1',
                                    rating: _stars,
                                    comment: _ctrl.text.trim(),
                                  )
                                  .unwrap();
                              if (!mounted) return;
                              setState(() {
                                _stars = 0;
                                _ctrl.clear();
                                _listVersion++;
                              });
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text('$e')),
                              );
                            } finally {
                              if (mounted) setState(() => _submitting = false);
                            }
                          }),
              ])),
          const SizedBox(height: 12),
          Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('AI Suggestion',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 13)),
                      Text(
                          _aiSuggestion,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ])),
              ])),
          const SizedBox(height: 16),
          const Text('Recent Feedback',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          if (feedbackList.isEmpty)
            const Text('No feedback yet.',
                style: TextStyle(color: AppColors.textSecondary))
          else
            ...feedbackList.map((f) => TCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                            f['reviewer_name']?.toString() ??
                                f['author_name']?.toString() ??
                                'Teammate',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const Spacer(),
                        Row(
                            children: List.generate(
                                5,
                                (i) => Icon(
                                    i < ((f['avg_rating'] as num?)?.toInt() ??
                                        (f['rating'] as num?)?.toInt() ??
                                        0)
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 14,
                                    color: Colors.amber))),
                      ]),
                      const SizedBox(height: 4),
                      Text(
                          f['feedback_text']?.toString() ??
                              f['content']?.toString() ??
                              '',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                          f['created_at'] != null &&
                                  f['created_at'].toString().isNotEmpty
                              ? formatRelativeTime(f['created_at'].toString())
                              : 'Recently',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textHint)),
                    ]))),
        ]);
      },
    );
  }
}

// ── Language Switch ───────────────────────────────────────────────────────────
class LanguageSwitchScreen extends StatefulWidget {
  const LanguageSwitchScreen({super.key});
  @override
  State<LanguageSwitchScreen> createState() => _LanguageSwitchScreenState();
}

class _LanguageSwitchScreenState extends State<LanguageSwitchScreen> {
  String _selected = 'English';
  final List<Map<String, dynamic>> _langs = [
    {'name': 'English', 'flag': '🇺🇸', 'native': 'English'},
    {'name': 'Arabic', 'flag': '🇪🇬', 'native': 'العربية'},
    {'name': 'French', 'flag': '🇫🇷', 'native': 'Français'},
    {'name': 'Spanish', 'flag': '🇪🇸', 'native': 'Español'},
    {'name': 'German', 'flag': '🇩🇪', 'native': 'Deutsch'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Language Settings',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: Column(children: [
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _langs.length,
          itemBuilder: (_, i) {
            final l = _langs[i];
            final sel = _selected == l['name'];
            return GestureDetector(
              onTap: () => setState(() => _selected = l['name'] as String),
              child: TCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Text(l['flag'] as String,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(l['name'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          Text(l['native'] as String,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ])),
                    if (sel)
                      const Icon(Icons.check_circle,
                          color: AppColors.primary, size: 22),
                  ])),
            );
          },
        )),
        Padding(
            padding: const EdgeInsets.all(16),
            child: TButton(
                label: 'Apply Language', onTap: () => Navigator.pop(context))),
      ]),
    );
  }
}

// ── Settings Screen ───────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin =
        context.watch<SessionController>().currentUser?.isAdmin == true;
    final darkMode = context.watch<ThemeController>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TSectionHeader(title: 'Preferences'),
          const SizedBox(height: 12),
          TCard(
              child: Column(children: [
            _tile(context, Icons.language_outlined, 'Language', 'English',
                onTap: () => Navigator.pushNamed(context, R.languageSwitch)),
            Divider(height: 1, color: theme.dividerColor),
            ListTile(
              onTap: () => darkMode.toggle(),
              leading: Icon(Icons.dark_mode_outlined,
                  color: theme.colorScheme.onSurface, size: 22),
              title: Text('Dark Mode',
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    darkMode.isDark ? 'On' : 'Off',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: darkMode.isDark,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => darkMode.setDarkMode(v),
                  ),
                ],
              ),
            ),
          ])),
          const SizedBox(height: 24),
          const TSectionHeader(title: 'Security & Privacy'),
          const SizedBox(height: 12),
          TCard(
              child: Column(children: [
            _tile(context, Icons.lock_outline, 'Privacy Policy', '',
                onTap: () => Navigator.pushNamed(context, R.privacyPolicy)),
            if (isAdmin) ...[
              Divider(height: 1, color: theme.dividerColor),
              _tile(context, Icons.security_outlined, 'Security Center', '',
                  onTap: () => Navigator.pushNamed(context, R.securityCenter)),
            ],
          ])),
          const SizedBox(height: 24),
          const TSectionHeader(title: 'Account'),
          const SizedBox(height: 12),
          TCard(
            onTap: () => _showLogoutDialog(context),
            child: const Row(
              children: [
                Icon(Icons.logout, color: AppColors.error, size: 22),
                SizedBox(width: 12),
                Text('Log out',
                    style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                Spacer(),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppColors.textHint),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Center(
              child: Text('Teamify v2.0.4 Build 102',
                  style: TextStyle(color: AppColors.textHint, fontSize: 11))),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<SessionController>().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, R.login, (route) => false);
            },
            child: const Text('Log out',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String value,
      {required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: AppColors.textPrimary, size: 22),
      title: Text(title,
          style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: AppColors.textPrimary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value.isNotEmpty)
            Text(value,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios,
              size: 14, color: AppColors.textHint),
        ],
      ),
    );
  }
}

// ── Privacy Policy ────────────────────────────────────────────────────────────
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <({String title, String body})>[
    (
      title: '1. Information We Collect',
      body:
          'Teamify collects information you provide when you register (name, email, role), '
          'project and task data you create in the app, messages sent in team chat, '
          'files you upload, and usage data such as login times and device type for security.',
    ),
    (
      title: '2. How We Use Your Data',
      body:
          'We use your data to operate the platform (projects, tasks, chat, meetings), '
          'personalize AI features (mentor insights, task suggestions, CV builder), '
          'send notifications, and protect accounts through security monitoring.',
    ),
    (
      title: '3. AI and Automated Processing',
      body:
          'Some features use machine learning on the server (task classification, delay '
          'prediction, mentor recommendations, chat summarization). AI outputs are '
          'suggestions only and do not replace human decisions on hiring or evaluation.',
    ),
    (
      title: '4. Data Sharing',
      body:
          'Your profile and project content are visible to teammates and admins as '
          'configured by your organization. We do not sell personal data. Third-party '
          'services (e.g. speech-to-text) may process data only when you use those features.',
    ),
    (
      title: '5. Security',
      body:
          'We use authentication tokens, encrypted connections (HTTPS), and access controls '
          'by role. You are responsible for keeping your password confidential and reporting '
          'suspicious activity via Security Center.',
    ),
    (
      title: '6. Your Rights',
      body:
          'You may update your profile, request export of your data, or ask for account '
          'deletion through your administrator. Contact support if you need help exercising '
          'these rights.',
    ),
    (
      title: '7. Contact',
      body:
          'For privacy questions, contact your Teamify administrator or the support channel '
          'provided by your organization. Last updated: May 2026.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Privacy Policy',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AIBanner(
            title: 'Your privacy matters',
            subtitle:
                'How Teamify collects, uses, and protects your information',
          ),
          const SizedBox(height: 16),
          ..._sections.map((s) => TCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            fontSize: 15)),
                    const SizedBox(height: 8),
                    Text(s.body,
                        style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textSecondary)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
