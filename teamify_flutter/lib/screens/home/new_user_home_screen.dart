import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../widgets/widgets.dart';

class NewUserHomeScreen extends StatelessWidget {
  final String userName;
  final String role; // 'Student' or 'Freelancer'

  const NewUserHomeScreen({
    super.key,
    this.userName = 'Mariam',
    this.role = 'Student',
  });

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final displayRole = args?['role'] as String? ?? role;
    final displayName = args?['name'] as String? ?? userName;
    final pendingApproval = args?['pendingApproval'] == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Premium Header with Gradient
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome, $displayName 👋',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pendingApproval
                            ? 'Your account is awaiting admin approval. You will be notified once approved.'
                            : 'Your journey as a $displayRole starts here. Let\'s set up your workspace.',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const TAvatar(initials: 'M', radius: 28, bg: Colors.white24),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TSectionHeader(
                      title: pendingApproval
                          ? 'Pending Approval'
                          : 'Quick Onboarding'),
                  const SizedBox(height: 16),
                  if (pendingApproval)
                    const TCard(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'An admin must approve your account before you can access protected Teamify features. Please try logging in again after approval.',
                        style: TextStyle(
                            color: AppColors.textSecondary, height: 1.4),
                      ),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 600;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: isWide
                              ? 3
                              : 3, // For 3 cards, 3 is most balanced.
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: isWide ? 1.4 : 0.85,
                          children: [
                            _ActionCard(
                              icon: Icons.person_add_alt_1_outlined,
                              title: 'Profile',
                              subtitle: 'Add bio & photo',
                              onTap: () => Navigator.pushNamed(
                                  context, R.completeProfile),
                            ),
                            _ActionCard(
                              icon: Icons.auto_awesome,
                              title: 'Match',
                              subtitle: 'Find partners',
                              onTap: () => Navigator.pushNamed(
                                  context, R.teammateMatching),
                            ),
                            _ActionCard(
                              icon: Icons.gpp_maybe_outlined,
                              title: 'Risk AI',
                              subtitle: 'Project health',
                              onTap: () =>
                                  Navigator.pushNamed(context, R.riskPredictor),
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                  const TSectionHeader(title: 'Suggested Steps'),
                  const SizedBox(height: 16),
                  TCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _StepItem(
                          title: 'Add your skills',
                          onTap: () => Navigator.pushNamed(context, R.skills),
                        ),
                        const Divider(
                            height: 1, indent: 60, color: AppColors.border),
                        _StepItem(
                          title: 'Complete your profile',
                          onTap: () =>
                              Navigator.pushNamed(context, R.completeProfile),
                        ),
                        const Divider(
                            height: 1, indent: 60, color: AppColors.border),
                        _StepItem(
                          title: displayRole == 'Student'
                              ? 'Join a project'
                              : 'Find work',
                          onTap: () => Navigator.pushNamed(context, R.search),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: TBottomNav(
        current: 0,
        onTap: (i) => handleFreelancerNav(context, i),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textSecondary, height: 1.2),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _StepItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: const Icon(Icons.check, color: AppColors.success, size: 16),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary)),
      trailing:
          const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
    );
  }
}
