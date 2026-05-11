import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class TaskRepository {
  final ApiClient _client;

  TaskRepository(this._client);

  Future<List<ApiTask>> listTasks({required String projectId}) async {
    final response = await _client.get<dynamic>(
      '/api/tasks',
      queryParameters: {'project_id': projectId},
    );
    return responseList(response.data, ['tasks', 'data'])
        .map(ApiTask.fromJson)
        .toList();
  }

  Future<ApiTask> createTask(Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/tasks',
      data: payload,
    );
    final data = responseMap(response.data);
    final task = responseMap(data['task']);
    return ApiTask.fromJson(task.isNotEmpty ? task : data);
  }

  Future<ApiTask> updateTask(String id, Map<String, dynamic> payload) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/api/tasks/$id',
      data: payload,
    );
    final data = responseMap(response.data);
    final task = responseMap(data['task']);
    return ApiTask.fromJson(task.isNotEmpty ? task : data);
  }

  Future<void> deleteTask(String id) async {
    await _client.delete<dynamic>('/api/tasks/$id');
  }
}
