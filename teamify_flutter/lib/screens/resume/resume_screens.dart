import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/files/file_downloader.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../core/session/session_controller.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';
import '../../core/network/api_result.dart';
import 'resume_cv_utils.dart';

// ── CV Start ──────────────────────────────────────────────────────────────────
class ResumeCVStartScreen extends StatelessWidget {
  const ResumeCVStartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Create Resume',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
          child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                SizedBox(height: 12),
                Text('AI Resume Builder',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 6),
                Text('Generate a professional CV from your Teamify data',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
        ),
        const SizedBox(height: 24),
        ...<Map<String, dynamic>>[
          {
            'icon': Icons.auto_awesome,
            'title': 'AI-Powered Generation',
            'desc': 'Let AI build your resume from your profile data',
            'badge': 'Recommended',
            'route': R.resumeBuilder
          },
          {
            'icon': Icons.edit_outlined,
            'title': 'Edit Content',
            'desc': 'Fill in your details manually',
            'badge': null,
            'route': R.resumeEditContent
          },
          {
            'icon': Icons.visibility_outlined,
            'title': 'Preview',
            'desc': 'View and download your resume',
            'badge': null,
            'route': R.resumePreview
          },
        ].map((o) => GestureDetector(
              onTap: () => Navigator.pushNamed(context, o['route'] as String),
              child: TCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(o['icon'] as IconData,
                          color: AppColors.primary, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Text(o['title'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          if (o['badge'] != null) ...[
                            const SizedBox(width: 8),
                            TChip(
                                label: o['badge'] as String,
                                bg: AppColors.success.withValues(alpha: 0.1),
                                textColor: AppColors.success,
                                fontSize: 10)
                          ],
                        ]),
                        Text(o['desc'] as String,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ])),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: AppColors.textSecondary),
                ]),
              ),
            )),
      ]),
    );
  }
}

