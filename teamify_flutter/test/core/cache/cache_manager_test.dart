import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:teamify/core/cache/cache_manager.dart';

/// A test-friendly subclass that overrides init() to skip initFlutter().
class _TestCacheManager extends CacheManager {
  final String _testDir;

  _TestCacheManager(this._testDir);

  @override
  Future<void> init() async {
    Hive.init(_testDir);
    await Hive.openBox<String>('_cache_meta');
    setInitialized(true);
  }
}

void main() {
  late CacheManager cache;
  late String testDir;

  setUp(() async {
    testDir =
        '${Directory.systemTemp.path}/hive_test_${DateTime.now().millisecondsSinceEpoch}';
    await Directory(testDir).create(recursive: true);
    cache = _TestCacheManager(testDir);
    await cache.init();
  });

  tearDown(() async {
    await Hive.close();
    try {
      await Directory(testDir).delete(recursive: true);
    } catch (_) {}
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Bug #2 — putList + getList roundtrip (verifies await correctness)
  // ═══════════════════════════════════════════════════════════════════════════

  group('CacheManager put + get roundtrip', () {
    test('putList then getList returns same data', () async {
      final data = [
        {'id': '1', 'name': 'Project A', 'progress': 75},
        {'id': '2', 'name': 'Project B', 'progress': 30},
      ];

      await cache.putList('projects', 'all', data);
      final result = await cache.getList('projects', 'all');

      expect(result, isNotNull);
      expect(result!.length, 2);
      expect(result[0]['name'], 'Project A');
      expect(result[1]['progress'], 30);
    });

    test('putMap then getMap returns same data', () async {
      final data = <String, dynamic>{'total_projects': 5, 'active': 3};

      await cache.putMap('dashboard', 'stats', data);
      final result = await cache.getMap('dashboard', 'stats');

      expect(result, isNotNull);
      expect(result!['total_projects'], 5);
    });

    test('invalidate removes single key', () async {
      await cache.putList('data', 'a', [
        {'x': 1}
      ]);
      await cache.putList('data', 'b', [
        {'x': 2}
      ]);

      await cache.invalidate('data', 'a');

      expect(await cache.getList('data', 'a'), isNull);
      expect(await cache.getList('data', 'b'), isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Bug #5 — invalidateBox must also clear timestamps
  // ═══════════════════════════════════════════════════════════════════════════

  group('CacheManager.invalidateBox', () {
    test('clears data AND timestamps', () async {
      await cache.putList('projects', 'all', [
        {'id': '1', 'name': 'P1'},
      ]);

      var result = await cache.getList('projects', 'all');
      expect(result, isNotNull);
      expect(result!.length, 1);

      await cache.invalidateBox('projects');

      result = await cache.getList('projects', 'all');
      expect(result, isNull);

      // Write new data — should use NEW timestamp
      await cache.putList('projects', 'all', [
        {'id': '2', 'name': 'P2'},
      ]);
      result = await cache.getList('projects', 'all');
      expect(result, isNotNull);
      expect(result!.first['id'], '2');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Bug #7 — JSON handles edge cases
  // ═══════════════════════════════════════════════════════════════════════════

  group('CacheManager JSON handling', () {
    test('handles scientific notation numbers', () async {
      await cache.putList('data', 'key', [
        {'large': 1.5e10, 'small': 3e-4},
      ]);
      final result = await cache.getList('data', 'key');
      expect(result, isNotNull);
      expect(result!.first['large'], 1.5e10);
    });

    test('handles unicode and special characters', () async {
      await cache.putList('data', 'key', [
        {'name': 'مريم', 'emoji': '🚀', 'html': '<script>'},
      ]);
      final result = await cache.getList('data', 'key');
      expect(result, isNotNull);
      expect(result!.first['name'], 'مريم');
      expect(result.first['emoji'], '🚀');
    });

    test('corrupted data returns null instead of crashing', () async {
      final box = await cache.openBox<String>('corrupted');
      await box.put('key', '{invalid json!!!}');
      // Set a timestamp so it's not considered expired
      final meta = Hive.box<String>('_cache_meta');
      await meta.put('corrupted_key_ts', DateTime.now().toIso8601String());

      final result = await cache.getList('corrupted', 'key');
      expect(result, isNull); // Cache miss, not crash
    });

    test('handles empty lists', () async {
      await cache.putList('data', 'empty', []);
      final result = await cache.getList('data', 'empty');
      expect(result, isNotNull);
      expect(result!.isEmpty, isTrue);
    });

    test('handles nested objects', () async {
      await cache.putList('data', 'nested', [
        {
          'user': {'name': 'Ali', 'roles': ['admin', 'dev']},
          'score': 95.5
        },
      ]);
      final result = await cache.getList('data', 'nested');
      expect(result, isNotNull);
      final user = result!.first['user'] as Map<String, dynamic>;
      expect(user['name'], 'Ali');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Bug #8 — Concurrent openBox must not crash
  // ═══════════════════════════════════════════════════════════════════════════

  group('CacheManager.openBox concurrency', () {
    test('10 simultaneous openBox calls for same name do not crash', () async {
      final futures = List.generate(10, (_) {
        return cache.getList('projects', 'all');
      });

      final results = await Future.wait(futures);
      for (final r in results) {
        expect(r, isNull); // No data, but no crash
      }
    });

    test('concurrent read + write do not crash', () async {
      final read = cache.getList('data', 'key');
      final write = cache.putList('data', 'key', [
        {'id': '1'}
      ]);

      await Future.wait([read, write]);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Cache TTL behavior
  // ═══════════════════════════════════════════════════════════════════════════

  group('CacheManager TTL', () {
    test('expired cache returns null', () async {
      await cache.putList('data', 'key', [
        {'id': '1'}
      ]);

      // Wait a tiny bit so the timestamp is definitely in the past
      await Future.delayed(const Duration(milliseconds: 10));

      final result = await cache.getList(
        'data',
        'key',
        maxAge: const Duration(milliseconds: 1),
      );
      expect(result, isNull);
    });

    test('non-expired cache returns data', () async {
      await cache.putList('data', 'key', [
        {'id': '1'}
      ]);

      final result = await cache.getList(
        'data',
        'key',
        maxAge: const Duration(hours: 1),
      );
      expect(result, isNotNull);
      expect(result!.first['id'], '1');
    });
  });
}
