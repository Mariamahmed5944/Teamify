import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../widgets/widgets.dart';

// ── Mentor Main Screen (Tabs Container) ──────────────────────────────────────
class MentorMainScreen extends StatefulWidget {
  const MentorMainScreen({super.key});
  @override
  State<MentorMainScreen> createState() => _MentorMainScreenState();
}

class _MentorMainScreenState extends State<MentorMainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('AI Career Mentor',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textSecondary,
          indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(text: 'Mentor'),
            Tab(text: 'Skills'),
            Tab(text: 'Courses'),
            Tab(text: 'Performance'),
            Tab(text: 'Feedback')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _MentorOverviewTab(),
          _SkillsTab(),
          _DetailedCoursesTab(),
          _DetailedPerformanceTab(),
          _FeedbackTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, R.aiMentorChat),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('Ask AI Mentor',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── Detailed Performance Tab (Image 1) ────────────────────────────────────────
class _DetailedPerformanceTab extends StatelessWidget {
  const _DetailedPerformanceTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Performance',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('AI-generated rating',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.success.withOpacity(0.05)
            ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: const Column(children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                      value: 0.87,
                      strokeWidth: 12,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary))),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text('87',
                    style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                Text('Overall Score',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ]),
            SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.trending_up, color: AppColors.success, size: 20),
              SizedBox(width: 8),
              Text('+5 from last month',
                  style: TextStyle(
                      color: AppColors.success, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Performance Metrics',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _metricItem(
            'Commitment', 92, Icons.visibility_outlined, AppColors.success),
        _metricItem('Teamwork', 85, Icons.people_outline, AppColors.primary),
        _metricItem(
            'Quality', 84, Icons.workspace_premium_outlined, AppColors.accent),
        const SizedBox(height: 24),
        const Text('6-Month Trend',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        TCard(
            child: SizedBox(
                height: 150,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _bar('Jan', 0.4),
                      _bar('Feb', 0.6),
                      _bar('Mar', 0.5),
                      _bar('Apr', 0.8),
                      _bar('May', 0.7),
                      _bar('Jun', 0.9),
                    ]))),
      ],
    );
  }

  Widget _metricItem(String label, int val, IconData icon, Color col) => TCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          Row(children: [
            Icon(icon, color: col, size: 20),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('$val',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          TBar(value: val / 100, color: col),
        ]),
      );

  Widget _bar(String label, double h) =>
      Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        Container(
            width: 20,
            height: 100 * h,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 8),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ]);
}

// ── Detailed Courses Tab (Image 3) ────────────────────────────────────────────
class _DetailedCoursesTab extends StatelessWidget {
  const _DetailedCoursesTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Courses',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('AI-recommended for you',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        const AIBanner(
            title: 'Personalized Learning',
            subtitle: 'These courses are selected based on your goals'),
        const SizedBox(height: 24),
        const Text('Continue Learning',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('System Design Fundamentals',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            TChip(
                label: 'Advanced',
                bg: Colors.purple.withOpacity(0.1),
                textColor: Colors.purple),
          ]),
          const Text('Tech Academy • 24 lessons',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          const TBar(value: 0.45),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Lesson 10 of 24',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            TextButton(
                onPressed: () {},
                child: const Text('Continue →',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ]),
        ])),
        const SizedBox(height: 24),
        const Text('Recommended for You',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 12),
        _courseItem('Advanced React Patterns', 'Frontend Masters', '8 hours',
            4.8, 'Intermediate'),
        _courseItem('Database Optimization', 'SQL Academy', '12 hours', 4.9,
            'Advanced'),
        _courseItem('API Design Best Practices', 'Web Dev Pro', '6 hours', 4.7,
            'Intermediate'),
      ],
    );
  }

  Widget _courseItem(
          String title, String org, String time, double rate, String level) =>
      TCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text('$org • $time',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  Text(' $rate',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  const Text(' (1,243)',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ]),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TChip(
                label: level,
                bg: AppColors.primary.withOpacity(0.1),
                textColor: AppColors.primary),
            const SizedBox(height: 8),
            ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20)),
                child: const Text('Enroll',
                    style: TextStyle(color: Colors.white, fontSize: 12))),
          ]),
        ]),
      );
}

