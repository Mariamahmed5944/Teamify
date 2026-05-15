import '../../core/network/api_client.dart';
import 'repository_helpers.dart';

class ChatRepository {
  final ApiClient _client;

  ChatRepository(this._client);

  /// GET /api/chat/rooms
  Future<List<Map<String, dynamic>>> listRooms() async {
    final response = await _client.get<dynamic>('/api/chat/rooms');
    return responseList(response.data, ['rooms', 'data'])
        .cast<Map<String, dynamic>>();
  }

  /// POST /api/chat/rooms
  /// Payload keys: name, type, project_id, members (list of user IDs)
  Future<Map<String, dynamic>> createRoom(
      Map<String, dynamic> payload) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/chat/rooms',
      data: payload,
    );
    return responseMap(response.data);
  }

  /// GET /api/chat/rooms/<roomId>/messages
  Future<List<Map<String, dynamic>>> getMessages(
    String roomId, {
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _client.get<dynamic>(
      '/api/chat/rooms/$roomId/messages',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return responseList(response.data, ['messages', 'data'])
        .cast<Map<String, dynamic>>();
  }
}
