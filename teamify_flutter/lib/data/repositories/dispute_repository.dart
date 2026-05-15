import '../../core/network/api_client.dart';
import 'repository_helpers.dart';

class DisputeRepository {
  final ApiClient _client;

  DisputeRepository(this._client);

  /// POST /api/disputes
  /// Payload keys: title, description, project_id
  Future<void> fileDispute(Map<String, dynamic> payload) async {
    await _client.post<dynamic>('/api/disputes', data: payload);
  }

  /// GET /api/disputes/my — current user's disputes
  Future<List<Map<String, dynamic>>> getMyDisputes() async {
    final response = await _client.get<dynamic>('/api/disputes/my');
    return responseList(response.data, ['disputes', 'data'])
        .cast<Map<String, dynamic>>();
  }

  /// GET /api/disputes — admin: all disputes
  Future<List<Map<String, dynamic>>> getAllDisputes() async {
    final response = await _client.get<dynamic>('/api/disputes');
    return responseList(response.data, ['disputes', 'data'])
        .cast<Map<String, dynamic>>();
  }

  /// GET /api/disputes/<id> — admin: single dispute detail
  Future<Map<String, dynamic>> getDispute(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/disputes/$id');
    return responseMap(response.data);
  }

  /// PATCH /api/disputes/<id>/status — admin: update dispute status
  Future<void> updateDisputeStatus(String id, String status) async {
    await _client.patch<dynamic>(
      '/api/disputes/$id/status',
      data: {'status': status},
    );
  }
}
