import '../../core/network/api_client.dart';
import 'repository_helpers.dart';

class AIRepository {
  final ApiClient _client;

  AIRepository(this._client);

  Future<Map<String, dynamic>> summarizeChat(String text,
      {int topN = 3}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/ai/chat/summarize',
      data: {'text': text, 'top_n': topN},
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> classifyTask(String text) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/ai/classify-task',
      data: {'text': text},
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> assignMember(String projectId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/ai/assign',
      data: {'project_id': projectId},
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> suggestPriority({
    required String projectId,
    String title = '',
    String description = '',
    String? dueDate,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/ai/suggest-priority',
      data: {
        'project_id': projectId,
        'title': title,
        'description': description,
        if (dueDate != null) 'due_date': dueDate,
      },
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> suggestDeadline({
    required String projectId,
    String priority = 'medium',
    String title = '',
    String description = '',
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/ai/suggest-deadline',
      data: {
        'project_id': projectId,
        'priority': priority,
        'title': title,
        'description': description,
      },
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> predictDelay(
      {String? taskId, String? projectId}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/ai/delay',
      data: {
        if (taskId != null) 'task_id': taskId,
        if (projectId != null) 'project_id': projectId,
      },
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> workload({String? userId}) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/ai/workload',
      queryParameters: {if (userId != null) 'user_id': userId},
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> mentorRecommendations(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/ai/mentor/recommendations/$userId',
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> mentorPerformance(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/ai/mentor/performance/$userId',
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> mentorCourses(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/ai/mentor/courses/$userId',
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> predictRating(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/api/ai/predict-rating/$userId',
    );
    return responseMap(response.data);
  }

  Future<Map<String, dynamic>> recommendTeammates(
      Map<String, dynamic> userStats) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/ai/recommend-teammates',
      data: {'user_stats': userStats},
    );
    return responseMap(response.data);
  }
}
