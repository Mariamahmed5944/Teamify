import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class ProjectRepository {
  final ApiClient _client;

  ProjectRepository(this._client);

  Future<List<ApiProject>> listProjects() async {
    final response = await _client.get<dynamic>('/api/projects');
    return responseList(response.data, ['projects', 'data'])
        .map(ApiProject.fromJson)
        .toList();
  }

  Future<ApiProject> getProject(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/projects/$id');
    final data = responseMap(response.data);
    final project = responseMap(data['project']);
    return ApiProject.fromJson(project.isNotEmpty ? project : data);
  }

  Future<ApiProject> createProject(Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/projects',
      data: payload,
    );
    final data = responseMap(response.data);
    final project = responseMap(data['project']);
    return ApiProject.fromJson(project.isNotEmpty ? project : data);
  }

  Future<ApiProject> updateProject(
      String id, Map<String, dynamic> payload) async {
    final response = await _client.patch<Map<String, dynamic>>(
      '/api/projects/$id',
      data: payload,
    );
    final data = responseMap(response.data);
    final project = responseMap(data['project']);
    return ApiProject.fromJson(project.isNotEmpty ? project : data);
  }

  Future<void> deleteProject(String id) async {
    await _client.delete<dynamic>('/api/projects/$id');
  }
}
