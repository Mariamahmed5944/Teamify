import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../core/session/session_controller.dart';
import '../../data/dummy_data.dart';
import '../../widgets/widgets.dart';

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
            _menuTile(context, Icons.logout, 'Log Out',
                onTap: () => Navigator.pushNamedAndRemoveUntil(
                    context, R.roleSelection, (_) => false),
                color: Colors.red),
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

// ── Freelancer Profile ────────────────────────────────────────────────────────
class FreelancerProfileScreen extends StatelessWidget {
  const FreelancerProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _ProfileBase(
      name: 'Mariam Khan',
      role: 'Freelance Developer',
      initials: 'MK',
      email: 'mariam.khan@email.com',
      location: 'San Francisco, CA',
      joined: 'Joined March 2025',
      projects: '3',
      tasksDone: '24',
      score: '87',
    );
  }
}

// ── Student Profile ───────────────────────────────────────────────────────────
class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _ProfileBase(
      name: 'Mariam Khan',
      role: 'Student Developer',
      initials: 'MK',
      email: 'mariam.khan@email.com',
      location: 'San Francisco, CA',
      joined: 'Joined March 2025',
      projects: '3',
      tasksDone: '24',
      score: '87',
    );
  }
}

// ── Admin Profile ─────────────────────────────────────────────────────────────
class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const _ProfileBase(
      name: 'Mariam Khan',
      role: 'System Administrator',
      initials: 'MK',
      email: 'mariam.khan@email.com',
      location: 'San Francisco, CA',
      joined: 'Joined March 2025',
      projects: '3',
      tasksDone: '24',
      score: '87',
      isAdmin: true,
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
  final _name = TextEditingController(text: 'Alice Smith');
  final _email = TextEditingController(text: 'alice@teamify.com');
  final _phone = TextEditingController(text: '+20 100 000 0000');
  final _bio = TextEditingController(
      text: 'Flutter developer with 3+ years experience.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
              child: Stack(children: [
            const TAvatar(initials: 'AS', radius: 40),
            Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 14))),
          ])),
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
                    controller: _name, decoration: _inputDec('Your name')),
                const SizedBox(height: 12),
                const Text('Email',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                    controller: _email, decoration: _inputDec('Your email')),
                const SizedBox(height: 12),
                const Text('Phone',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                    controller: _phone, decoration: _inputDec('Your phone')),
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
          TButton(label: 'Save Changes', onTap: () => Navigator.pop(context)),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: DummyData.projects.length,
        itemBuilder: (_, i) {
          final p = DummyData.projects[i];
          return TCard(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
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
                    bg: AppColors.success.withOpacity(0.1),
                    textColor: AppColors.success),
              ]));
        },
      ),
    );
  }
}

// ── Ratings ───────────────────────────────────────────────────────────────────
class RatingsScreen extends StatelessWidget {
  const RatingsScreen({super.key});
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TCard(
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Column(children: [
              const Text('4.8',
                  style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Row(
                  children: List.generate(
                      5,
                      (i) => Icon(i < 4 ? Icons.star : Icons.star_half,
                          color: Colors.amber, size: 20))),
              const Text('Based on 24 reviews',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ])),
          const SizedBox(height: 12),
          ...<Map<String, dynamic>>[
            {
              'name': 'John Doe',
              'stars': 5,
              'comment':
                  'Excellent work! Delivered on time and exceeded expectations.',
              'date': '2 weeks ago'
            },
            {
              'name': 'Lisa Park',
              'stars': 5,
              'comment':
                  'Very professional and skilled developer. Highly recommend!',
              'date': '1 month ago'
            },
            {
              'name': 'Mike Kumar',
              'stars': 4,
              'comment': 'Great communication and clean code. Will work again.',
              'date': '2 months ago'
            },
          ].map((r) => TCard(
                margin: const EdgeInsets.only(bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        TAvatar(initials: (r['name'] as String)[0], radius: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(r['name'] as String,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      fontSize: 13)),
                              Row(
                                  children: List.generate(
                                      r['stars'] as int,
                                      (_) => const Icon(Icons.star,
                                          size: 12, color: Colors.amber))),
                            ])),
                        Text(r['date'] as String,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 6),
                      Text(r['comment'] as String,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ]),
              )),
        ],
      ),
    );
  }
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
                  color: Colors.purple.withOpacity(0.15),
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
                      color: (c['levelColor'] as Color).withOpacity(0.15),
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

class _PerfTab extends StatelessWidget {
  const _PerfTab();
  @override
  Widget build(BuildContext context) {
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
          child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('87',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text('Overall Score',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ]),
        ),
        const SizedBox(height: 12),
        const Text('↗ +5 from last month',
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
          'value': 92,
          'color': AppColors.success
        },
        {
          'icon': Icons.people_outline,
          'label': 'Teamwork',
          'value': 85,
          'color': AppColors.primary
        },
        {
          'icon': Icons.chat_bubble_outline,
          'label': 'Quality',
          'value': 84,
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
                      value: (m['value'] as int) / 100,
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

class _TrendPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();
  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  int _stars = 0;
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Rate Your Experience',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(
            children: List.generate(
                5,
                (i) => GestureDetector(
                      onTap: () => setState(() => _stars = i + 1),
                      child: Icon(i < _stars ? Icons.star : Icons.star_border,
                          color: Colors.amber, size: 32),
                    ))),
        const SizedBox(height: 12),
        const Text('Your Feedback',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
            const Positioned(
                bottom: 8,
                right: 8,
                child: Row(children: [
                  Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('AI assist',
                      style: TextStyle(fontSize: 11, color: AppColors.primary))
                ])),
          ]),
        ),
        const SizedBox(height: 12),
        TButton(label: '✈ Submit Feedback', onTap: () {}),
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
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('AI Suggestion',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 13)),
                  Text(
                      'Consider mentioning specific achievements or areas for improvement to make your feedback more actionable.',
                      style: TextStyle(
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
      ...<Map<String, dynamic>>[
        {
          'name': 'Sarah Johnson',
          'stars': 5,
          'comment': 'Excellent work on the project delivery!',
          'date': '2 days ago'
        },
        {
          'name': 'Michael Chen',
          'stars': 4,
          'comment': 'Great collaboration and communication.',
          'date': '1 week ago'
        },
      ].map((f) => TCard(
          margin: const EdgeInsets.only(bottom: 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(f['name'] as String,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Row(
                  children: List.generate(
                      5,
                      (i) => Icon(
                          i < (f['stars'] as int)
                              ? Icons.star
                              : Icons.star_border,
                          size: 14,
                          color: Colors.amber))),
            ]),
            const SizedBox(height: 4),
            Text(f['comment'] as String,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text(f['date'] as String,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ]))),
    ]);
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
    return Scaffold(
      backgroundColor: AppColors.background,
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
            const Divider(height: 1, color: AppColors.border),
            _tile(context, Icons.dark_mode_outlined, 'Dark Mode', 'Off',
                onTap: () {}),
          ])),
          const SizedBox(height: 24),
          const TSectionHeader(title: 'Security & Privacy'),
          const SizedBox(height: 12),
          TCard(
              child: Column(children: [
            _tile(context, Icons.lock_outline, 'Privacy Policy', '',
                onTap: () {}),
            const Divider(height: 1, color: AppColors.border),
            _tile(context, Icons.security_outlined, 'Security Center', '',
                onTap: () => Navigator.pushNamed(context, R.securityCenter)),
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
