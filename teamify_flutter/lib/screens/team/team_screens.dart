import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/dummy_data.dart';
import '../../widgets/widgets.dart';

// ── Teams List Screen ────────────────────────────────────────────────────────
class TeamsListScreen extends StatelessWidget {
  const TeamsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title:
            const Text('Teams', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: DummyData.teams.length,
        itemBuilder: (_, i) {
          final t = DummyData.teams[i];
          return TCard(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.people_outline,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppColors.textPrimary)),
                          Text(t.description,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Member Avatars
                    SizedBox(
                      height: 30,
                      width: 70, // Fixed width to prevent 'size.isFinite' error
                      child: Stack(
                        children: List.generate(
                            t.memberIds.length > 3 ? 3 : t.memberIds.length,
                            (index) {
                          final user = DummyData.users.firstWhere(
                            (u) => u.id == t.memberIds[index],
                            orElse: () => DummyData.users.first,
                          );
                          return Positioned(
                            left: index * 18.0,
                            child: TAvatar(initials: user.initials, radius: 15),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${t.memberIds.length} members',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                    const Spacer(),
                    const Icon(Icons.folder_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${t.projectsCount} projects',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: TButton(
          label: '+ Create Team',
          onTap: () => Navigator.pushNamed(context,
              R.addUser), // Using addUser route for now or should I add a new one?
        ),
      ),
    );
  }
}

// ── Members List Screen (Improved) ───────────────────────────────────────────
class MembersListScreen extends StatelessWidget {
  const MembersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: const Text('Members',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name or skill...',
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search,
                      color: AppColors.textSecondary, size: 20),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: DummyData.users.length,
              itemBuilder: (_, i) {
                final u = DummyData.users[i];
                return TCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      TAvatar(initials: u.initials, radius: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(u.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        fontSize: 15)),
                                const Spacer(),
                                TChip(
                                  label: u.role,
                                  bg: u.role == 'Freelancer'
                                      ? const Color(0xFFEFF6FF)
                                      : const Color(0xFFF0FDF4),
                                  textColor: u.role == 'Freelancer'
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFF16A34A),
                                  fontSize: 10,
                                ),
                              ],
                            ),
                            Text(u.role,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: u.skills
                                  .take(3)
                                  .map((s) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: Text(s,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color:
                                                    AppColors.textSecondary)),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