// ── Feedback Tab (Image 2) ────────────────────────────────────────────────────
class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();
  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  int _rating = 0;
  final _ctrl = TextEditingController();

  void _aiAssist() {
    setState(() {
      _ctrl.text =
          "The project collaboration was smooth, and the AI mentor's guidance helped me complete the system design module ahead of schedule.";
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('AI suggested a professional feedback for you.')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Feedback',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('Share your thoughts',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        TCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rate Your Experience',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                  5,
                  (i) => IconButton(
                        icon: Icon(i < _rating ? Icons.star : Icons.star_border,
                            size: 32,
                            color: i < _rating
                                ? Colors.amber
                                : AppColors.textHint),
                        onPressed: () => setState(() => _rating = i + 1),
                      ))),
          const SizedBox(height: 20),
          const Text('Your Feedback',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              TextField(
                  controller: _ctrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      hintText: 'Share your thoughts...',
                      border: InputBorder.none)),
              GestureDetector(
                onTap: _aiAssist,
                child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Icon(Icons.auto_awesome,
                      size: 14, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text('AI assist',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          TButton(
              label: 'Submit Feedback',
              icon: Icons.send,
              onTap: () {
                if (_rating == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please select a rating first!')));
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Feedback submitted successfully!'),
                    backgroundColor: AppColors.success));
              }),
        ])),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16)),
          child: const Row(children: [
            Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
            SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('AI Suggestion',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                      'Consider mentioning specific achievements or areas for improvement.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ])),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Recent Feedback',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        _recentFeedback('Sarah Johnson',
            'Excellent work on the project delivery!', '2 days ago', 5),
        _recentFeedback('Michael Chen',
            'Great collaboration and communication.', '1 week ago', 4),
      ],
    );
  }

  Widget _recentFeedback(String name, String text, String time, int rate) =>
      TCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Row(
                children: List.generate(
                    5,
                    (i) => Icon(Icons.star,
                        size: 14,
                        color: i < rate ? Colors.amber : AppColors.textHint))),
          ]),
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(time,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ]),
      );
}

// ── Mentor Overview Tab (Image 1) ─────────────────────────────────────────────
class _MentorOverviewTab extends StatelessWidget {
  const _MentorOverviewTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TCard(
          color: AppColors.primary.withOpacity(0.05),
          child:
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.stars, color: AppColors.primary, size: 24),
              SizedBox(width: 8),
              Text('Your AI Career Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            SizedBox(height: 12),
            Text(
              "You're progressing well on your path to Senior Developer. Focus on system design and code review skills to accelerate your growth.",
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        const Row(children: [
          Text('Suggested Next Steps',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Spacer(),
          Icon(Icons.auto_awesome, size: 14, color: AppColors.primary),
          SizedBox(width: 4),
          Text('AI-powered',
              style: TextStyle(fontSize: 12, color: AppColors.primary)),
        ]),
        const SizedBox(height: 12),
        _nextStep('Complete System Design course', 'High Priority', '4 Weeks',
            AppColors.error),
        _nextStep('Improve code review skills', 'Medium', '2 Weeks',
            AppColors.warning),
        _nextStep('Build a portfolio project', 'Suggested', '5 Weeks',
            AppColors.primary),
        const SizedBox(height: 20),
        const Text('Career Path Progress',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        const TCard(
            child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Junior',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('Mid-Level',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
            Text('Senior',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
          SizedBox(height: 12),
          TBar(value: 0.68),
          SizedBox(height: 8),
          Text("You're 68% of the way to Senior Developer",
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ])),
      ],
    );
  }

  Widget _nextStep(String title, String tag, String duration, Color tagCol) =>
      TCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(duration,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            TChip(label: tag, bg: tagCol.withOpacity(0.1), textColor: tagCol),
            const SizedBox(height: 8),
            TextButton(
                onPressed: () {},
                child: const Text('Start →',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
          ]),
        ]),
      );
}

