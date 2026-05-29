import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class UserRepository {
  final ApiClient _client;

  UserRepository(this._client);

  // GET /api/users/profile
  Future<ApiUser?> getProfile() async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/users/profile');
    final data = responseMap(response.data);
    final user = responseMap(data['user']);
    return ApiUser.fromJson(user.isNotEmpty ? user : data);
  }

  // PUT /api/users/profile
  Future<ApiUser?> updateProfile(Map<String, dynamic> payload) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/users/profile',
      data: payload,
    );
    final data = responseMap(response.data);
    final user = responseMap(data['user']);
    return ApiUser.fromJson(user.isNotEmpty ? user : data);
  }

  // GET /api/users/admin-dashboard (admin only)
  Future<Map<String, dynamic>> getAdminDashboard() async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/users/admin-dashboard');
    return responseMap(response.data);
  }

  // GET /api/users/<id>/profile
  Future<ApiUser?> getPublicProfile(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/users/$id/profile');
    final data = responseMap(response.data);
    final profile = responseMap(data['profile']);
    if (profile.isNotEmpty) return ApiUser.fromJson(profile);
    final user = responseMap(data['user']);
    return ApiUser.fromJson(user.isNotEmpty ? user : data);
  }

  // GET /api/users/<id>/stats
  Future<Map<String, dynamic>> getUserStats(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/users/$id/stats');
    return responseMap(response.data);
  }
}
