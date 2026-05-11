import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class AdminRepository {
  final ApiClient _client;

  AdminRepository(this._client);

  Future<List<ApiUser>> listUsers() async {
    final response = await _client.get<dynamic>('/admin/users');
    return responseList(response.data, ['users', 'data'])
        .map(ApiUser.fromJson)
        .toList();
  }

  Future<List<ApiUser>> listPendingUsers() async {
    final response = await _client.get<dynamic>('/admin/users/pending');
    return responseList(response.data, ['users', 'pending_users', 'data'])
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
}