// ── Resume Builder ────────────────────────────────────────────────────────────
class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});
  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  String _style = 'Modern';
  bool _generating = false;
  String? _error;
  bool _loadingSources = true;
  String _profileStatus = 'Loading...';
  String _projectsStatus = '—';
  String _tasksStatus = '—';
  String _feedbackStatus = '—';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDataSources());
  }

  Future<void> _loadDataSources() async {
    final svc = context.read<AppServices>();
    try {
      final projects =
          await svc.projects.listProjects(forceRefresh: true).unwrap();
      var taskCount = 0;
      for (final p in projects) {
        final tasks = await svc.tasks
            .listTasks(projectId: p.id, forceRefresh: false)
            .unwrap();
        taskCount += tasks.length;
      }
      if (!mounted) return;
      setState(() {
        _loadingSources = false;
        _profileStatus = 'Complete';
        _projectsStatus =
            projects.isEmpty ? 'None yet' : '${projects.length} project(s)';
        _tasksStatus =
            taskCount == 0 ? 'None yet' : '$taskCount task(s) analyzed';
        _feedbackStatus = 'Included when available';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingSources = false;
        _profileStatus = 'Complete';
        _projectsStatus = 'Unavailable';
        _tasksStatus = 'Unavailable';
        _feedbackStatus = 'Unavailable';
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
          title: const Text('AI Resume Builder',
              style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Build with AI banner
        TCard(
            color: AppColors.primary.withValues(alpha: 0.05),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 22)),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Build your resume with AI',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text(
                        'Our AI analyzes your Teamify profile, projects, and achievements to create a professional resume tailored for you.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ])),
            ])),
        const SizedBox(height: 12),
        // Profile Summary
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Profile Summary',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Consumer<SessionController>(builder: (context, session, _) {
            final user = session.currentUser;
            final name = user?.displayName ?? user?.fullName ?? 'User';
            final role = user?.role ?? 'Member';
            return Row(children: [
              TAvatar(initials: name.isNotEmpty ? name[0].toUpperCase() : 'U', radius: 24),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    Text(role,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ])),
            ]);
          }),
        ])),
        const SizedBox(height: 12),
        // AI Data Sources
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('AI Data Sources',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 10),
          ...<Map<String, dynamic>>[
            {
              'icon': Icons.person_outline,
              'label': 'Profile Information',
              'status': _loadingSources ? 'Loading...' : _profileStatus,
            },
            {
              'icon': Icons.work_outline,
              'label': 'Projects & Work',
              'status': _loadingSources ? 'Loading...' : _projectsStatus,
            },
            {
              'icon': Icons.track_changes,
              'label': 'Tasks & Contributions',
              'status': _loadingSources ? 'Loading...' : _tasksStatus,
            },
            {
              'icon': Icons.trending_up,
              'label': 'Feedback & Reviews',
              'status': _loadingSources ? 'Loading...' : _feedbackStatus,
            },
          ].map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(s['icon'] as IconData, color: AppColors.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s['label'] as String,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary))),
                Text(s['status'] as String,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600)),
              ]))),
        ])),
        const SizedBox(height: 12),
        // Resume Style
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Resume Style',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Row(
              children: ['Modern', 'Classic', 'Creative'].map((s) {
            final sel = _style == s;
            final icons = {
              'Modern': Icons.auto_awesome,
              'Classic': Icons.description_outlined,
              'Creative': Icons.palette_outlined
            };
            return Expanded(
                child: GestureDetector(
              onTap: () => setState(() => _style = s),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                        width: sel ? 2 : 1)),
                child: Column(children: [
                  Icon(icons[s]!,
                      color: sel ? AppColors.primary : AppColors.textSecondary,
                      size: 24),
                  const SizedBox(height: 4),
                  Text(s,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              sel ? AppColors.primary : AppColors.textSecondary,
                          fontWeight:
                              sel ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
            ));
          }).toList()),
        ])),
        const SizedBox(height: 20),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ),
        TButton(
          label: _generating ? 'Generating...' : '✦ Generate Resume',
          onTap: _generating
              ? null
              : () async {
                  setState(() {
                    _generating = true;
                    _error = null;
                  });
                  final svc = context.read<AppServices>();
                  final result = await svc.ai.buildCVWithAI();
                  if (!context.mounted) return;
                  setState(() => _generating = false);
                  if (result.isSuccess && result.data != null) {
                    await svc.cvs.invalidateCVs();
                    if (!context.mounted) return;
                    final preview =
                        normalizeCvForPreview(result.data!);
                    final cvs = await svc.cvs.listCVs(forceRefresh: true).unwrap();
                    final cvId = cvs.isNotEmpty ? cvs.first.id : null;
                    if (!context.mounted) return;
                    Navigator.pushReplacementNamed(
                      context,
                      R.resumePreview,
                      arguments: {
                        'cv_id': cvId,
                        'cv_data': preview,
                      },
                    );
                  } else {
                    setState(() => _error =
                        result.error?.toString() ??
                            'Could not generate resume. Try again.');
                  }
                },
        ),
        const SizedBox(height: 10),
        TButton(
            label: 'View Saved Resumes',
            outline: true,
            onTap: () async {
              final nav = Navigator.of(context);
              await context.read<AppServices>().cvs.invalidateCVs();
              if (!context.mounted) return;
              nav.pushNamed(R.resumePreview);
            }),
      ]),
    );
  }
}

// ── Resume Preview ────────────────────────────────────────────────────────────
class ResumePreviewScreen extends StatefulWidget {
  const ResumePreviewScreen({super.key});

  @override
  State<ResumePreviewScreen> createState() => _ResumePreviewScreenState();
}

