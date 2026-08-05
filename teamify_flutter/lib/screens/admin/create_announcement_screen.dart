import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/models/admin_announcement_model.dart';
import '../../data/demo/demo_announcements_data.dart';
import '../../widgets/widgets.dart';

/// Screen 2: Form to Create, Edit, Preview, or Schedule Announcements.
class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _teamCtrl = TextEditingController();

  AdminAnnouncement? _editingAnnouncement;
  AnnouncementAudience _audience = AnnouncementAudience.allUsers;
  bool _inAppNotification = true;
  bool _emailNotification = true;
  bool _isScheduled = false; // false = Send Now, true = Schedule
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _scheduledTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is AdminAnnouncement) {
        setState(() {
          _editingAnnouncement = args;
          _titleCtrl.text = args.title;
          _messageCtrl.text = args.message;
          _audience = args.audience;
          _teamCtrl.text = args.targetTeamName;
          _inAppNotification = args.inAppNotification;
          _emailNotification = args.emailNotification;
          if (args.scheduledAt != null) {
            _isScheduled = true;
            _scheduledDate = args.scheduledAt!;
            _scheduledTime = TimeOfDay.fromDateTime(args.scheduledAt!);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    _teamCtrl.dispose();
    super.dispose();
  }

  DateTime get _fullScheduledDateTime {
    return DateTime(
      _scheduledDate.year,
      _scheduledDate.month,
      _scheduledDate.day,
      _scheduledTime.hour,
      _scheduledTime.minute,
    );
  }

  AdminAnnouncement _buildCurrentAnnouncement({required AnnouncementStatus status}) {
    return AdminAnnouncement(
      id: _editingAnnouncement?.id ??
          'ann_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      message: _messageCtrl.text.trim(),
      audience: _audience,
      targetTeamName: _teamCtrl.text.trim(),
      inAppNotification: _inAppNotification,
      emailNotification: _emailNotification,
      status: status,
      createdAt: _editingAnnouncement?.createdAt ?? DateTime.now(),
      scheduledAt: _isScheduled ? _fullScheduledDateTime : null,
      sentAt: status == AnnouncementStatus.sent ? DateTime.now() : null,
    );
  }

  void _saveDraft() {
    if (!_formKey.currentState!.validate()) return;
    final item = _buildCurrentAnnouncement(status: AnnouncementStatus.draft);
    if (_editingAnnouncement != null) {
      DemoAnnouncementStore.instance.update(item);
    } else {
      DemoAnnouncementStore.instance.add(item);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Announcement draft saved successfully.'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _sendOrSchedule() {
    if (!_formKey.currentState!.validate()) return;
    if (!_inAppNotification && !_emailNotification) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one delivery channel.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final targetStatus =
        _isScheduled ? AnnouncementStatus.scheduled : AnnouncementStatus.sent;
    final item = _buildCurrentAnnouncement(status: targetStatus);

    if (_editingAnnouncement != null) {
      DemoAnnouncementStore.instance.update(item);
    } else {
      DemoAnnouncementStore.instance.add(item);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isScheduled
            ? 'Announcement scheduled successfully.'
            : 'Announcement broadcasted successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _navigateToPreview() {
    if (!_formKey.currentState!.validate()) return;
    final targetStatus =
        _isScheduled ? AnnouncementStatus.scheduled : AnnouncementStatus.draft;
    final item = _buildCurrentAnnouncement(status: targetStatus);
    Navigator.pushNamed(
      context,
      R.adminAnnouncementsPreview,
      arguments: item,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null) {
      setState(() => _scheduledTime = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = _editingAnnouncement != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              size: 18, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Announcement' : 'Create Announcement',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Announcement Details ───────────────────────────────────────
            const TSectionHeader(title: 'Announcement Details'),
            const SizedBox(height: 8),
            TCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Title is required' : null,
                    decoration: const InputDecoration(
                      labelText: 'Announcement Title',
                      hintText: 'e.g. Platform Maintenance Notice: v2.5',
                      prefixIcon: Icon(Icons.title, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _messageCtrl,
                    maxLines: 4,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Message is required' : null,
                    decoration: const InputDecoration(
                      labelText: 'Announcement Message',
                      hintText:
                          'Enter the full announcement text broadcasted to users…',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Audience Selection ─────────────────────────────────────────
            const TSectionHeader(title: 'Target Audience'),
            const SizedBox(height: 8),
            TCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<AnnouncementAudience>(
                    value: _audience,
                    decoration: const InputDecoration(
                      labelText: 'Audience Segment',
                      prefixIcon: Icon(Icons.people_outline, color: AppColors.primary),
                      border: OutlineInputBorder(),
                    ),
                    items: AnnouncementAudience.values.map((aud) {
                      return DropdownMenuItem(
                        value: aud,
                        child: Row(
                          children: [
                            Icon(aud.icon, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(aud.label),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _audience = val);
                    },
                  ),
                  if (_audience == AnnouncementAudience.specificTeam) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _teamCtrl,
                      validator: (v) => _audience == AnnouncementAudience.specificTeam &&
                              (v == null || v.trim().isEmpty)
                          ? 'Team name is required'
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Specific Team Name',
                        hintText: 'e.g. Frontend Core Team',
                        prefixIcon: Icon(Icons.badge_outlined, color: AppColors.primary),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Delivery Channels ─────────────────────────────────────────
            const TSectionHeader(title: 'Delivery Channels'),
            const SizedBox(height: 8),
            TCard(
              child: Column(
                children: [
                  CheckboxListTile(
                    secondary: const Icon(Icons.notifications_active_outlined,
                        color: AppColors.primary),
                    title: const Text('In-App Notification',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Push to user Notification Center & activity feed.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: _inAppNotification,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _inAppNotification = v ?? false),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  CheckboxListTile(
                    secondary:
                        const Icon(Icons.mail_outline, color: AppColors.primary),
                    title: const Text('Email Notification',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Dispatch email broadcast according to user preferences.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: _emailNotification,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _emailNotification = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Scheduling Options ─────────────────────────────────────────
            const TSectionHeader(title: 'Schedule & Dispatch'),
            const SizedBox(height: 8),
            TCard(
              child: Column(
                children: [
                  RadioListTile<bool>(
                    secondary: const Icon(Icons.send_outlined,
                        color: AppColors.success),
                    title: const Text('Send Now',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Broadcast announcement immediately upon submission.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: false,
                    groupValue: _isScheduled,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isScheduled = v ?? false),
                  ),
                  Divider(height: 1, color: theme.dividerColor),
                  RadioListTile<bool>(
                    secondary: const Icon(Icons.schedule_outlined,
                        color: AppColors.warning),
                    title: const Text('Schedule for Later',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Queue announcement for automatic dispatch at a future time.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    value: true,
                    groupValue: _isScheduled,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _isScheduled = v ?? true),
                  ),
                  if (_isScheduled) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: Text(
                                '${_scheduledDate.day}/${_scheduledDate.month}/${_scheduledDate.year}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickTime,
                              icon: const Icon(Icons.access_time, size: 18),
                              label: Text(
                                '${_scheduledTime.hour.toString().padLeft(2, '0')}:${_scheduledTime.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Form Action Buttons Bar ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: TButton(
                    label: 'Preview',
                    outline: true,
                    onTap: _navigateToPreview,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TButton(
                    label: 'Save Draft',
                    outline: true,
                    onTap: _saveDraft,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TButton(
                    label: _isScheduled ? 'Schedule' : 'Send',
                    onTap: _sendOrSchedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
