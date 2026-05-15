import 'dart:convert' as convert;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:hive_flutter/hive_flutter.dart';

/// Lightweight cache layer backed by Hive.
///
/// Uses a cache-first strategy: reads from local storage immediately,
/// then syncs with the backend in the background.
class CacheManager {
  static const _metaBoxName = '_cache_meta';

  bool _initialized = false;

  /// Guards against concurrent `openBox` calls for the same name.
  final Map<String, Future<Box<dynamic>>> _openingBoxes = {};

  /// Call once at app startup (before runApp).
  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await Hive.openBox<String>(_metaBoxName);
    _initialized = true;
  }

  /// Test-only setter for [_initialized]. Allows test subclasses to bypass
  /// [Hive.initFlutter()] which requires Flutter bindings.
  @visibleForTesting
  void setInitialized(bool value) => _initialized = value;

  /// Open (or reuse) a typed box. Safe against concurrent calls.
  Future<Box<T>> openBox<T>(String name) async {
    if (Hive.isBoxOpen(name)) return Hive.box<T>(name);
    // Deduplicate concurrent open calls for the same box name
    if (_openingBoxes.containsKey(name)) {
      await _openingBoxes[name];
      return Hive.box<T>(name);
    }
    final future = Hive.openBox<T>(name);
    _openingBoxes[name] = future;
    try {
      await future;
      return Hive.box<T>(name);
    } finally {
      _openingBoxes.remove(name);
    }
  }

  /// Store a JSON-serializable map list under [key] in [boxName].
  Future<void> putList(
    String boxName,
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    if (!_initialized) return;
    final box = await openBox<String>(boxName);
    final encoded = convert.jsonEncode(items);
    await box.put(key, encoded);
    await _setTimestamp(boxName, key);
  }

  /// Store a single JSON-serializable map under [key] in [boxName].
  Future<void> putMap(
    String boxName,
    String key,
    Map<String, dynamic> data,
  ) async {
    if (!_initialized) return;
    final box = await openBox<String>(boxName);
    final encoded = convert.jsonEncode(data);
    await box.put(key, encoded);
    await _setTimestamp(boxName, key);
  }

  /// Retrieve a cached list, or null if missing / expired.
  Future<List<Map<String, dynamic>>?> getList(
    String boxName,
    String key, {
    Duration maxAge = const Duration(minutes: 10),
  }) async {
    if (!_initialized) return null;
    if (_isExpired(boxName, key, maxAge)) return null;
    try {
      final box = await openBox<String>(boxName);
      final raw = box.get(key);
      if (raw == null) return null;
      final decoded = convert.jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
      return null;
    } catch (_) {
      // Corrupted cache — treat as miss
      await invalidate(boxName, key);
      return null;
    }
  }

  /// Retrieve a cached map, or null if missing / expired.
  Future<Map<String, dynamic>?> getMap(
    String boxName,
    String key, {
    Duration maxAge = const Duration(minutes: 10),
  }) async {
    if (!_initialized) return null;
    if (_isExpired(boxName, key, maxAge)) return null;
    try {
      final box = await openBox<String>(boxName);
      final raw = box.get(key);
      if (raw == null) return null;
      final decoded = convert.jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      await invalidate(boxName, key);
      return null;
    }
  }

  /// Invalidate a specific cache entry.
  Future<void> invalidate(String boxName, String key) async {
    if (!_initialized) return;
    final box = await openBox<String>(boxName);
    await box.delete(key);
    final meta = Hive.box<String>(_metaBoxName);
    await meta.delete('${boxName}_${key}_ts');
  }

  /// Invalidate everything in a box, including timestamps.
  Future<void> invalidateBox(String boxName) async {
    if (!_initialized) return;
    final box = await openBox<String>(boxName);
    await box.clear();
    // Also clear all timestamps for this box
    final meta = Hive.box<String>(_metaBoxName);
    final keysToDelete = meta.keys
        .where((k) => k.toString().startsWith('${boxName}_'))
        .toList();
    for (final key in keysToDelete) {
      await meta.delete(key);
    }
  }

  /// Clear all caches. Safe to call during logout.
  Future<void> clearAll() async {
    _initialized = false;
    _openingBoxes.clear();
    // Close all boxes first to prevent write-after-delete
    await Hive.close();
    await Hive.deleteFromDisk();
    await init();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  bool _isExpired(String boxName, String key, Duration maxAge) {
    if (!Hive.isBoxOpen(_metaBoxName)) return true;
    final meta = Hive.box<String>(_metaBoxName);
    final tsStr = meta.get('${boxName}_${key}_ts');
    if (tsStr == null) return true;
    final ts = DateTime.tryParse(tsStr);
    if (ts == null) return true;
    return DateTime.now().difference(ts) > maxAge;
  }

  Future<void> _setTimestamp(String boxName, String key) async {
    if (!Hive.isBoxOpen(_metaBoxName)) return;
    final meta = Hive.box<String>(_metaBoxName);
    await meta.put(
      '${boxName}_${key}_ts',
      DateTime.now().toIso8601String(),
    );
  }
}
