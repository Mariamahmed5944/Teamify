import '../../core/network/api_client.dart';
import 'repository_helpers.dart';

class StatsRepository {
  final ApiClient _client;

  StatsRepository(this._client);

  /// GET /api/stats/project/<id>
  Future<Map<String, dynamic>> getProjectStats(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/stats/project/$id');
    return responseMap(response.data);
  }

  /// GET /api/stats/global — admin only
  Future<Map<String, dynamic>> getGlobalStats() async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/stats/global');
    return responseMap(response.data);
  }

  /// GET /api/stats/workload-overview — admin only
  Future<Map<String, dynamic>> getWorkloadOverview() async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/stats/workload-overview');
    return responseMap(response.data);
  }
}
