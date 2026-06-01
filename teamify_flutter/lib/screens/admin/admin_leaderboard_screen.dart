import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

class AdminLeaderboardScreen extends StatefulWidget {
  const AdminLeaderboardScreen({super.key});

  @override
  State<AdminLeaderboardScreen> createState() => _AdminLeaderboardScreenState();
}

class _AdminLeaderboardScreenState extends State<AdminLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  String? _error;
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
    setState(() {
      _loading = true;
      _error = null;
    });

    final admin = context.read<AppServices>().admin;
    String? error;
    List<dynamic> ratings = [];
    List<dynamic> feedback = [];

    final ratingsResult = await admin.getRatingsLeaderboard();
    ratingsResult.when(
      success: (data) => ratings = data['items'] as List? ?? [],
      failure: (msg) => error = msg,
    );

    final feedbackResult = await admin.getFeedbackLeaderboard();
    feedbackResult.when(
      success: (data) => feedback = data['items'] as List? ?? [],
      failure: (msg) {
        error ??= msg;
      },
    );

    if (!mounted) return;
    setState(() {
      _ratings = ratings;
      _feedback = feedback;
      _error = error;
      _loading = false;
    });

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error!),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ratings & Feedback Leaderboard',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Star Ratings'),
            Tab(text: 'Feedback Scores'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: AppColors.error.withValues(alpha: 0.1),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildList(_ratings, isRating: true),
                      _buildList(_feedback, isRating: false),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildList(List<dynamic> items, {required bool isRating}) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error != null
                ? 'Could not load leaderboard data.\nTap refresh after restarting the backend.'
                : 'No data yet.\nPeer feedback will appear here once teammates rate each other.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
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
              backgroundColor: rank <= 3
                  ? AppColors.warning.withValues(alpha: 0.2)
                  : AppColors.border,
              child: Text('#$rank',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${isRating ? 'Ratings' : 'Feedback entries'}: $count'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isRating ? Icons.star : Icons.thumb_up,
                    color: AppColors.warning, size: 18),
                const SizedBox(width: 4),
                Text('$score',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }
}
