import '../../core/network/api_client.dart';
import 'repository_helpers.dart';

class ReminderRepository {
  final ApiClient _client;

  ReminderRepository(this._client);

  /// GET /api/reminders
  Future<List<Map<String, dynamic>>> getReminders() async {
    final response = await _client.get<dynamic>('/api/reminders');
    return responseList(response.data, ['reminders', 'data'])
        .cast<Map<String, dynamic>>();
  }
}
