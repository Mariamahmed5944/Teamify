import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/network/api_result.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();
  
  String _target = 'all'; // 'all', 'students', 'freelancers', 'specific'
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);

    try {
      final String? specificId = _target == 'specific' ? _userIdCtrl.text.trim() : null;
      await context.read<AppServices>().admin.broadcastNotification(
        _target,
        _titleCtrl.text.trim(),
        _bodyCtrl.text.trim(),
        userId: specificId,
      ).unwrap();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement successfully broadcasted!'), backgroundColor: AppColors.success),
        );
        _titleCtrl.clear();
        _bodyCtrl.clear();
        _userIdCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Broadcast failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Announcement Center', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const TSectionHeader(title: 'Broadcast Announcement'),
            const SizedBox(height: 16),
            TCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Target Cohort', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _target,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Platform Users')),
                      DropdownMenuItem(value: 'students', child: Text('Students Only')),
                      DropdownMenuItem(value: 'freelancers', child: Text('Freelancers Only')),
                      DropdownMenuItem(value: 'specific', child: Text('Specific User (By ID)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _target = val);
                      }
                    },
                  ),
                  if (_target == 'specific') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _userIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enter Target User ID',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (_target == 'specific' && (val == null || val.trim().isEmpty)) {
                          return 'User ID is required for targeted broadcasts';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            TCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Announcement Content', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notification Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Title cannot be empty';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bodyCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message Body',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Message body cannot be empty';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            _sending
                ? const Center(child: CircularProgressIndicator())
                : TButton(
                    label: 'Send Broadcast',
                    icon: Icons.send_outlined,
                    onTap: _sendAnnouncement,
                  ),
          ],
        ),
      ),
    );
  }
}
