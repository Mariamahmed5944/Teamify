import '../../core/network/api_client.dart';
import '../../models/models.dart';
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
    return responseList(response.data, ['items', 'users', 'pending_users', 'data'])
        .map(ApiUser.fromJson)
        .toList();
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

  Future<List<LoginLog>> listLoginLogs({String filter = 'All'}) async {
    final qp = <String, dynamic>{};
    if (filter == 'Success') qp['status'] = 'success';
    if (filter == 'Failed') qp['status'] = 'fail';
    final response = await _client.get<dynamic>(
      '/admin/logs',
      queryParameters: qp.isEmpty ? null : qp,
    );
    final raw = responseList(response.data, ['items']);
    return raw.map(_mapLoginLog).toList();
  }

  Future<List<SecurityAlert>> listAlerts() async {
    final response = await _client.get<dynamic>('/admin/alerts');
    final raw = responseList(response.data, ['items']);
    return raw.map(_mapSecurityAlert).toList();
  }
}

LoginLog _mapLoginLog(Map<String, dynamic> m) {
  final ts = asString(m['timestamp']);
  var time = ts;
  var date = '';
  if (ts.contains('T')) {
    final parts = ts.split('T');
    date = parts[0];
    final rest = parts[1];
    time = rest.length >= 5 ? rest.substring(0, 5) : rest;
  } else if (ts.length > 5) {
    time = ts;
  }
  final uid = m['user_id'];
  return LoginLog(
    id: asString(m['id']),
    userName: uid == null ? 'Unknown' : 'User #$uid',
    status: asString(m['status']) == 'success' ? 'Success' : 'Failed',
    time: time.isNotEmpty ? time : '—',
    date: date.isNotEmpty ? date : '—',
    device: asString(m['device_info']).isEmpty ? 'Unknown' : asString(m['device_info']),
    ip: asString(m['ip_address']),
  );
}

SecurityAlert _mapSecurityAlert(Map<String, dynamic> m) {
  final typ = asString(m['type'], 'Security event');
  final title = typ.replaceAll('_', ' ');
  final resolved = asBool(m['resolved']);
  final desc = asString(m['description']);
  final ts = asString(m['timestamp']);
  final lt = typ.toLowerCase();
  final risk = lt.contains('brute') || lt.contains('force') || lt.contains('critical')
      ? 'HIGH RISK'
      : lt.contains('warn') ? 'LOW RISK' : 'MEDIUM RISK';
  return SecurityAlert(
    id: asString(m['id']),
    title: title.isNotEmpty ? title : 'Alert',
    user: resolved ? 'Resolved' : 'System',
    description: desc.isEmpty ? 'No description' : desc,
    risk: risk,
    status: resolved ? 'Resolved' : 'New',
    time: ts.length > 19 ? ts.substring(0, 19) : (ts.isNotEmpty ? ts : '—'),
  );
}
