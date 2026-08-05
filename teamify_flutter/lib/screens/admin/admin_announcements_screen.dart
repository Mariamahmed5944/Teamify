import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/models/admin_announcement_model.dart';
import '../../data/demo/demo_announcements_data.dart';
import '../../widgets/admin_announcement_widgets.dart';

/// Screen 1: Manage Admin Announcements with Search, Filters, and Actions.
class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState extends State<AdminAnnouncementsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final store = DemoAnnouncementStore.instance;

  String _filter = 'all'; // 'all', 'scheduled', 'draft', 'sent', 'cancelled'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    store.addListener(_onStoreUpdated);
  }

  @override
  void dispose() {
    store.removeListener(_onStoreUpdated);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStoreUpdated() {
    if (mounted) setState(() {});
  }

  List<AdminAnnouncement> get _filteredItems {
    final query = _searchQuery.toLowerCase().trim();
    return store.items.where((item) {
      // Filter status match
      if (_filter == 'scheduled' && item.status != AnnouncementStatus.scheduled) {
        return false;
      }
      if (_filter == 'draft' && item.status != AnnouncementStatus.draft) {
        return false;
      }
      if (_filter == 'sent' && item.status != AnnouncementStatus.sent) {
        return false;
      }
      if (_filter == 'cancelled' &&
          item.status != AnnouncementStatus.cancelled) {
        return false;
      }

      // Search query match
      if (query.isNotEmpty) {
        final titleMatch = item.title.toLowerCase().contains(query);
        final bodyMatch = item.message.toLowerCase().contains(query);
        final audienceMatch = item.audience.label.toLowerCase().contains(query);
        return titleMatch || bodyMatch || audienceMatch;
      }

      return true;
    }).toList();
  }

  void _handleAction(String action, AdminAnnouncement item) {
    switch (action) {
      case 'preview':
        Navigator.pushNamed(
          context,
          R.adminAnnouncementsPreview,
          arguments: item,
        );
        break;
      case 'edit':
        Navigator.pushNamed(
          context,
          R.adminAnnouncementsCreate,
          arguments: item,
        );
        break;
      case 'duplicate':
        store.duplicate(item);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement duplicated as a new draft.'),
            backgroundColor: AppColors.primary,
          ),
        );
        break;
      case 'send_now':
        store.markAsSent(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement status marked as Sent.'),
            backgroundColor: AppColors.success,
          ),
        );
        break;
      case 'cancel':
        store.cancelScheduled(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheduled announcement cancelled.'),
            backgroundColor: AppColors.error,
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmDialog(item);
        break;
    }
  }

  void _showDeleteConfirmDialog(AdminAnnouncement item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text(
            'Are you sure you want to delete "${item.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              store.delete(item.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Announcement deleted.'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _filteredItems;

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
          'Admin Announcements',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, R.adminAnnouncementsCreate);
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Announcement',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                AnnouncementSearchBar(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  onClear: () => setState(() {
                    _searchCtrl.clear();
                    _searchQuery = '';
                  }),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filterChip('all', 'All (${store.items.length})'),
                      const SizedBox(width: 8),
                      _filterChip(
                        'scheduled',
                        'Scheduled (${store.items.where((i) => i.status == AnnouncementStatus.scheduled).length})',
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        'draft',
                        'Draft (${store.items.where((i) => i.status == AnnouncementStatus.draft).length})',
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        'sent',
                        'Sent (${store.items.where((i) => i.status == AnnouncementStatus.sent).length})',
                      ),
                      const SizedBox(width: 8),
                      _filterChip(
                        'cancelled',
                        'Cancelled (${store.items.where((i) => i.status == AnnouncementStatus.cancelled).length})',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Announcements List View
          Expanded(
            child: visible.isEmpty
                ? AnnouncementEmptyState(
                    onCreatePressed: () {
                      Navigator.pushNamed(context, R.adminAnnouncementsCreate);
                    },
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: visible.length,
                    itemBuilder: (ctx, i) {
                      final item = visible[i];
                      return AnnouncementCard(
                        announcement: item,
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            R.adminAnnouncementsPreview,
                            arguments: item,
                          );
                        },
                        onActionSelected: (act) => _handleAction(act, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final sel = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
