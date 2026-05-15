import 'dart:async';

/// Generic request deduplicator to prevent concurrent identical requests.
class RequestDeduplicator {
  final Map<String, Future<dynamic>> _inFlight = {};

  /// Executes [action] or returns the currently in-flight future for [key].
  Future<T> deduplicate<T>(String key, Future<T> Function() action) async {
    if (_inFlight.containsKey(key)) {
      return await _inFlight[key] as T;
    }

    final future = action();
    _inFlight[key] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  void clear() {
    _inFlight.clear();
  }
}