class _ResumePreviewScreenState extends State<ResumePreviewScreen> {
  Map<String, dynamic>? _cvData;
  String? _cvId;
  Map<String, dynamic> _design = defaultDesignPrefs();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCV());
  }

  Future<void> _loadCV() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args.containsKey('cv_data') && args['cv_data'] is Map
          ? Map<String, dynamic>.from(args['cv_data'] as Map)
          : Map<String, dynamic>.from(args);
      final preview = normalizeCvForPreview(raw);
      setState(() {
        _cvId = args['cv_id']?.toString() ?? preview['id']?.toString();
        _cvData = preview;
        _design = designPrefsFromCv(raw);
        _loading = false;
      });
      return;
    }

    final svc = context.read<AppServices>();
    try {
      final cvs = await svc.cvs.listCVs(forceRefresh: true).unwrap();
      if (!mounted) return;
      if (cvs.isNotEmpty) {
        final row = cvs.first.data;
        final preview = normalizeCvForPreview(row);
        setState(() {
          _cvId = cvs.first.id;
          _cvData = preview;
          _design = designPrefsFromCv(row);
          _loading = false;
        });
        return;
      }

      final built = await svc.ai.buildCVWithAI().unwrap();
      if (!mounted) return;
      await svc.cvs.invalidateCVs();
      final refreshed = await svc.cvs.listCVs(forceRefresh: true).unwrap();
      final preview = normalizeCvForPreview(built);
      setState(() {
        _cvId = refreshed.isNotEmpty ? refreshed.first.id : null;
        _cvData = preview;
        _design = designPrefsFromCv(built);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().contains('No CV')
            ? 'No resume yet. Open AI Resume Builder and tap Generate Resume.'
            : e.toString();
      });
    }
  }

  Future<String?> _ensureSavedCvId() async {
    if (_cvId != null && _cvId!.isNotEmpty) return _cvId;
    if (!mounted) return null;
    final user = context.read<SessionController>().currentUser;
    if (user == null || _cvData == null) return null;

    final form = editFormFromPreview(_cvData!);
    final payload = buildCvApiPayload(
      user: user,
      summary: form.summary,
      skills: form.skills,
      projects: form.projects,
      design: _design,
    );

    final svc = context.read<AppServices>();
    final created = await svc.cvs.createCV(payload);
    if (!mounted) return _cvId;
    if (!created.isSuccess || created.data == null) {
      throw Exception(created.error ?? 'Could not save resume');
    }
    _cvId = created.data!.id;
    return _cvId;
  }

  Future<void> _deleteCv() async {
    if (_cvId == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete resume?'),
        content: const Text(
          'This removes your saved CV from the database. You can generate a new one anytime.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    final cvs = context.read<AppServices>().cvs;
    final result = await cvs.deleteCV(_cvId!);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.isSuccess) {
      await cvs.invalidateCVs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume deleted')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Delete failed')),
      );
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
        title: const Text('Resume Preview',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_cvId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Delete resume',
              onPressed: _busy ? null : _deleteCv,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.error)))
              : _buildPreview(),
    );
  }

  Widget _buildPreview() {
    final data = _cvData ?? {};
    final userMap = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};
    final session = context.watch<SessionController>().currentUser;
    final name = userMap['name']?.toString().trim().isNotEmpty == true
        ? userMap['name'].toString()
        : (session?.displayName ?? session?.fullName ?? 'User');
    final role = userMap['role']?.toString().trim().isNotEmpty == true
        ? userMap['role'].toString()
        : (session?.role ?? 'Professional');
    final email = userMap['email']?.toString().trim().isNotEmpty == true
        ? userMap['email'].toString()
        : (session?.email ?? '');

    final sections = _design['sections'];
    final sectionVis = sections is Map
        ? sections.map((k, v) => MapEntry(k.toString(), v == true))
        : defaultSectionVisibility();
    final accent = accentColorFromDesign(_design);
    final styleName = _design['style']?.toString() ?? 'Modern';

    final summary = data['summary']?.toString() ?? 'No summary available.';
    final skills = data['skills'] is List
        ? (data['skills'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final experience =
        data['experience'] is List ? (data['experience'] as List) : [];
    final achievements = data['achievements'] is List
        ? (data['achievements'] as List)
        : [];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: styleName == 'Creative'
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (styleName == 'Creative')
                    Container(height: 6, color: accent),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                  crossAxisAlignment: styleName == 'Classic'
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Text(name,
                        textAlign: styleName == 'Classic'
                            ? TextAlign.start
                            : TextAlign.center,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: accent)),
                    Text(role,
                        textAlign: styleName == 'Classic'
                            ? TextAlign.start
                            : TextAlign.center,
                        style: TextStyle(color: accent.withValues(alpha: 0.75))),
                    Row(
                      mainAxisAlignment: styleName == 'Classic'
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                      Icon(Icons.email_outlined,
                          size: 12, color: accent.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      Text(email,
                          style: TextStyle(
                              fontSize: 11,
                              color: accent.withValues(alpha: 0.7))),
                    ]),
                    if (sectionVis['Summary'] != false) ...[
                      Divider(height: 20, color: accent.withValues(alpha: 0.35)),
                      _section('Professional Summary', accent),
                      Text(summary,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5)),
                    ],
                    if (sectionVis['Experience'] != false) ...[
                    Divider(height: 20, color: accent.withValues(alpha: 0.35)),
                    _section('Experience & Projects', accent),
                    if (experience.isEmpty)
                      const Text('No experience listed.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    else
                      ...experience.map((e) {
                        final title = e is Map
                            ? (e['title'] ?? e['role'] ?? '')
                            : e.toString();
                        final desc = e is Map ? (e['description'] ?? '') : '';
                        final roleLine = e is Map && (e['role']?.toString().isNotEmpty == true)
                            ? '${e['role']}\n'
                            : '';
                        return _project(
                          title.toString(),
                          '$roleLine${desc.toString()}'.trim(),
                        );
                      }),
                    ],
                    if (sectionVis['Skills'] != false) ...[
                    Divider(height: 20, color: accent.withValues(alpha: 0.35)),
                    _section('Skills', accent),
                    if (skills.isEmpty)
                      const Text('No skills listed.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    else
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: skills
                              .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.1),
                                      border: Border.all(
                                          color: accent.withValues(alpha: 0.5)),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(s,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: accent))))
                              .toList()),
                    ],
                    if (sectionVis['Achievements'] != false) ...[
                    Divider(height: 20, color: accent.withValues(alpha: 0.35)),
                    _section('Achievements', accent),
                    if (achievements.isEmpty)
                      const Text('No achievements listed.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    else
                      ...achievements.map((a) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• ${a.toString()}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        );
                      }),
                    ],
                  ]),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            TButton(
                label: '✏ Edit Content',
                outline: true,
                onTap: _busy
                    ? null
                    : () async {
                        final updated = await Navigator.pushNamed(
                          context,
                          R.resumeEditContent,
                          arguments: {
                            'cv_id': _cvId,
                            'cv_data': _cvData,
                            'design': _design,
                          },
                        );
                        if (updated is Map) {
                          final map = Map<String, dynamic>.from(updated);
                          setState(() {
                            _cvData = normalizeCvForPreview(map);
                            _cvId = map['id']?.toString() ?? _cvId;
                            _design = designPrefsFromCv(map);
                          });
                        }
                      }),
            const SizedBox(height: 8),
            TButton(
                label: '🎨 Customize Design',
                outline: true,
                onTap: _busy
                    ? null
                    : () async {
                        final updated = await Navigator.pushNamed(
                          context,
                          R.resumeCustomize,
                          arguments: {
                            'cv_id': _cvId,
                            'cv_data': _cvData,
                            'design': _design,
                          },
                        );
                        if (updated is Map) {
                          final map = Map<String, dynamic>.from(updated);
                          setState(() {
                            _cvData = normalizeCvForPreview(map);
                            _design = designPrefsFromCv(map);
                            if (map['id'] != null) {
                              _cvId = map['id']?.toString();
                            }
                          });
                        }
                      }),
            const SizedBox(height: 8),
            TButton(
                label: _busy ? 'Downloading…' : '↓ Download PDF',
                onTap: _busy ? null : _downloadPdf),
          ]),
        ),
      ],
    );
  }

  Future<void> _downloadPdf() async {
    setState(() => _busy = true);
    try {
      if (!mounted) return;
      final user = context.read<SessionController>().currentUser;
      final cvs = context.read<AppServices>().cvs;
      final cvId = await _ensureSavedCvId();
      if (cvId == null) throw Exception('Save your resume before downloading');

      final filename = cvPdfFilename(_cvData ?? {}, user);
      final exported = await cvs.exportPdf(cvId, filename: filename).unwrap();

      await saveDownloadedBytes(
        filename: exported.filename,
        bytes: exported.bytes,
        mimeType: 'application/pdf',
      );

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        R.resumeExportSuccess,
        arguments: {
          'filename': exported.filename,
          'bytes': exported.bytes,
          'cv_id': cvId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static Widget _section(String title, Color accent) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: accent,
                fontSize: 14)),
      );

  static Widget _project(String title, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: AppColors.textPrimary)),
          Text(desc,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}

