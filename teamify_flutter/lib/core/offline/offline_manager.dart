import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'offline_mutation.dart';
import '../cache/cache_manager.dart';
import '../network/api_client.dart';
import 'package:dio/dio.dart';

/// Manages offline mutations and replays them when online.
class OfflineManager {
  final CacheManager cache;
  final ApiClient apiClient;
  final Connectivity connectivity;

  static const _box = '_offline_queue';
  static const _key = 'mutations';
  static const _maxRetries = 5;

  bool _isReplaying = false;
  bool _isPaused = false;
  StreamSubscription? _subscription;

  OfflineManager({
    required this.cache,
    required this.apiClient,
    Connectivity? connectivity,
  }) : connectivity = connectivity ?? Connectivity();

  void init() {
    _subscription = connectivity.onConnectivityChanged.listen((result) {
      // The API changed in 6.x to return a List<ConnectivityResult>
      // Let's handle it safely.
      final isOnline = !result.contains(ConnectivityResult.none);
          
      if (isOnline && !_isPaused) {
        replayQueue();
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }

  void pauseReplay() {
    _isPaused = true;
  }

  void resumeReplay() {
    _isPaused = false;
    connectivity.checkConnectivity().then((result) {
      final isOnline = !result.contains(ConnectivityResult.none);
      if (isOnline) replayQueue();
    });
  }

  Future<void> enqueue(OfflineMutation mutation) async {
    final list = await _getQueue();
    list.add(mutation);
    await _saveQueue(list);
    
    // Optionally trigger replay instantly if we think we might be online
    final result = await connectivity.checkConnectivity();
    final isOnline = !result.contains(ConnectivityResult.none);
    if (isOnline && !_isPaused) {
      replayQueue();
    }
  }

  Future<void> replayQueue() async {
    if (_isReplaying || _isPaused) return;
    _isReplaying = true;

    try {
      final queue = await _getQueue();
      if (queue.isEmpty) return;

      final toKeep = <OfflineMutation>[];

      for (var mutation in queue) {
        if (_isPaused) break; // Abort replay if paused
        try {
          // Replay with idempotency key
          final options = Options(headers: {'Idempotency-Key': mutation.id});
          switch (mutation.method.toUpperCase()) {
            case 'POST':
              await apiClient.post<dynamic>(mutation.path, data: mutation.data, options: options);
              break;
            case 'PATCH':
            case 'PUT':
              await apiClient.patch<dynamic>(mutation.path, data: mutation.data, options: options);
              break;
            case 'DELETE':
              await apiClient.delete<dynamic>(mutation.path, data: mutation.data, options: options);
              break;
          }
          debugPrint('[OfflineManager] Replayed ${mutation.id}');
        } on DioException catch (e) {
          final isNetworkError = e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.unknown;

          if (isNetworkError) {
            // Still offline or flaky network, keep and back off
            if (mutation.retryCount < _maxRetries) {
              toKeep.add(mutation.copyWith(retryCount: mutation.retryCount + 1));
            } else {
              debugPrint('[OfflineManager] Dropped ${mutation.id} after $_maxRetries retries');
            }
          } else {
            // It failed for another reason (e.g. 400 Bad Request, 403)
            // We drop it to avoid infinite replay loops
            debugPrint('[OfflineManager] Dropped ${mutation.id} due to API error: ${e.message}');
          }
        } catch (e) {
          // Unknown error, drop
          debugPrint('[OfflineManager] Dropped ${mutation.id} due to unknown error: $e');
        }
      }

      await _saveQueue(toKeep);
    } finally {
      _isReplaying = false;
    }
  }

  Future<List<OfflineMutation>> _getQueue() async {
    final cached = await cache.getList(_box, _key, maxAge: const Duration(days: 365));
    if (cached == null) return [];
    return cached.map(OfflineMutation.fromJson).toList();
  }

  Future<void> _saveQueue(List<OfflineMutation> queue) async {
    await cache.putList(_box, _key, queue.map((m) => m.toJson()).toList());
  }
}
