import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/network/api_result.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

class AdminSecurityScreen extends StatefulWidget {
  const AdminSecurityScreen({super.key});

  @override
  State<AdminSecurityScreen> createState() => _AdminSecurityScreenState();
}

class _AdminSecurityScreenState extends State<AdminSecurityScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _future = context.read<AppServices>().admin.getSecuritySummary().unwrap();
    });
  }

  Future<void> _lockAccount(String userId) async {
    try {
      await context.read<AppServices>().admin.updateUserStatus(userId, 'lock').unwrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account locked successfully'), backgroundColor: AppColors.success),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lock failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _revokeSession(String userId) async {
    try {
      await context.read<AppServices>().admin.revokeSessions(userId).unwrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Active sessions revoked successfully'), backgroundColor: AppColors.success),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revocation failed: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Security Center', style: TextStyle(fontWeight: FontWeight.bold)),
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
          final alerts = data['alerts'] as List? ?? [];
          final logins = data['logins'] as List? ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // KPI Cards
              Row(
                children: [
                  Expanded(
                    child: _securityCard('Failed Logins', '${metrics['failed_logins'] ?? 0}', Icons.lock_open, AppColors.error),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _securityCard('Locked Users', '${metrics['locked_users'] ?? 0}', Icons.block_outlined, AppColors.warning),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _securityCard('Active Sessions', '${metrics['active_sessions'] ?? 0}', Icons.devices_other, AppColors.success),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _securityCard('Suspicious Alerts', '${metrics['suspicious_activity_alerts'] ?? 0}', Icons.shield_outlined, AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Anomalies/Alerts Log
              if (alerts.isNotEmpty) ...[
                const TSectionHeader(title: 'Active Intrusion Alerts'),
                const SizedBox(height: 12),
                Column(
                  children: alerts.map((a) {
                    final alert = a as Map<String, dynamic>;
                    return TCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                        title: Text(alert['type'] ?? 'Anomaly Detected', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text(alert['details']?.toString() ?? 'Failed attempts', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        trailing: OutlinedButton(
                          onPressed: () => _lockAccount(alert['user_id'].toString()),
                          child: const Text('Lock User', style: TextStyle(fontSize: 11, color: AppColors.error)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

              // Access Log Table
              const TSectionHeader(title: 'Recent Authenticated Logins'),
              const SizedBox(height: 12),
              if (logins.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No access records tracked.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                Column(
                  children: logins.map((item) {
                    final log = item as Map<String, dynamic>;
                    final isSuccess = log['status'] == 'success';
                    final dateStr = (log['timestamp'] ?? '').toString().replaceAll('T', ' ').split('.').first;

                    return TCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSuccess ? Icons.verified_user : Icons.gpp_bad,
                                  color: isSuccess ? AppColors.success : AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(log['user_name'] ?? 'System', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('IP: ${log['ip_address']} · Device: ${log['device_info']}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Text(dateStr, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              ],
                            ),
                            if (isSuccess && log['user_id'] != null) ...[
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.logout, size: 14, color: AppColors.error),
                                    label: const Text('Revoke Session', style: TextStyle(fontSize: 11, color: AppColors.error)),
                                    onPressed: () => _revokeSession(log['user_id'].toString()),
                                  ),
                                ],
                              ),
                            ],
                          ],
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

  Widget _securityCard(String title, String value, IconData icon, Color color) {
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
