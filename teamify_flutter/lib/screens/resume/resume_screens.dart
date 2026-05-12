import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../widgets/widgets.dart';

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
          const Row(children: [
            TAvatar(initials: 'AJ', radius: 24),
            SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Alex Johnson',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text('Computer Science Student',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Column(children: [
                      Text('Projects',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                      Text('12',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                    ]))),
            const SizedBox(width: 10),
            Expanded(
                child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          SizedBox(width: 4),
                          Text('Rating',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                          SizedBox(width: 4),
                          Text('4.8',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary)),
                        ]))),
          ]),
          const SizedBox(height: 10),
          const Text('Top Skills',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
              spacing: 6,
              children: ['React', 'TypeScript', 'Node.js', 'Python', 'AI/ML']
                  .map((s) => TChip(label: s))
                  .toList()),
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
              'status': 'Complete'
            },
            {
              'icon': Icons.work_outline,
              'label': 'Projects & Work',
              'status': '12 items'
            },
            {
              'icon': Icons.track_changes,
              'label': 'Tasks & Contributions',
              'status': 'Analyzed'
            },
            {
              'icon': Icons.trending_up,
              'label': 'Feedback & Reviews',
              'status': 'Included'
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
        TButton(
          label: _generating ? 'Generating...' : '✦ Generate Resume',
          onTap: _generating
              ? null
              : () async {
                  setState(() => _generating = true);
                  await Future.delayed(const Duration(seconds: 2));
                  if (!context.mounted) return;
                  setState(() => _generating = false);
                  Navigator.pushNamed(context, R.resumePreview);
                },
        ),
        const SizedBox(height: 10),
        TButton(
            label: 'Preview Resume',
            outline: true,
            onTap: () => Navigator.pushNamed(context, R.resumePreview)),
      ]),
    );
  }
}

// ── Resume Preview ────────────────────────────────────────────────────────────
class ResumePreviewScreen extends StatelessWidget {
  const ResumePreviewScreen({super.key});
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
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(20),
            child: Padding(
                padding: EdgeInsets.only(bottom: 8, left: 16),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Review your AI-generated resume',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12))))),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)),
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Alex Johnson',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const Text('Computer Science Student',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const Row(children: [
                        Icon(Icons.email_outlined,
                            size: 12, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text('alex.johnson@email.com',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                        SizedBox(width: 12),
                        Icon(Icons.phone_outlined,
                            size: 12, color: AppColors.textSecondary),
                        SizedBox(width: 4),
                        Text('(555) 123-4567',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                      const Divider(height: 20),
                      _section('Professional Summary'),
                      const Text(
                          'Passionate computer science student with experience in web development and AI projects. Seeking opportunities to apply my skills in real-world applications.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5)),
                      const Divider(height: 20),
                      _section('Projects & Experience'),
                      _project('E-commerce Platform',
                          'Built a full-stack e-commerce app using React and Node.js'),
                      _project('AI Chatbot',
                          'Developed an intelligent chatbot using NLP and machine learning'),
                      const Divider(height: 20),
                      _section('Skills'),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            'React',
                            'TypeScript',
                            'Node.js',
                            'Python',
                            'AI/ML'
                          ]
                              .map((s) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                      border:
                                          Border.all(color: AppColors.border),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(s,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textPrimary))))
                              .toList()),
                      const Divider(height: 20),
                      _section('Achievements'),
                      const Text(
                          '• Completed 12 successful projects\n• Maintained 4.8/5.0 client rating\n• Contributed to open-source projects',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.8)),
                    ]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TButton(
                  label: '✏ Edit Content',
                  outline: true,
                  onTap: () =>
                      Navigator.pushNamed(context, R.resumeEditContent)),
              const SizedBox(height: 8),
              TButton(
                  label: '🎨 Customize Design',
                  outline: true,
                  onTap: () => Navigator.pushNamed(context, R.resumeCustomize)),
              const SizedBox(height: 8),
              TButton(
                  label: '↓ Download PDF',
                  onTap: () =>
                      Navigator.pushNamed(context, R.resumeExportSuccess)),
            ]),
          ),
        ],
      ),
    );
  }

  static Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
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
  final _bio = TextEditingController(
      text:
          'Passionate computer science student with experience in web development and AI projects. Seeking opportunities to apply my skills in real-world applications.');
  final List<String> _skills = [
    'React',
    'TypeScript',
    'Node.js',
    'Python',
    'AI/ML'
  ];
  final _newSkill = TextEditingController();
  final _proj1Title = TextEditingController(text: 'E-commerce Platform');
  final _proj1Desc = TextEditingController(
      text: 'Built a full-stack e-commerce app using React and Node.js');
  final _proj2Title = TextEditingController(text: 'AI Chatbot');
  final _proj2Desc = TextEditingController(
      text: 'Developed an intelligent chatbot using NLP and machine learning');

  @override
  Widget build(BuildContext context) {
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
                        if (_newSkill.text.isNotEmpty) {
                          setState(() {
                            _skills.add(_newSkill.text);
                            _newSkill.clear();
                          });
                        }
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
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      TextField(
                          controller: _proj1Title,
                          decoration: InputDecoration(
                              hintText: 'Project title',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10))),
                      const SizedBox(height: 6),
                      TextField(
                          controller: _proj1Desc,
                          maxLines: 2,
                          decoration: InputDecoration(
                              hintText: 'Description',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10))),
                    ])),
                const SizedBox(height: 8),
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10)),
                    child: Column(children: [
                      TextField(
                          controller: _proj2Title,
                          decoration: InputDecoration(
                              hintText: 'Project title',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10))),
                      const SizedBox(height: 6),
                      TextField(
                          controller: _proj2Desc,
                          maxLines: 2,
                          decoration: InputDecoration(
                              hintText: 'Description',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10))),
                    ])),
              ])),
          const SizedBox(height: 20),
          TButton(
              label: 'Save Changes',
              onTap: () => Navigator.pushNamed(context, R.resumePreview)),
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
  final Map<String, bool> _sections = {
    'Summary': true,
    'Experience': true,
    'Skills': true,
    'Achievements': true
  };

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
                      children: [
                    AppColors.primary,
                    const Color(0xFF8B5CF6),
                    const Color(0xFFEC4899),
                    const Color(0xFF10B981),
                    const Color(0xFFF59E0B)
                  ].map((c) {
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
                    label: 'Apply Changes',
                    onTap: () => Navigator.pushNamed(context, R.resumePreview)),
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
  @override
  Widget build(BuildContext context) {
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
              TCard(
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.check_circle_outline,
                          color: AppColors.primary, size: 28)),
                  const SizedBox(width: 14),
                  const Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Resume_Alex_Johnson.pdf',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        Text('Download to your device',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary)),
                      ])),
                ]),
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
