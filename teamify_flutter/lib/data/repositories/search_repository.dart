import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class SearchRepository {
  final ApiClient _client;

  SearchRepository(this._client);

  Future<List<ApiUser>> users(String query, {String? userType}) async {
    final response = await _client.get<dynamic>(
      '/api/search/users',
      queryParameters: {
        if (query.isNotEmpty) 'q': query,
        if (userType != null) 'user_type': userType,
      },
    );
    return responseList(response.data, ['users', 'data'])
        .map(ApiUser.fromJson)
        .toList();
  }

  Future<List<ApiProject>> projects(String query) async {
    final response = await _client.get<dynamic>(
      '/api/search/projects',
      queryParameters: {if (query.isNotEmpty) 'q': query},
    );
    return responseList(response.data, ['projects', 'data'])
        .map(ApiProject.fromJson)
        .toList();
  }
}
