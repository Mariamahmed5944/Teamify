import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/network/api_result.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aiLimitsCtrl = TextEditingController();
  final _maxUploadCtrl = TextEditingController();
  final _allowedTypesCtrl = TextEditingController();
  final _sessionTimeoutCtrl = TextEditingController();

  bool _registrationEnabled = true;
  bool _aiEnabled = true;
  bool _emailNotifs = true;
  bool _pushNotifs = true;
  String _passwordPolicy = 'medium';
  
  bool _loading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _aiLimitsCtrl.dispose();
    _maxUploadCtrl.dispose();
    _allowedTypesCtrl.dispose();
    _sessionTimeoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppServices>().admin.getSettings().unwrap();
      setState(() {
        _registrationEnabled = res['registration_enabled'] ?? true;
        _aiEnabled = res['ai_enabled'] ?? true;
        _aiLimitsCtrl.text = (res['ai_limits'] ?? 100).toString();
        _maxUploadCtrl.text = (res['max_upload_size_mb'] ?? 5).toString();
        _allowedTypesCtrl.text = (res['allowed_file_types'] as List? ?? []).join(', ');
        _sessionTimeoutCtrl.text = (res['session_timeout_min'] ?? 60).toString();
        _passwordPolicy = res['password_policy'] ?? 'medium';
        _emailNotifs = res['email_notifications'] ?? true;
        _pushNotifs = res['push_notifications'] ?? true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final List<String> fileTypes = _allowedTypesCtrl.text
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();

    final Map<String, dynamic> payload = {
      'registration_enabled': _registrationEnabled,
      'ai_enabled': _aiEnabled,
      'ai_limits': int.tryParse(_aiLimitsCtrl.text) ?? 100,
      'max_upload_size_mb': int.tryParse(_maxUploadCtrl.text) ?? 5,
      'allowed_file_types': fileTypes,
      'session_timeout_min': int.tryParse(_sessionTimeoutCtrl.text) ?? 60,
      'password_policy': _passwordPolicy,
      'email_notifications': _emailNotifs,
      'push_notifications': _pushNotifs,
    };

    try {
      await context.read<AppServices>().admin.updateSettings(payload).unwrap();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Global system settings saved successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('System Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. User Registration
                  const TSectionHeader(title: 'User Registration Preferences'),
                  const SizedBox(height: 10),
                  TCard(
                    padding: const EdgeInsets.all(12),
                    child: SwitchListTile(
                      title: const Text('Enable Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Toggle standard student and freelancer registrations globally', style: TextStyle(fontSize: 12)),
                      value: _registrationEnabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: (val) => setState(() => _registrationEnabled = val),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. AI Preferences
                  const TSectionHeader(title: 'AI Services Preferences'),
                  const SizedBox(height: 10),
                  TCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable Platform AI Features', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: const Text('Toggles STT transcription, summaries, and delay predictions', style: TextStyle(fontSize: 12)),
                          value: _aiEnabled,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _aiEnabled = val),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _aiLimitsCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Daily API Limit Per User',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Limit is required';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Platform Uploads
                  const TSectionHeader(title: 'Upload Configurations'),
                  const SizedBox(height: 10),
                  TCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _maxUploadCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Maximum Upload Size (MB)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Max size is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _allowedTypesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Allowed File Extensions (Comma separated)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'File extensions are required';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Security Policy
                  const TSectionHeader(title: 'Security & Access Control'),
                  const SizedBox(height: 10),
                  TCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _sessionTimeoutCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Session Timeout Duration (Minutes)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Timeout is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _passwordPolicy,
                          decoration: const InputDecoration(
                            labelText: 'Password Complexity Level',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('Low (Min 6 chars)')),
                            DropdownMenuItem(value: 'medium', child: Text('Medium (Min 8 chars, 1 number, 1 capital)')),
                            DropdownMenuItem(value: 'high', child: Text('High (Min 10 chars, special characters required)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _passwordPolicy = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Notifications
                  const TSectionHeader(title: 'Communication Pipelines'),
                  const SizedBox(height: 10),
                  TCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Email Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          value: _emailNotifs,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _emailNotifs = val),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mobile Push Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          value: _pushNotifs,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _pushNotifs = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  _saving
                      ? const Center(child: CircularProgressIndicator())
                      : TButton(
                          label: 'Save Preferences',
                          icon: Icons.save_outlined,
                          onTap: _saveSettings,
                        ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
