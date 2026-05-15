import '../../core/network/api_client.dart';
import 'repository_helpers.dart';

class LogRepository {
  final ApiClient _client;

  LogRepository(this._client);

  /// GET /api/logs/my — current user's own activity log
  Future<List<Map<String, dynamic>>> getMyActivity() async {
    final response = await _client.get<dynamic>('/api/logs/my');
    return responseList(response.data, ['logs', 'data'])
        .cast<Map<String, dynamic>>();
  }

  /// GET /api/logs/all — admin only: full system audit log
  Future<List<Map<String, dynamic>>> getAllLogs() async {
    final response = await _client.get<dynamic>('/api/logs/all');
    return responseList(response.data, ['logs', 'data'])
        .cast<Map<String, dynamic>>();
  }
}
