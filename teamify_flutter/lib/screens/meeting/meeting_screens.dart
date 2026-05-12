import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/widgets.dart';

// ── Meeting Screen (Live/Start) ──────────────────────────────────────────────
class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key});
  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  bool _isLive = false;

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
        title: const Text('Meeting',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Call Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.videocam_outlined,
                          color: AppColors.primary)),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Design Team Sync',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Website Redesign Project',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Participants Header
            Row(
              children: [
                const Icon(Icons.people_outline,
                    size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                const Text('Participants',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('3 active',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 16),
            // Recording Banner (If Live)
            if (_isLive) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFFDC2626), shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Recording in progress',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textPrimary)),
                          Text('AI transcription active',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary)),
                        ])),
                    const Icon(Icons.access_time,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    const Text('00:00',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            // Participants List
            Expanded(
              child: ListView(
                children: [
                  _participantRow('John Doe', 'In meeting', true),
                  _participantRow('Alice Smith', 'In meeting', true),
                  _participantRow('Mike Kumar', 'In meeting', true),
                  _participantRow('Lisa Park', 'Not joined', false),
                ],
              ),
            ),
            // Live Notes (If Live)
            if (_isLive) ...[
              const Text('Live Notes',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Text(
                      'AI is capturing discussion points and action items in real-time...',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.mic_none),
                          label: const Text('Mute'),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.stop_circle_outlined,
                              color: Color(0xFFDC2626)),
                          label: const Text('Stop Recording',
                              style: TextStyle(color: Color(0xFFDC2626))),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))))),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const MeetingSummaryScreen())),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('End Meeting',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16))),
            ] else ...[
              ElevatedButton(
                  onPressed: () => setState(() => _isLive = true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  child: const Text('Start Meeting',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _participantRow(String name, String status, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(
          children: [
            TAvatar(
                initials: name.split(' ').map((e) => e[0]).join(), radius: 18),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(status,
                  style: TextStyle(
                      fontSize: 11,
                      color: isActive
                          ? const Color(0xFF16A34A)
                          : AppColors.textSecondary)),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Meeting Summary Screen ───────────────────────────────────────────────────
class MeetingSummaryScreen extends StatelessWidget {
  const MeetingSummaryScreen({super.key});

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
        title: const Text('Meeting Summary',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // AI Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8)),
            child: const Row(children: [
              Icon(Icons.bolt, size: 16, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('AI-generated summary from meeting recording',
                  style: TextStyle(
                      color: Color(0xFF7C3AED),
                      fontSize: 11,
                      fontWeight: FontWeight.bold))
            ]),
          ),
          const SizedBox(height: 20),
          const Text('Design Team Sync',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Row(children: [
            Text('December 25, 2025',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            SizedBox(width: 12),
            Icon(Icons.circle, size: 4, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Text('45 minutes',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            SizedBox(width: 12),
            Icon(Icons.circle, size: 4, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Text('4 participants',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ]),
          const SizedBox(height: 24),
          _sectionHeader(Icons.chat_bubble_outline, 'Key Discussion Points'),
          _pointBox('1. Reviewed current progress on homepage redesign'),
          _pointBox(
              '2. Discussed color palette adjustments to align with brand guidelines'),
          _pointBox('3. Identified need for additional user research'),
          _pointBox('4. Planned sprint goals for next two weeks'),
          const SizedBox(height: 24),
          _sectionHeader(Icons.check_box_outlined, 'Decisions Made'),
          _decisionItem(
              'Adopt new color palette with adjusted primary blue (#2563EB)'),
          _decisionItem('Schedule user testing for next Monday'),
          _decisionItem(
              'Implement mobile-first approach for all new components'),
          _decisionItem('Weekly design reviews every Friday at 2 PM'),
          const SizedBox(height: 24),
          _sectionHeader(Icons.assignment_outlined, 'Action Items'),
          _actionCard('Create wireframes for mobile homepage', 'Alice Smith',
              'Wednesday, Jan 8', const Color(0xFFF59E0B)),
          _actionCard(
              'Coordinate with development team on technical constraints',
              'Mike Kumar',
              'Friday, Jan 10',
              const Color(0xFFF59E0B)),
          _actionCard('Update design system documentation', 'John Doe',
              'Thursday, Jan 9', const Color(0xFFF59E0B)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, color: Colors.white, size: 20),
              label: const Text('Export as PDF',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))))),
              const SizedBox(width: 12),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.check_box_outlined),
                      label: const Text('Create Tasks'),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))))),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.textPrimary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
      ]));
  Widget _pointBox(String t) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8)),
      child: Text(t,
          style: const TextStyle(
              fontSize: 12, color: AppColors.textPrimary, height: 1.4)));
  Widget _decisionItem(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.check_circle, size: 16, color: Color(0xFF10B981)),
        const SizedBox(width: 12),
        Expanded(
            child: Text(t, style: const TextStyle(fontSize: 12, height: 1.4)))
      ]));
  Widget _actionCard(String t, String owner, String date, Color c) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1E40AF))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(owner,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
          Text(date,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: c))
        ])
      ]));
}
