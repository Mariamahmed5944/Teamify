import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart' as ui;
import '../models/models.dart';
import 'repository_helpers.dart';

class AdminRepository {
  final ApiClient _client;

  AdminRepository(this._client);

  /// List all uploaded files (admin view, via /api/files).
  Future<List<ApiFile>> listFiles() async {
    final response = await _client.get<dynamic>('/api/files');
    return responseList(response.data, ['files', 'data'])
        .map(ApiFile.fromJson)
        .toList();
  }

  Future<List<ApiUser>> listUsers() async {
    final response = await _client.get<dynamic>('/admin/users');
    return responseList(response.data, ['items', 'users', 'data'])
        .map(ApiUser.fromJson)
        .toList();
  }

  Future<List<ApiUser>> listPendingUsers() async {
    final response = await _client.get<dynamic>('/admin/users/pending');
    return responseList(
            response.data, ['items', 'users', 'pending_users', 'data'])
        .map(ApiUser.fromJson)
        .toList();
  }

  Future<List<ui.LoginLog>> listLoginLogs() async {
    final response = await _client.get<dynamic>('/admin/logs');
    return responseList(response.data, ['items', 'logs', 'data']).map((json) {
      final timestamp = asString(json['timestamp'] ?? json['created_at']);
      final user = responseMap(json['user']);
      final userName = asString(
        json['user_name'] ??
            json['username'] ??
            user['display_name'] ??
            user['full_name'] ??
            user['email'],
        'Unknown user',
      );
      final status = asString(json['status']).toLowerCase() == 'success'
          ? 'Success'
          : 'Failed';
      return ui.LoginLog(
        id: asString(json['id']),
        userName: userName,
        status: status,
        time: _formatTime(timestamp),
        date: _formatDate(timestamp),
        device: asString(json['device_info'] ?? json['device'], 'Unknown'),
        ip: asString(json['ip_address'] ?? json['ip'], 'Unknown'),
      );
    }).toList();
  }

  Future<List<ui.SecurityAlert>> listAlerts() async {
    final response = await _client.get<dynamic>('/admin/alerts');
    return responseList(response.data, ['items', 'alerts', 'data']).map((json) {
      final resolved = asBool(json['resolved']);
      final type = asString(json['type'], 'Security Alert');
      final description = asString(json['description']);
      final timestamp = asString(json['timestamp'] ?? json['created_at']);
      return ui.SecurityAlert(
        id: asString(json['id']),
        title: _titleFromType(type),
        user: asString(json['user_name'] ?? json['user_id'], 'System'),
        description: description.isNotEmpty ? description : type,
        risk: _riskFromType(type, description),
        status: resolved ? 'Resolved' : 'New',
        time: _formatDateTime(timestamp),
      );
    }).toList();
  }

  Future<void> approveUser(String id) async {
    await _client.patch<dynamic>('/admin/users/$id/approve');
  }

  Future<void> rejectUser(String id, {String? reason}) async {
    await _client.patch<dynamic>(
      '/admin/users/$id/reject',
      data: reason == null ? null : {'reason': reason},
    );
  }

  // ── User Detail & Management ─────────────────────────────────────────────

  /// GET /admin/users/<id>
  Future<ApiUser> getUserDetail(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/admin/users/$id');
    final data = responseMap(response.data);
    final user = responseMap(data['user']);
    return ApiUser.fromJson(user.isNotEmpty ? user : data);
  }

  /// PUT /admin/users/<id>
  Future<ApiUser> updateUserDetails(
      String id, Map<String, dynamic> payload) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/admin/users/$id',
      data: payload,
    );
    final data = responseMap(response.data);
    final user = responseMap(data['user']);
    return ApiUser.fromJson(user.isNotEmpty ? user : data);
  }

  /// DELETE /admin/users/<id>
  Future<void> deleteUser(String id) async {
    await _client.delete<dynamic>('/admin/users/$id');
  }

  /// PATCH /admin/users/<id>/lock
  Future<void> lockUser(String id) async {
    await _client.patch<dynamic>('/admin/users/$id/lock');
  }

  /// PATCH /admin/users/<id>/unlock
  Future<void> unlockUser(String id) async {
    await _client.patch<dynamic>('/admin/users/$id/unlock');
  }

  // ── Project Management ───────────────────────────────────────────────────

  /// GET /admin/projects
  Future<List<ApiProject>> listAllProjects() async {
    final response = await _client.get<dynamic>('/admin/projects');
    return responseList(response.data, ['projects', 'data'])
        .map(ApiProject.fromJson)
        .toList();
  }

  /// DELETE /admin/projects/<id>
  Future<void> deleteProjectAdmin(String id) async {
    await _client.delete<dynamic>('/admin/projects/$id');
  }

  // ── Reports & Analytics ──────────────────────────────────────────────────

  /// GET /admin/reports/summary
  Future<Map<String, dynamic>> getReportSummary() async {
    final response =
        await _client.get<Map<String, dynamic>>('/admin/reports/summary');
    return responseMap(response.data);
  }

  /// GET /admin/analytics/overview
  Future<Map<String, dynamic>> getAnalyticsOverview() async {
    final response =
        await _client.get<Map<String, dynamic>>('/admin/analytics/overview');
    return responseMap(response.data);
  }

  /// GET /admin/analytics/users/growth
  Future<List<Map<String, dynamic>>> getUserGrowthData() async {
    final response =
        await _client.get<dynamic>('/admin/analytics/users/growth');
    return responseList(response.data, ['data', 'growth'])
        .cast<Map<String, dynamic>>();
  }

  // ── Activity & Audit Logs ────────────────────────────────────────────────

  /// GET /admin/activity
  Future<List<Map<String, dynamic>>> getAdminActivity() async {
    final response = await _client.get<dynamic>('/admin/activity');
    return responseList(response.data, ['items', 'activity', 'data'])
        .cast<Map<String, dynamic>>();
  }

  /// GET /admin/audit-logs
  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    final response = await _client.get<dynamic>('/admin/audit-logs');
    return responseList(response.data, ['logs', 'items', 'data'])
        .cast<Map<String, dynamic>>();
  }

  // ── Alert Management ─────────────────────────────────────────────────────

  /// PATCH /admin/alerts/<id>/resolve
  Future<void> resolveAlert(String id) async {
    await _client.patch<dynamic>('/admin/alerts/$id/resolve');
  }

  // ── Exports ──────────────────────────────────────────────────────────────

  /// GET /admin/export/users — returns CSV bytes
  Future<List<int>> exportUsersCsv() async {
    final response = await _client.get<List<int>>(
      '/admin/export/users',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// GET /admin/export/projects — returns CSV bytes
  Future<List<int>> exportProjectsCsv() async {
    final response = await _client.get<List<int>>(
      '/admin/export/projects',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  static String _titleFromType(String type) {
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String _riskFromType(String type, String description) {
    final value = '$type $description'.toLowerCase();
    if (value.contains('brute') ||
        value.contains('failed') ||
        value.contains('critical')) {
      return 'HIGH RISK';
    }
    if (value.contains('anomaly') || value.contains('suspicious')) {
      return 'MEDIUM RISK';
    }
    return 'LOW RISK';
  }

  static String _formatDateTime(String value) =>
      value.isEmpty ? 'Unknown' : value.replaceFirst('T', ' ').split('.').first;

  static String _formatDate(String value) =>
      _formatDateTime(value).split(' ').first;

  static String _formatTime(String value) {
    final parts = _formatDateTime(value).split(' ');
    return parts.length > 1 ? parts[1] : 'Unknown';
  }
}