// ── Edit Content ──────────────────────────────────────────────────────────────
class ResumeEditContentScreen extends StatefulWidget {
  const ResumeEditContentScreen({super.key});
  @override
  State<ResumeEditContentScreen> createState() =>
      _ResumeEditContentScreenState();
}

class _ResumeEditContentScreenState extends State<ResumeEditContentScreen> {
  final _bio = TextEditingController();
  final List<String> _skills = [];
  final _newSkill = TextEditingController();
  final List<_ProjectFields> _projects = [];
  String? _cvId;
  Map<String, dynamic> _design = defaultDesignPrefs();
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromArgs());
  }

  Future<void> _loadFromArgs() async {
    final args = ModalRoute.of(context)?.settings.arguments;
    Map<String, dynamic> preview = {};
    if (args is Map) {
      _cvId = args['cv_id']?.toString();
      if (args['cv_data'] is Map) {
        preview = normalizeCvForPreview(
          Map<String, dynamic>.from(args['cv_data'] as Map),
        );
      }
      if (args['design'] is Map) {
        _design = Map<String, dynamic>.from(args['design'] as Map);
      }
    } else {
      try {
        if (!mounted) return;
        final cvs =
            await context.read<AppServices>().cvs.listCVs(forceRefresh: true).unwrap();
        if (cvs.isNotEmpty) {
          _cvId = cvs.first.id;
          preview = normalizeCvForPreview(cvs.first.data);
          _design = designPrefsFromCv(cvs.first.data);
        }
      } catch (_) {}
    }

    final form = editFormFromPreview(preview);
    _bio.text = form.summary;
    _skills.addAll(filterSkillsForCvApi(form.skills).kept);
    _projects.clear();
    for (final p in form.projects) {
      _projects.add(_ProjectFields(
        title: TextEditingController(text: p['title']),
        desc: TextEditingController(text: p['description']),
      ));
    }
    if (_projects.isEmpty) {
      _projects.add(_ProjectFields());
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _bio.dispose();
    _newSkill.dispose();
    for (final p in _projects) {
      p.title.dispose();
      p.desc.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final user = context.read<SessionController>().currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    final projects = _projects
        .map((p) => {
              'title': p.title.text.trim(),
              'description': p.desc.text.trim(),
              'role': 'Contributor',
            })
        .where((p) => (p['title'] as String).isNotEmpty)
        .toList();

    final filtered = filterSkillsForCvApi(_skills);
    if (filtered.removed.isNotEmpty) {
      if (mounted) {
        setState(() {
          _skills
            ..clear()
            ..addAll(filtered.kept);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Removed invalid skills: ${filtered.removed.join(', ')}',
            ),
          ),
        );
      }
    }

    if (filtered.kept.isEmpty && _skills.isNotEmpty) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No valid skills to save. Add skills like backend, Python, or React.',
            ),
          ),
        );
      }
      return;
    }

    final payload = buildCvApiPayload(
      user: user,
      summary: _bio.text,
      skills: filtered.kept,
      projects: projects,
      design: _design,
    );

    final svc = context.read<AppServices>();
    final result = _cvId != null && _cvId!.isNotEmpty
        ? await svc.cvs.updateCV(_cvId!, payload)
        : await svc.cvs.createCV(payload);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isSuccess) {
      await svc.cvs.invalidateCVs();
      final cv = result.data;
      final row = Map<String, dynamic>.from(cv?.data ?? payload);
      if (cv != null) _cvId = cv.id;
      row['id'] = _cvId;
      if (!mounted) return;
      final removedNote = filtered.removed.isNotEmpty
          ? ' Removed unrecognized skills: ${filtered.removed.join(', ')}.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Resume saved to your account.$removedNote')),
      );
      Navigator.pop(context, normalizeCvForPreview(row));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Save failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Content',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(20),
            child: Padding(
                padding: EdgeInsets.only(bottom: 8, left: 16),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Update your resume information',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Professional Bio',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                    controller: _bio,
                    maxLines: 4,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.primary)))),
              ])),
          const SizedBox(height: 12),
          TCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Skills',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _skills
                        .map((s) => Chip(
                              label: Text(s),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () =>
                                  setState(() => _skills.remove(s)),
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              side: BorderSide(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3)),
                              labelStyle:
                                  const TextStyle(color: AppColors.primary),
                            ))
                        .toList()),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _newSkill,
                          decoration: InputDecoration(
                              hintText: 'Add a skill...',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                      color: AppColors.border)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: const BorderSide(
                                      color: AppColors.border)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8)))),
                  const SizedBox(width: 8),
                  GestureDetector(
                      onTap: () {
                        final raw = _newSkill.text.trim();
                        if (raw.isEmpty) return;
                        final canon = canonicalSkillName(raw);
                        if (canon == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '"$raw" is not a valid skill name. '
                                'Use letters, numbers, and spaces (2–80 characters), '
                                'e.g. backend, Python, React.',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          if (!_skills.contains(canon)) _skills.add(canon);
                          _newSkill.clear();
                        });
                      },
                      child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                              color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 18))),
                ]),
              ])),
          const SizedBox(height: 12),
          TCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Projects',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 10),
                ..._projects.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(children: [
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: p.title,
                              decoration: InputDecoration(
                                hintText: 'Project title',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          if (_projects.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.error, size: 20),
                              onPressed: () => setState(() {
                                p.title.dispose();
                                p.desc.dispose();
                                _projects.removeAt(i);
                              }),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        TextField(
                          controller: p.desc,
                          maxLines: 2,
                          decoration: InputDecoration(
                            hintText: 'Description',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none),
                          ),
                        ),
                      ]),
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => setState(() => _projects.add(_ProjectFields())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add project'),
                ),
              ])),
          const SizedBox(height: 20),
          TButton(
              label: _saving ? 'Saving…' : 'Save Changes',
              onTap: _saving ? null : _save),
          const SizedBox(height: 10),
          TButton(
              label: 'Cancel',
              outline: true,
              onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

// ── Customize ─────────────────────────────────────────────────────────────────
class ResumeCustomizeScreen extends StatefulWidget {
  const ResumeCustomizeScreen({super.key});
  @override
  State<ResumeCustomizeScreen> createState() => _ResumeCustomizeScreenState();
}

class _ResumeCustomizeScreenState extends State<ResumeCustomizeScreen> {
  String _style = 'Modern';
  Color _accent = AppColors.primary;
  final Map<String, bool> _sections = defaultSectionVisibility();
  String? _cvId;
  Map<String, dynamic>? _cvData;
  bool _saving = false;

  static final _accentOptions = [
    AppColors.primary,
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadArgs());
  }

  void _loadArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map) return;
    _cvId = args['cv_id']?.toString();
    if (args['cv_data'] is Map) {
      _cvData = normalizeCvForPreview(
        Map<String, dynamic>.from(args['cv_data'] as Map),
      );
    }
    final design = args['design'] is Map
        ? Map<String, dynamic>.from(args['design'] as Map)
        : designPrefsFromCv(Map<String, dynamic>.from(args));
    _style = design['style']?.toString() ?? 'Modern';
    final accentHex = design['accent']?.toString() ?? '#2D5FA6';
    _accent = colorFromHex(accentHex) ?? AppColors.primary;
    final sec = design['sections'];
    if (sec is Map) {
      for (final k in _sections.keys) {
        _sections[k] = sec[k] == true;
      }
    }
    setState(() {});
  }

  String _accentHex(Color c) {
    final rgb = c.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0')}';
  }

  Future<void> _apply() async {
    final user = context.read<SessionController>().currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    final design = {
      'style': _style,
      'accent': _accentHex(_accent),
      'sections': Map<String, bool>.from(_sections),
    };

    try {
      if (_cvId != null && _cvId!.isNotEmpty) {
        final form = _cvData != null
            ? editFormFromPreview(_cvData!)
            : (summary: '', skills: <String>[], projects: <Map<String, String>>[]);
        final payload = buildCvApiPayload(
          user: user,
          summary: form.summary,
          skills: form.skills,
          projects: form.projects,
          design: design,
        );
        await context.read<AppServices>().cvs.updateCV(_cvId!, payload).unwrap();
      } else if (_cvData != null) {
        final form = editFormFromPreview(_cvData!);
        final payload = buildCvApiPayload(
          user: user,
          summary: form.summary,
          skills: form.skills,
          projects: form.projects,
          design: design,
        );
        final created =
            await context.read<AppServices>().cvs.createCV(payload).unwrap();
        _cvId = created.id;
      }

      if (!mounted) return;
      final result = {
        'id': _cvId,
        'design': design,
        if (_cvData != null) ..._cvData!,
        'personal_info': {
          'resume_style': _style,
          'accent_color': _accentHex(_accent),
          'section_visibility': _sections,
        },
      };
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Design preferences saved')),
      );
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not apply changes: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
        title: const Text('Customize Resume',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(20),
            child: Padding(
                padding: EdgeInsets.only(bottom: 8, left: 16),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Personalize your resume design',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))))),
      ),
      body: Column(
        children: [
          Expanded(
              child: ListView(padding: const EdgeInsets.all(16), children: [
            TCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Resume Style',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                      children: ['Modern', 'Classic', 'Creative'].map((s) {
                    final sel = _style == s;
                    final icons = {
                      'Modern': Icons.auto_awesome,
                      'Classic': Icons.description_outlined,
                      'Creative': Icons.palette_outlined
                    };
                    return Expanded(
                        child: GestureDetector(
                      onTap: () => setState(() => _style = s),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                            color: sel
                                ? AppColors.primary.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    sel ? AppColors.primary : AppColors.border,
                                width: sel ? 2 : 1)),
                        child: Column(children: [
                          Icon(icons[s]!,
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 22),
                          const SizedBox(height: 4),
                          Text(s,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ]),
                      ),
                    ));
                  }).toList()),
                ])),
            const SizedBox(height: 12),
            TCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Accent Color',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                      children: _accentOptions.map((c) {
                    final sel = _accent == c;
                    return GestureDetector(
                      onTap: () => setState(() => _accent = c),
                      child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      sel ? Colors.black : Colors.transparent,
                                  width: 2.5)),
                          child: sel
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                              : null),
                    );
                  }).toList()),
                ])),
            const SizedBox(height: 12),
            TCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Resume Sections',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 15)),
                  const SizedBox(height: 8),
                  ..._sections.keys.map((s) => Row(children: [
                        Expanded(
                            child: Text(s,
                                style: const TextStyle(
                                    color: AppColors.textPrimary))),
                        Switch(
                            value: _sections[s]!,
                            onChanged: (v) => setState(() => _sections[s] = v),
                            activeThumbColor: AppColors.primary),
                      ])),
                ])),
          ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TButton(
                    label: _saving ? 'Saving…' : 'Apply Changes',
                    onTap: _saving ? null : _apply),
                const SizedBox(height: 8),
                TButton(
                    label: 'Cancel',
                    outline: true,
                    onTap: () => Navigator.pop(context)),
              ])),
        ],
      ),
    );
  }
}

