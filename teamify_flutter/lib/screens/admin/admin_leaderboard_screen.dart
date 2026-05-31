import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/network/api_result.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

class AdminLeaderboardScreen extends StatefulWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  State<AdminLeaderboardScreen> createState() => _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState extends State<AdminLeaderboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  List<dynamic> _ratings = [];
  List<dynamic> _feedback = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final admin = context.read<AppServices>().admin;
      final ratings = await admin.getRatingsLeaderboard().unwrap();
      final feedback = await admin.getFeedbackLeaderboard().unwrap();
      if (mounted) {
        setState(() {
          _ratings = ratings['items'] as List? ?? [];
          _feedback = feedback['items'] as List? ?? [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load leaderboard: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ratings & Feedback Leaderboard', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Star Ratings'),
            Tab(text: 'Feedback Scores'),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildList(_ratings, isRating: true),
                _buildList(_feedback, isRating: false),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> items, {required bool isRating}) {
    if (items.isEmpty) {
      return const Center(child: Text('No data yet', style: TextStyle(color: AppColors.textSecondary)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final row = items[i] as Map<String, dynamic>;
        final rank = i + 1;
        final name = row['user_name'] ?? 'User';
        final score = isRating ? row['avg_score'] : row['avg_rating'];
        final count = isRating ? row['rating_count'] : row['feedback_count'];
        return TCard(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: rank <= 3 ? AppColors.warning.withValues(alpha: 0.2) : AppColors.border,
              child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${isRating ? 'Ratings' : 'Feedback entries'}: $count'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isRating ? Icons.star : Icons.thumb_up, color: AppColors.warning, size: 18),
                const SizedBox(width: 4),
                Text('$score', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }
}
