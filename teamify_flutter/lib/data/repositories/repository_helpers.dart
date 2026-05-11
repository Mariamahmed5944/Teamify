import '../models/models.dart';

Map<String, dynamic> responseMap(dynamic data) => asMap(data);

List<Map<String, dynamic>> responseList(dynamic data, List<String> keys) {
  if (data is List) return asMapList(data);
  final map = asMap(data);
  for (final key in keys) {
    final value = map[key];
    if (value is List) return asMapList(value);
  }
  return const [];
}
