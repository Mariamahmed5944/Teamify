import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class FileRepository {
  final ApiClient _client;

  FileRepository(this._client);

  Future<List<ApiFile>> listFiles({String? projectId}) async {
    final response = await _client.get<dynamic>(
      '/api/files',
      queryParameters: projectId != null && projectId.isNotEmpty
          ? {'project_id': projectId}
          : null,
    );
    return responseList(response.data, ['files', 'data'])
        .map(ApiFile.fromJson)
        .toList();
  }

  Future<ApiFile> uploadFile({
    required String filePath,
    required String filename,
    String? projectId,
    List<int>? fileBytes,
  }) async {
    final MultipartFile filePayload;
    if (fileBytes != null) {
      filePayload = MultipartFile.fromBytes(fileBytes, filename: filename);
    } else {
      filePayload = await MultipartFile.fromFile(filePath, filename: filename);
    }
    final data = FormData.fromMap({
      'file': filePayload,
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

  Future<List<int>> downloadFile(String id) async {
    final response = await _client.get<List<int>>(
      '/api/files/$id',
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Accept': '*/*'},
      ),
    );
    return response.data ?? <int>[];
  }

  Future<void> deleteFile(String id) async {
    await _client.delete<dynamic>('/api/files/$id');
  }
}