// ── Skills Tab (Image 3) ──────────────────────────────────────────────────────
class _SkillsTab extends StatelessWidget {
  const _SkillsTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Skills',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        const Text('AI-recommended for you',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        const TCard(
          color: AppColors.primary,
          child: Row(children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
                child: Text(
                    'Personalized Recommendations based on your performance.',
                    style: TextStyle(color: Colors.white, fontSize: 13))),
          ]),
        ),
        const SizedBox(height: 20),
        const Row(children: [
          Text('Top Skills',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Spacer(),
          Text('Sorted by relevance',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 12),
        _skillCard('Advanced TypeScript', 'Intermediate', 95, Icons.code),
        _skillCard('System Design', 'Advanced', 88, Icons.architecture),
        _skillCard('GraphQL APIs', 'Intermediate', 82, Icons.api),
        _skillCard('Performance Optimization', 'Advanced', 78, Icons.speed),
      ],
    );
  }

  Widget _skillCard(String title, String level, int score, IconData icon) =>
      TCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          Row(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const Text('Based on your work history',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ])),
            TChip(
                label: level,
                bg: AppColors.primary.withOpacity(0.1),
                textColor: AppColors.primary),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            const Text('Relevance Score',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const Spacer(),
            Text('~$score%',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary)),
          ]),
          const SizedBox(height: 6),
          TBar(value: score / 100),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child:
                  TButton(label: 'Explore Skill', outline: true, onTap: () {})),
        ]),
      );
}

// ── Career Mentor Chat (Image 2) ──────────────────────────────────────────────
class CareerMentorChatScreen extends StatefulWidget {
  const CareerMentorChatScreen({super.key});
  @override
  State<CareerMentorChatScreen> createState() => _CareerMentorChatScreenState();
}

class _CareerMentorChatScreenState extends State<CareerMentorChatScreen> {
  final _ctrl = TextEditingController();
  final List<Map<String, dynamic>> _msgs = [
    {
      'text':
          'Hi! I\'m your AI Career Mentor. I\'m here to help you grow in your career. What would you like to focus on today?',
      'isMe': false
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
        title: const Row(children: [
          Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Mentor',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('Online',
                style: TextStyle(fontSize: 10, color: AppColors.success)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
            child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _msgs.length,
          itemBuilder: (_, i) => _buildBubble(_msgs[i]),
        )),
        if (_msgs.length == 1) _buildSuggestions(),
        _buildInput(),
      ]),
    );
  }

  Widget _buildSuggestions() => Container(
        height: 140,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.5,
          children: [
            _suggest('What should I focus on next?'),
            _suggest('How do I get promoted?'),
            _suggest('Recommend courses for me'),
            _suggest('Review my skill gaps'),
          ],
        ),
      );

  Widget _suggest(String text) => GestureDetector(
        onTap: () {
          setState(() {
            _msgs.add({'text': text, 'isMe': true});
          });
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Text(text,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
        ),
      );

  Widget _buildBubble(Map m) {
    final isMe = m['isMe'] as bool;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isMe ? null : Border.all(color: AppColors.border),
        ),
        child: Text(m['text'],
            style: TextStyle(
                color: isMe ? Colors.white : AppColors.textPrimary,
                fontSize: 13)),
      ),
    );
  }

  Widget _buildInput() => Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: SafeArea(
            child: Row(children: [
          Expanded(
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24)),
                  child: TextField(
                      controller: _ctrl,
                      decoration: const InputDecoration(
                          hintText: 'Ask your mentor anything...',
                          border: InputBorder.none)))),
          const SizedBox(width: 8),
          IconButton(
              icon: const Icon(Icons.send, color: AppColors.primary),
              onPressed: () {
                if (_ctrl.text.isNotEmpty) {
                  setState(() {
                    _msgs.add({'text': _ctrl.text, 'isMe': true});
                    _ctrl.clear();
                  });
                }
              }),
        ])),
      );
}
