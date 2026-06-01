import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/network/api_result.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

class AdminAiScreen extends StatefulWidget {
  const AdminAiScreen({super.key});

  @override
  State<AdminAiScreen> createState() => _AdminAiScreenState();
}

class _AdminAiScreenState extends State<AdminAiScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = context.read<AppServices>().admin.getAiMetrics().unwrap();
    });
  }

  String _formatDuration(dynamic raw) {
    if (raw == null) return '0.00';
    final value = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
    return (value ?? 0).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Monitor', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.textSecondary)),
              ),
            );
          }
          final data = snapshot.data ?? {};
          final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
          final list = data['recent_requests'] as List? ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _aiCard('Total AI Calls (Today)', '${metrics['total_ai_requests'] ?? 0}', Icons.bar_chart, AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _aiCard('Failed Calls (Today)', '${metrics['failed_ai_calls'] ?? 0}', Icons.error_outline, AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _aiCard('Avg Latency', '${_formatDuration(metrics['average_response_time'])}s', Icons.timer_outlined, AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _aiCard('Token Usage (Today)', '${metrics['token_usage'] ?? 0}', Icons.monetization_on_outlined, AppColors.warning),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 28),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Most Popular AI Feature (Today)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            (metrics['most_used_feature'] ?? 'None').toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const TSectionHeader(title: 'Recent AI Requests Audit'),
              const SizedBox(height: 4),
              const Text(
                'Use AI Hub features to generate live audit entries.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No AI calls logged today.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                Column(
                  children: list.map((item) {
                    final req = item as Map<String, dynamic>;
                    final isOk = req['status'] == 'success';
                    final feature = req['feature'] ?? req['endpoint'] ?? '/api/ai';
                    return TCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isOk ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOk ? Icons.check : Icons.close,
                            color: isOk ? AppColors.success : AppColors.error,
                            size: 16,
                          ),
                        ),
                        title: Text(feature.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(
                          'User: ${req['user_name'] ?? 'System'} · Latency: ${_formatDuration(req['duration'])}s',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: TChip(
                          label: '${req['token_usage'] ?? 0} tokens',
                          bg: AppColors.primary.withValues(alpha: 0.1),
                          textColor: AppColors.primary,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _aiCard(String title, String value, IconData icon, Color color) {
    return TCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