// ── Export Success ────────────────────────────────────────────────────────────
class ResumeExportSuccessScreen extends StatelessWidget {
  const ResumeExportSuccessScreen({super.key});

  Future<void> _downloadAgain(BuildContext context) async {
    final args = ModalRoute.of(context)?.settings.arguments;
    Uint8List? bytes;
    var filename = 'resume.pdf';
    String? cvId;

    if (args is Map) {
      final rawBytes = args['bytes'];
      if (rawBytes is Uint8List) bytes = rawBytes;
      filename = args['filename']?.toString() ?? filename;
      cvId = args['cv_id']?.toString();
    }

    try {
      if (bytes == null && cvId != null) {
        final user = context.read<SessionController>().currentUser;
        final exported = await context
            .read<AppServices>()
            .cvs
            .exportPdf(cvId, filename: cvPdfFilename({}, user))
            .unwrap();
        bytes = exported.bytes;
        filename = exported.filename;
      }
      if (bytes == null) {
        throw Exception('No PDF data available');
      }
      await saveDownloadedBytes(
        filename: filename,
        bytes: bytes,
        mimeType: 'application/pdf',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloaded $filename')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final filename = args is Map
        ? (args['filename']?.toString() ?? 'resume.pdf')
        : 'resume.pdf';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context)),
          title: const Text('Back',
              style: TextStyle(fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check,
                      color: AppColors.success, size: 40)),
              const SizedBox(height: 24),
              const Text('Your resume is ready!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              const Text('Successfully exported as PDF',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () => _downloadAgain(context),
                child: TCard(
                  child: Row(children: [
                    Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.picture_as_pdf_outlined,
                            color: AppColors.primary, size: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(filename,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                          const Text('Tap to download again',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ])),
                    const Icon(Icons.download, color: AppColors.primary),
                  ]),
                ),
              ),
              const SizedBox(height: 40),
              TButton(
                  label: 'Back to Preview',
                  onTap: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      R.resumePreview,
                      (r) =>
                          r.settings.name == R.freelancerProfile ||
                          r.settings.name == R.freelancerHome)),
              const SizedBox(height: 12),
              TButton(
                  label: 'Create Another Resume',
                  outline: true,
                  onTap: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      R.resumeCVStart,
                      (r) =>
                          r.settings.name == R.freelancerProfile ||
                          r.settings.name == R.freelancerHome)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectFields {
  final TextEditingController title;
  final TextEditingController desc;

  _ProjectFields({
    TextEditingController? title,
    TextEditingController? desc,
  })  : title = title ?? TextEditingController(),
        desc = desc ?? TextEditingController();
}
