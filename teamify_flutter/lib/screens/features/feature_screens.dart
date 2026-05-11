import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

// ── Complete Profile ──────────────────────────────────────────────────────────
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final List<String> _selectedRoles = ['Freelance Designer'];
  final List<String> _selectedAvailability = ['Full-time'];

  final List<String> _roles = [
    'UI/UX Designer',
    'Product Designer',
    'Freelance Designer',
    'Mobile App Designer',
    'Flutter Developer',
    'Frontend Developer',
    'Graphic Designer',
    'Team Lead',
    'Mentor',
    'Remote Designer'
  ];

  final List<String> _availability = [
    'Full-time',
    'Part-time',
    'Freelance',
    'Remote',
    'Hybrid',
    'Available Now',
    'Open to Opportunities'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complete Profile'),
        leading:
            const Padding(padding: EdgeInsets.all(12), child: TBackButton()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TBar(value: 0.6, height: 8),
            const SizedBox(height: 8),
            const Text('60% Complete',
                style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            const SizedBox(height: 32),
            Center(
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 2),
                        shape: BoxShape.circle),
                    child: const TAvatar(initials: 'MK', radius: 48),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 4)
                          ]),
                      child:
                          const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const TSectionHeader(title: 'Professional Bio'),
            const SizedBox(height: 12),
            _inputField('Full Name', 'Mariam Kamel'),
            _inputField('Bio',
                'Passionate UI/UX Designer looking for innovative projects.'),
            const SizedBox(height: 24),
            const TSectionHeader(title: 'Skills & Expertise'),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TChip(label: 'Product Design'),
                TChip(label: 'Flutter'),
                TChip(label: 'Figma'),
                TChip(label: '+ Add Skill', bg: Colors.transparent),
              ],
            ),
            const SizedBox(height: 32),
            const TSectionHeader(title: 'Preferences'),
            const SizedBox(height: 20),
            const Text('Preferred Role',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: _roles.map((role) {
                final isSelected = _selectedRoles.contains(role);
                return FilterChip(
                  label: Text(role),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedRoles.add(role);
                      } else {
                        _selectedRoles.remove(role);
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color:
                            isSelected ? AppColors.primary : AppColors.border),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Availability',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 0,
              children: _availability.map((a) {
                final isSelected = _selectedAvailability.contains(a);
                return FilterChip(
                  label: Text(a),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedAvailability.add(a);
                      } else {
                        _selectedAvailability.remove(a);
                      }
                    });
                  },
                  selectedColor: AppColors.primary.withOpacity(0.2),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color:
                            isSelected ? AppColors.primary : AppColors.border),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 48),
            TButton(
                label: 'Save & Continue', onTap: () => Navigator.pop(context)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SizedBox(width: double.infinity, child: Text(val))),
          ],
        ),
      );
}

// ── AI Teammate Matching ──────────────────────────────────────────────────────
class AITeammateMatchingScreen extends StatelessWidget {
  const AITeammateMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Talent Matching')),
      body: ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: 3,
        itemBuilder: (context, i) {
          final names = ['Sarah Johnson', 'Ahmed Ali', 'Jessica Chen'];
          final roles = ['UI Designer', 'Backend Dev', 'Project Manager'];
          final scores = [0.98, 0.85, 0.76];
          return TCard(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    TAvatar(
                        initials: names[i][0],
                        radius: 26,
                        bg: AppColors.accent),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(names[i],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 17)),
                          Text(roles[i],
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${(scores[i] * 100).toInt()}% Match',
                          style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.border),
                const SizedBox(height: 16),
                _scoreRow('Skills Compatibility', scores[i]),
                _scoreRow('Schedule Sync', 0.9),
                _scoreRow('Communication Style', 0.88),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: TButton(label: 'Quick Invite', onTap: () {})),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TButton(
                            label: 'Profile', outline: true, onTap: () {})),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _scoreRow(String label, double val) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
              Text('${(val * 100).toInt()}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            TBar(value: val, height: 4),
          ],
        ),
      );
}

// ── Project Risk Predictor ────────────────────────────────────────────────────
class ProjectRiskPredictorScreen extends StatelessWidget {
  const ProjectRiskPredictorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Risk Analysis')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CircularProgressIndicator(
                          value: 0.82,
                          strokeWidth: 12,
                          backgroundColor: AppColors.border,
                          color: AppColors.error),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('82%',
                            style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: AppColors.error)),
                        Text('HIGH RISK',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            const AIBanner(
              title: 'Project Status',
              subtitle: 'Task "Redesign" is 4 days behind schedule.',
              badge: 'ATTENTION',
            ),
            const SizedBox(height: 32),
            const TSectionHeader(title: 'Top Risk Factors'),
            const SizedBox(height: 16),
            _riskCard(
                'Resource Bottleneck',
                'Senior Designer is overloaded with 5 active projects.',
                Icons.person_off_outlined),
            _riskCard(
                'Scope Creep',
                'Recent client requests added 15% more work to the current sprint.',
                Icons.trending_up),
            const SizedBox(height: 32),
            const TSectionHeader(title: 'Workload Insights'),
            const SizedBox(height: 16),
            TCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _workloadRow('Team Capacity', 0.85, AppColors.warning),
                  const SizedBox(height: 12),
                  _workloadRow('Project Velocity', 0.42, AppColors.error),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const TSectionHeader(title: 'Suggested Actions'),
            const SizedBox(height: 16),
            TCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  _recItem('Reassign "Logo Design" to Freelancer Sarah'),
                  const Divider(indent: 50),
                  _recItem('Schedule a client meeting to finalize scope'),
                  const Divider(indent: 50),
                  _recItem('Apply for 3-day extension on Phase 1'),
                ],
              ),
            ),
            const SizedBox(height: 40),
            TButton(label: 'Optimize Project', onTap: () {}),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _riskCard(String title, String desc, IconData icon) => TCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: AppColors.error, size: 20)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(desc,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ])),
          ],
        ),
      );

  Widget _recItem(String text) => ListTile(
        leading: const Icon(Icons.lightbulb_outline, color: AppColors.warning),
        title: Text(text, style: const TextStyle(fontSize: 14)),
        trailing:
            const Icon(Icons.add_circle_outline, color: AppColors.primary),
      );

  Widget _workloadRow(String label, double val, Color color) => Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${(val * 100).toInt()}%',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          TBar(value: val, color: color, height: 6),
        ],
      );
}

