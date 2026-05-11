import '../../core/network/api_client.dart';
import '../../models/models.dart' as ui;
import '../models/models.dart';
import 'repository_helpers.dart';

class AdminRepository {
  final ApiClient _client;

  AdminRepository(this._client);

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
