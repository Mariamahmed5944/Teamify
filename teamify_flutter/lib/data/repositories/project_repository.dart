import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class ProjectRepository {
  final ApiClient _client;

  ProjectRepository(this._client);

  // GET /api/projects
  Future<List<ApiProject>> listProjects() async {
    final response = await _client.get<dynamic>('/api/projects');
    return responseList(response.data, ['projects', 'data'])
        .map(ApiProject.fromJson)
        .toList();
  }

  // POST /api/projects
  Future<ApiProject> createProject(Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/projects',
      data: payload,
    );
    final data = responseMap(response.data);
    final project = responseMap(data['project']);
    return ApiProject.fromJson(project.isNotEmpty ? project : data);
  }

  // GET /api/projects/<id>
  Future<ApiProject> getProject(String id) async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/projects/$id');
    final data = responseMap(response.data);
    final project = responseMap(data['project']);
    return ApiProject.fromJson(project.isNotEmpty ? project : data);
  }

  // PUT /api/projects/<id>
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

  // DELETE /api/projects/<id>
  Future<void> deleteProject(String id) async {
    await _client.delete<dynamic>('/api/projects/$id');
  }

  // GET /api/projects/completed
  Future<List<ApiProject>> listCompletedProjects(
      {int page = 1, String search = ''}) async {
    final response = await _client.get<dynamic>(
      '/api/projects/completed',
      queryParameters: {
        'page': page,
        if (search.isNotEmpty) 'search': search,
      },
    );
    return responseList(response.data, ['projects', 'data'])
        .map(ApiProject.fromJson)
        .toList();
  }

  // POST /api/projects/<id>/complete
  Future<ApiProject> completeProject(String id) async {
    final response =
        await _client.post<Map<String, dynamic>>('/api/projects/$id/complete');
    final data = responseMap(response.data);
    final project = responseMap(data['project']);
    return ApiProject.fromJson(project.isNotEmpty ? project : data);
  }

  // POST /api/projects/<id>/reopen
  Future<ApiProject> reopenProject(String id) async {
    final response =
        await _client.post<Map<String, dynamic>>('/api/projects/$id/reopen');
    final data = responseMap(response.data);
    final project = responseMap(data['project']);
    return ApiProject.fromJson(project.isNotEmpty ? project : data);
  }

  // GET /api/projects/<id>/members
  Future<List<ApiUser>> listProjectMembers(String id) async {
    final response =
        await _client.get<dynamic>('/api/projects/$id/members');
    return responseList(response.data, ['members', 'data'])
        .map(ApiUser.fromJson)
        .toList();
  }

  // POST /api/projects/<id>/members
  Future<void> addProjectMember(
      {required String projectId, required String userId}) async {
    await _client.post<dynamic>(
      '/api/projects/$projectId/members',
      data: {'user_id': userId},
    );
  }

  // DELETE /api/projects/<id>/members/<uid>
  Future<void> removeProjectMember(
      {required String projectId, required String userId}) async {
    await _client
        .delete<dynamic>('/api/projects/$projectId/members/$userId');
  }
}