// ── Chat Emotion Detection ────────────────────────────────────────────────────
class ChatEmotionScreen extends StatelessWidget {
  const ChatEmotionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Project Chat')),
      body: Column(
        children: [
          const AIBanner(
            title: 'Team Insights',
            subtitle: 'Recent messages show a shift in team sentiment.',
            badge: 'INFO',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _chatBubble(
                    'Sarah J.',
                    'Where are the final icons? We need them now.',
                    '10:02 AM',
                    AppColors.error,
                    'Anxious'),
                _chatBubble(
                    'Ahmed A.',
                    'Working on them, giving the final touches.',
                    '10:05 AM',
                    AppColors.textSecondary,
                    'Calm'),
                _chatBubble(
                    'Sarah J.',
                    'The client is waiting. This is the third delay.',
                    '10:08 AM',
                    AppColors.error,
                    'Frustrated'),
                _chatBubble(
                    'AI Assistant',
                    'I\'ve suggested a sync for 11 AM to resolve blockers.',
                    '10:09 AM',
                    AppColors.primary,
                    'Suggestion',
                    isAI: true),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border))),
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: AppColors.textHint),
                SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: AppColors.textHint)))),
                Icon(Icons.sentiment_satisfied_alt,
                    color: AppColors.textHint),
                SizedBox(width: 12),
                Icon(Icons.send, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(
          String sender, String msg, String time, Color color, String tone,
          {bool isAI = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TAvatar(
                initials: sender[0],
                radius: 18,
                bg: isAI ? AppColors.primary : AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(sender,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text(time,
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 11)),
                    const Spacer(),
                    Text(tone,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  TCard(
                    color: isAI ? AppColors.primaryLight : Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: Text(msg,
                        style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── Meeting Transcription ─────────────────────────────────────────────────────
class MeetingTranscriptionScreen extends StatelessWidget {
  const MeetingTranscriptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Meeting Intelligence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TCard(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.mic, color: AppColors.error),
                  SizedBox(width: 16),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Redesign Kick-off',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Recorded: May 07 • 42 mins',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ]),
                  Spacer(),
                  Icon(Icons.share_outlined, color: AppColors.primary),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const TSectionHeader(title: 'Meeting Summary'),
            const SizedBox(height: 16),
            const TCard(
              padding: EdgeInsets.all(16),
              child: Text(
                  'The team agreed on the mobile-first approach. Major technical blockers were discussed regarding the API integration. Ahmed will lead the design sprint starting Monday.',
                  style: TextStyle(height: 1.5, fontSize: 14)),
            ),
            const SizedBox(height: 32),
            const TSectionHeader(title: 'Action Items'),
            const SizedBox(height: 16),
            _taskItem('Finalize UI Kit by Tuesday', true),
            _taskItem('Draft API documentation', false),
            _taskItem('Schedule client walkthrough', false),
            const SizedBox(height: 32),
            const TSectionHeader(title: 'Live Transcript'),
            const SizedBox(height: 16),
            const TCard(
              padding: EdgeInsets.all(16),
              child: Text(
                  'Sarah: "The timeline is tight, we need to focus on core features first."\nAhmed: "I agree, I will prioritize the login and dashboard views."\n...',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.8)),
            ),
            const SizedBox(height: 40),
            TButton(label: 'Export Insights', onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _taskItem(String t, bool done) => TCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.circle_outlined,
              color: done ? AppColors.success : AppColors.primary),
          const SizedBox(width: 12),
          Text(t,
              style: TextStyle(
                  fontSize: 14,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? AppColors.textHint : AppColors.textPrimary)),
        ]),
      );
}

// ── File Version History ──────────────────────────────────────────────────────
class FileVersionHistoryScreen extends StatelessWidget {
  const FileVersionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Security & History')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.primaryDark,
            child: const Row(
              children: [
                Icon(Icons.cloud_done_outlined,
                    color: AppColors.success, size: 32),
                SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Cloud Backup Active',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text('Automatic versioning is enabled.',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 12)),
                    ])),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: 4,
              itemBuilder: (context, i) {
                return _versionTile(4 - i, i == 0);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TButton(
                label: 'Verify Integrity', icon: Icons.security, onTap: () {}),
          ),
        ],
      ),
    );
  }

  Widget _versionTile(int v, bool current) => TCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.insert_drive_file_outlined,
                    color: AppColors.primary)),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Text('Version $v.0',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    if (current) ...[
                      const SizedBox(width: 8),
                      const TChip(
                          label: 'LATEST',
                          bg: AppColors.success,
                          textColor: Colors.white,
                          fontSize: 9)
                    ],
                  ]),
                  const Text('May 07 • 02:45 PM',
                      style:
                          TextStyle(color: AppColors.textHint, fontSize: 12)),
                ])),
            TextButton(
                onPressed: () {},
                child: const Text('Restore',
                    style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
      );
}
