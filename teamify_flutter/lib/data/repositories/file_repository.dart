import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class FileRepository {
  final ApiClient _client;

  FileRepository(this._client);

  Future<List<ApiFile>> listFiles() async {
    final response = await _client.get<dynamic>('/api/files');
    return responseList(response.data, ['files', 'data'])
        .map(ApiFile.fromJson)
        .toList();
  }

  Future<ApiFile> uploadFile({
    required String filePath,
    required String filename,
    String? projectId,
  }) async {
    final data = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
      if (projectId != null) 'project_id': projectId,
    });
    final response = await _client.post<Map<String, dynamic>>(
      '/api/files',
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
    final map = responseMap(response.data);
    final file = responseMap(map['file']);
    return ApiFile.fromJson(file.isNotEmpty ? file : map);
  }

  Future<Response<List<int>>> downloadFile(String id) {
    return _client.get<List<int>>(
      '/api/files/$id',
      options: Options(responseType: ResponseType.bytes),
    );
  }
}
