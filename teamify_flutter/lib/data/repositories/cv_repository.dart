import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class CVRepository {
  final ApiClient _client;

  CVRepository(this._client);

  Future<List<ApiCV>> listCVs() async {
    final response = await _client.get<dynamic>('/api/cv');
    return responseList(response.data, ['cvs', 'cv', 'data'])
        .map(ApiCV.fromJson)
        .toList();
  }

  Future<ApiCV> createCV(Map<String, dynamic> payload) async {
    final response =
        await _client.post<Map<String, dynamic>>('/api/cv', data: payload);
    final data = responseMap(response.data);
    final cv = responseMap(data['cv']);
    return ApiCV.fromJson(cv.isNotEmpty ? cv : data);
  }

  Future<ApiCV> updateCV(String id, Map<String, dynamic> payload) async {
    final response =
        await _client.patch<Map<String, dynamic>>('/api/cv/$id', data: payload);
    final data = responseMap(response.data);
    final cv = responseMap(data['cv']);
    return ApiCV.fromJson(cv.isNotEmpty ? cv : data);
  }

  Future<Response<List<int>>> exportPdf(String id) {
    return _client.get<List<int>>(
      '/api/cv/$id/export/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<Map<String, dynamic>> buildWithAI({String? targetUserId}) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/ai/cv/build',
      data: targetUserId == null ? const {} : {'target_user_id': targetUserId},
    );
    return responseMap(response.data);
  }
}
