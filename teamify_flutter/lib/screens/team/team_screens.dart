import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/models/models.dart' as api;
import '../../widgets/widgets.dart';

class _TeamGroup {
  final String label;
  final List<String> memberNames;
  final int projectsCount;

  _TeamGroup({
    required this.label,
    required this.memberNames,
    required this.projectsCount,
  });
}

List<_TeamGroup> _teamsFromProjects(List<api.ApiProject> projects) {
  final buckets = <String, List<api.ApiProject>>{};
  for (final p in projects) {
    final key = p.category.trim().isNotEmpty ? p.category : 'Collaboration';
    buckets.putIfAbsent(key, () => []).add(p);
  }
  return buckets.entries.map((e) {
    final names = <String>{};
    for (final p in e.value) {
      names.addAll(p.members.where((x) => x.trim().isNotEmpty));
    }
    return _TeamGroup(
      label: e.key,
      memberNames: names.toList(),
      projectsCount: e.value.length,
    );
  }).toList();
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length >= 2)
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  return parts[0][0].toUpperCase();
}

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
      body: RepositoryLoader<List<_TeamGroup>>(
        load: () async => _teamsFromProjects(
          await context.read<AppRepositories>().projects.listProjects(),
        ),
        isEmpty: (t) => t.isEmpty,
        emptyMessage: 'No teams yet — join or create projects first.',
        builder: (context, teams) {
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: teams.length,
            itemBuilder: (_, i) {
              final t = teams[i];
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
                              Text(t.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary)),
                              Text(
                                  'Projects grouped by ${t.label}',
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
                        SizedBox(
                          height: 30,
                          width: 70,
                          child: Stack(
                            children: List.generate(
                                t.memberNames.length > 3
                                    ? 3
                                    : t.memberNames.length,
                                (index) {
                              final name = t.memberNames[index];
                              return Positioned(
                                left: index * 18.0,
                                child: TAvatar(initials: _initials(name), radius: 15),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${t.memberNames.length} members',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        const Icon(Icons.folder_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${t.projectsCount} projects',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: TButton(
          label: '+ Create Team',
          onTap: () => Navigator.pushNamed(context, R.addUser),
        ),
      ),
    );
  }
}

// ── Members List Screen ───────────────────────────────────────────────────────
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
            child: RepositoryLoader<List<api.ApiUser>>(
              load: () => context.read<AppRepositories>().search.users(''),
              isEmpty: (u) => u.isEmpty,
              emptyMessage: 'No members found',
              builder: (context, users) {
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final m = u.toDisplayModel();
                    return TCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          TAvatar(initials: m.initials, radius: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(m.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                            fontSize: 15)),
                                    const Spacer(),
                                    TChip(
                                      label: u.displayRole,
                                      bg: u.isFreelancer
                                          ? const Color(0xFFEFF6FF)
                                          : const Color(0xFFF0FDF4),
                                      textColor: u.isFreelancer
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF16A34A),
                                      fontSize: 10,
                                    ),
                                  ],
                                ),
                                Text(u.email,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: u.skills
                                      .take(3)
                                      .map((s) => Container(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.background,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(s,
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors
                                                        .textSecondary)),
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
