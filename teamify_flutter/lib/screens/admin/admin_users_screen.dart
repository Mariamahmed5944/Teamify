import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/network/api_result.dart';
import '../../services/app_services.dart';
import '../../widgets/widgets.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _filterType = ''; // '', 'freelancer', 'student'
  String _filterStatus = ''; // '', 'active', 'locked', 'pending'
  int _currentPage = 1;
  int _totalPages = 1;
  bool _loading = false;
  List<dynamic> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim();
        _currentPage = 1;
      });
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final res = await context.read<AppServices>().admin.listUsers(
        search: _searchQuery,
        status: _filterStatus,
        type: _filterType,
        page: _currentPage,
      ).unwrap();

      setState(() {
        _users = res['items'] as List? ?? [];
        _totalPages = res['pages'] ?? 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String userId, String action, {String reason = ''}) async {
    try {
      await context.read<AppServices>().admin.updateUserStatus(userId, action, reason: reason).unwrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User account marked as $action successfully'), backgroundColor: AppColors.success),
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _changeRole(String userId, String role) async {
    try {
      await context.read<AppServices>().admin.changeUserRole(userId, role).unwrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User role updated successfully'), backgroundColor: AppColors.success),
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _resetPassword(String userId, String newPassword) async {
    try {
      await context.read<AppServices>().admin.resetUserPassword(userId, newPassword).unwrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await context.read<AppServices>().admin.deleteUser(userId).unwrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User permanently deleted'), backgroundColor: AppColors.success),
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User Management', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filter Box
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Search by name, email, username...',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Filters Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButton<String>(
                          value: _filterType,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All Types', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'freelancer', child: Text('Freelancers', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'student', child: Text('Students', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _filterType = val ?? '';
                              _currentPage = 1;
                            });
                            _loadUsers();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: DropdownButton<String>(
                          value: _filterStatus,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: '', child: Text('All Statuses', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'active', child: Text('Active Only', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'locked', child: Text('Locked Only', style: TextStyle(fontSize: 12))),
                            DropdownMenuItem(value: 'pending', child: Text('Pending Approval', style: TextStyle(fontSize: 12))),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _filterStatus = val ?? '';
                              _currentPage = 1;
                            });
                            _loadUsers();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // User Table/List View
          Expanded(
            child: _loading && _users.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _users.isEmpty
                    ? const Center(child: Text('No users found matching filters', style: TextStyle(color: AppColors.textSecondary)))
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _users.length,
                          itemBuilder: (context, index) {
                            final u = _users[index] as Map<String, dynamic>;
                            final String initials = (u['display_name'] ?? 'U').toString().substring(0, 1).toUpperCase();
                            final String status = u['status'] ?? 'active';
                            final String role = u['role'] ?? 'member';

                            return TCard(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        TAvatar(initials: initials, radius: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(u['full_name'] ?? u['display_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                                              Text(u['email'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            TChip(
                                              label: status.toUpperCase(),
                                              bg: status == 'active'
                                                  ? AppColors.success.withValues(alpha: 0.1)
                                                  : status == 'locked'
                                                      ? AppColors.error.withValues(alpha: 0.1)
                                                      : AppColors.warning.withValues(alpha: 0.1),
                                              textColor: status == 'active'
                                                  ? AppColors.success
                                                  : status == 'locked'
                                                      ? AppColors.error
                                                      : AppColors.warning,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(u['user_type']?.toUpperCase() ?? 'MEMBER', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    // Row of Actions
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        if (status == 'pending')
                                          IconButton(
                                            icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                                            onPressed: () => _updateStatus(u['id'].toString(), 'approve'),
                                            tooltip: 'Approve User',
                                          ),
                                        if (status == 'pending')
                                          IconButton(
                                            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                                            onPressed: () => _updateStatus(u['id'].toString(), 'reject'),
                                            tooltip: 'Reject User',
                                          ),
                                        if (status != 'pending' && status != 'locked')
                                          IconButton(
                                            icon: const Icon(Icons.lock_outline, color: AppColors.warning),
                                            onPressed: () => _updateStatus(u['id'].toString(), 'lock'),
                                            tooltip: 'Lock Account',
                                          ),
                                        if (status == 'locked')
                                          IconButton(
                                            icon: const Icon(Icons.lock_open, color: AppColors.success),
                                            onPressed: () => _updateStatus(u['id'].toString(), 'unlock'),
                                            tooltip: 'Unlock Account',
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.password_outlined, color: AppColors.primary),
                                          onPressed: () => _showResetPasswordDialog(u['id'].toString()),
                                          tooltip: 'Reset Password',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_attributes_outlined, color: AppColors.accent),
                                          onPressed: () => _showRoleDialog(u['id'].toString(), role),
                                          tooltip: 'Change Role',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                          onPressed: () => _showDeleteConfirmation(u['id'].toString()),
                                          tooltip: 'Delete Account',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Pagination Bar
          if (_totalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() => _currentPage--);
                            _loadUsers();
                          }
                        : null,
                  ),
                  Text('Page $_currentPage of $_totalPages', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages
                        ? () {
                            setState(() => _currentPage++);
                            _loadUsers();
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showRoleDialog(String userId, String currentRole) {
    showDialog(
      context: context,
      builder: (context) {
        String selRole = currentRole;
        return AlertDialog(
          title: const Text('Change User Role'),
          content: DropdownButtonFormField<String>(
            initialValue: currentRole,
            items: const [
              DropdownMenuItem(value: 'member', child: Text('Member')),
              DropdownMenuItem(value: 'admin', child: Text('Administrator')),
              DropdownMenuItem(value: 'guest', child: Text('Guest')),
            ],
            onChanged: (val) {
              if (val != null) selRole = val;
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _changeRole(userId, selRole);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showResetPasswordDialog(String userId) {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Password'),
          content: TextField(
            controller: passwordCtrl,
            decoration: const InputDecoration(hintText: 'Enter new password (min 8 chars)'),
            obscureText: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final pw = passwordCtrl.text.trim();
                if (pw.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password too short!'), backgroundColor: AppColors.error),
                  );
                  return;
                }
                Navigator.pop(context);
                _resetPassword(userId, pw);
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation(String userId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you absolutely sure you want to permanently delete this user account? This action is irreversible.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(context);
                _deleteUser(userId);
              },
              child: const Text('Delete permanently'),
            ),
          ],
        );
      },
    );
  }
}
