import '../../core/network/api_client.dart';
import 'repository_helpers.dart';

class AdminRepository {
  final ApiClient _client;

  AdminRepository(this._client);

  // ── 1. Admin Dashboard ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/dashboard');
    return responseMap(response.data);
  }

  // ── 2. User Management ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> listUsers({
    String search = '',
    String status = '',
    String type = '',
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/users',
      queryParameters: {
        'search': search,
        'status': status,
        'user_type': type,
        'page': page,
        'per_page': perPage,
      },
    );
    return responseMap(response.data);
  }

  Future<void> updateUserStatus(String id, String action, {String reason = ''}) async {
    await _client.patch<dynamic>(
      '/admin/users/$id/status',
      data: {'action': action, 'reason': reason},
    );
  }

  Future<void> changeUserRole(String id, String role) async {
    await _client.patch<dynamic>(
      '/admin/users/$id/role',
      data: {'role': role},
    );
  }

  Future<void> resetUserPassword(String id, String password) async {
    await _client.patch<dynamic>(
      '/admin/users/$id/reset-password',
      data: {'password': password},
    );
  }

  Future<void> deleteUser(String id) async {
    await _client.delete<dynamic>('/admin/users/$id');
  }

  Future<Map<String, dynamic>> createUser({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/admin/users',
      data: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role,
      },
    );
    return responseMap(response.data);
  }

  // ── 3. Project Management ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> listProjects({
    String search = '',
    String status = '',
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/projects',
      queryParameters: {
        'search': search,
        'status': status,
        'page': page,
        'per_page': perPage,
      },
    );
    return responseMap(response.data);
  }

  Future<void> reassignProject(String projectId, String newOwnerId) async {
    await _client.patch<dynamic>(
      '/admin/projects/$projectId/reassign',
      data: {'owner_id': int.parse(newOwnerId)},
    );
  }

  Future<void> deleteProject(String projectId) async {
    await _client.delete<dynamic>('/admin/projects/$projectId');
  }

  // ── 4. Task Management ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> listTasks({
    String search = '',
    int? projectId,
    int? assignedTo,
    String priority = '',
    String status = '',
    int page = 1,
    int perPage = 20,
  }) async {
    final Map<String, dynamic> qParams = {
      'search': search,
      'priority': priority,
      'status': status,
      'page': page,
      'per_page': perPage,
    };
    if (projectId != null) qParams['project_id'] = projectId;
    if (assignedTo != null) qParams['assigned_to'] = assignedTo;

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/tasks',
      queryParameters: qParams,
    );
    return responseMap(response.data);
  }

  Future<void> updateTask(String taskId, {String? status, String? assignedTo}) async {
    final Map<String, dynamic> data = {};
    if (status != null) data['status'] = status;
    if (assignedTo != null) data['assigned_to'] = int.tryParse(assignedTo);

    await _client.patch<dynamic>(
      '/admin/tasks/$taskId',
      data: data,
    );
  }

  Future<void> deleteTask(String taskId) async {
    await _client.delete<dynamic>('/admin/tasks/$taskId');
  }

  // ── 5. AI Monitor ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAiMetrics() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/ai/metrics');
    return responseMap(response.data);
  }

  // ── 6. Disputes ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> listDisputes({
    String status = '',
    String category = '',
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/disputes',
      queryParameters: {
        'status': status,
        'category': category,
        'page': page,
        'per_page': perPage,
      },
    );
    return responseMap(response.data);
  }

  Future<void> resolveDispute(String disputeId, String action, String resolution) async {
    await _client.patch<dynamic>(
      '/admin/disputes/$disputeId/resolve',
      data: {'action': action, 'resolution': resolution},
    );
  }

  // ── 7. Notifications Center ─────────────────────────────────────────────────
  Future<void> broadcastNotification(String target, String title, String body, {String? userId}) async {
    final Map<String, dynamic> data = {
      'target': target,
      'title': title,
      'body': body,
    };
    if (userId != null) data['user_id'] = int.tryParse(userId);

    await _client.post<dynamic>(
      '/admin/notifications',
      data: data,
    );
  }

  // ── 8. File Management ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> listFiles({
    String search = '',
    int? ownerId,
    int page = 1,
    int perPage = 20,
  }) async {
    final Map<String, dynamic> qParams = {
      'search': search,
      'page': page,
      'per_page': perPage,
    };
    if (ownerId != null) qParams['owner_id'] = ownerId;

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/files',
      queryParameters: qParams,
    );
    return responseMap(response.data);
  }

  Future<void> deleteFile(String fileId) async {
    await _client.delete<dynamic>('/admin/files/$fileId');
  }

  // ── 9. Activity Logs ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> listLogs({
    String action = '',
    String entity = '',
    String search = '',
    int? userId,
    int page = 1,
    int perPage = 50,
  }) async {
    final Map<String, dynamic> qParams = {
      'action': action,
      'entity': entity,
      'search': search,
      'page': page,
      'per_page': perPage,
    };
    if (userId != null) qParams['user_id'] = userId;

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/logs',
      queryParameters: qParams,
    );
    return responseMap(response.data);
  }

  Future<void> resolveAlert(String id) async {
    await _client.patch<dynamic>('/admin/alerts/$id/resolve');
  }

  Future<Map<String, dynamic>> listAuditLogs({
    String action = '',
    String severity = '',
    String search = '',
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/audit-logs',
      queryParameters: {
        'action': action,
        'severity': severity,
        'search': search,
        'page': page,
        'per_page': perPage,
      },
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> getDisputeDetail(String id) async {
    final response = await _client.get<Map<String, dynamic>>('/admin/disputes/$id');
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> getAnalyticsTimeSeries({String metric = 'users', int days = 30}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/analytics/time-series',
      queryParameters: {'metric': metric, 'days': days},
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> listBroadcastHistory({int page = 1, int perPage = 20}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/notifications/history',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> listRolePermissions() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/roles');
    return responseMap(response.data);
  }

  Future<void> updateRolePermissions(String role, Map<String, dynamic> permissions) async {
    await _client.put<dynamic>('/admin/roles/$role', data: {'permissions': permissions});
  }

  Future<Map<String, dynamic>> getRatingsLeaderboard({int page = 1}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/ratings/leaderboard',
      queryParameters: {'page': page},
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> getFeedbackLeaderboard({int page = 1}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/admin/feedback/leaderboard',
      queryParameters: {'page': page},
    );
    return responseMap(response.data);
  }

  Future<String> exportAnalytics(String type) async {
    final response = await _client.get<dynamic>(
      '/admin/analytics/export',
      queryParameters: {'type': type, 'format': 'csv'},
    );
    final data = response.data;
    if (data is String) return data;
    return data?.toString() ?? '';
  }

  // ── 10. Security Center ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSecuritySummary() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/security');
    return responseMap(response.data);
  }

  Future<void> revokeSessions(String userId) async {
    await _client.post<dynamic>('/admin/security/revoke-session/$userId');
  }

  Future<Map<String, dynamic>> listLoginLogs({
    String status = '',
    String ip = '',
    int? userId,
    int page = 1,
    int perPage = 100,
  }) async {
    final Map<String, dynamic> qParams = {
      'page': page,
      'per_page': perPage,
    };
    if (status.isNotEmpty) qParams['status'] = status;
    if (ip.isNotEmpty) qParams['ip'] = ip;
    if (userId != null) qParams['user_id'] = userId;

    final response = await _client.get<Map<String, dynamic>>(
      '/admin/login-logs',
      queryParameters: qParams,
    );
    return responseMap(response.data);
  }

  // ── 11. Analytics ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAnalyticsOverview() async {
    final response =
        await _client.get<Map<String, dynamic>>('/admin/analytics/overview');
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> getReportSummary() async {
    final response =
        await _client.get<Map<String, dynamic>>('/admin/reports/summary');
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> getAnalyticsDetails() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/analytics');
    return responseMap(response.data);
  }

  // ── 12. Settings ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSettings() async {
    final response = await _client.get<Map<String, dynamic>>('/admin/settings');
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> settings) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/admin/settings',
      data: settings,
    );
    return responseMap(response.data);
  }
}
