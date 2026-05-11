import '../../core/network/api_client.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class NotificationRepository {
  final ApiClient _client;

  NotificationRepository(this._client);

  Future<List<ApiNotification>> listNotifications() async {
    final response = await _client.get<dynamic>('/api/notifications');
    return responseList(response.data, ['notifications', 'data'])
        .map(ApiNotification.fromJson)
        .toList();
  }

  Future<void> markRead(String id) async {
    await _client.patch<dynamic>('/api/notifications/$id/read');
  }
}
