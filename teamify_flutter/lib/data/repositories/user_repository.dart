import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class UserRepository {
  final ApiClient _client;

  UserRepository(this._client);

  Future<ApiUser?> getProfile() async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/users/profile');
    final data = responseMap(response.data);
    final user = responseMap(data['user']);
    return ApiUser.fromJson(user.isNotEmpty ? user : data);
  }

  Future<ApiUser?> updateProfile(Map<String, dynamic> payload) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/api/users/profile',
      data: payload,
    );
    final data = responseMap(response.data);
    final user = responseMap(data['user']);
    return ApiUser.fromJson(user.isNotEmpty ? user : data);
  }
}
