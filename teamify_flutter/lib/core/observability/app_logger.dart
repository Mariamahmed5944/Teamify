import 'package:flutter/foundation.dart';

/// Lightweight structured logging and metrics.
///
/// Structured events use [info] with a [data] map; legacy callers
/// can still use [log] for plain strings.
class AppLogger {
  static bool enableVerbose = kDebugMode;
  static final Map<String, dynamic> _crashContext = {};

  static void setCrashContext(String key, dynamic value) {
    _crashContext[key] = value;
  }

  // ── Logging ──────────────────────────────────────────────────────────────

  /// General verbose log (backwards-compatible with existing [log] callers).
  static void log(String message) {
    if (enableVerbose) {
      debugPrint('[INFO] $message');
    }
  }

  /// Structured info event with optional key-value [data].
  ///
  /// Use for domain events like `offline.queue.add`.
  static void info(String event, {Map<String, dynamic>? data}) {
    if (enableVerbose) {
      final suffix = data != null ? ' ${data.toString()}' : '';
      debugPrint('[INFO] $event$suffix');
    }
    // Future: forward to analytics / Sentry breadcrumbs here.
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message');
    if (error != null) debugPrint(error.toString());
    if (stackTrace != null) debugPrint(stackTrace.toString());

    final contextStr =
        _crashContext.isNotEmpty ? '\nContext: $_crashContext' : '';
    debugPrint('[ERROR_CONTEXT]$contextStr');

    // Future: Sentry integration
    // Sentry.configureScope((scope) {
    //   _crashContext.forEach((k, v) => scope.setTag(k, v.toString()));
    // });
    // Sentry.captureException(error, stackTrace: stackTrace);
  }

  // ── Metrics ───────────────────────────────────────────────────────────────

  /// Record a named metric counter / gauge.
  static void recordMetric(String name, num value,
      {Map<String, String>? tags}) {
    if (enableVerbose) {
      debugPrint('[METRIC] $name: $value ${tags ?? ""}');
    }
    // Future: forward to Datadog / Prometheus here.
  }

  static void trackLatency(String operation, Duration duration) {
    recordMetric('latency.$operation', duration.inMilliseconds);
  }

  // ── Offline-specific helpers ──────────────────────────────────────────────

  /// Logs an offline queue lifecycle event with standard fields.
  static void offlineEvent(
    String event, {
    required String id,
    required String tag,
    int? retryCount,
    String? error,
    int? latencyMs,
  }) {
    final data = <String, dynamic>{
      'id': id,
      'tag': tag,
      if (retryCount != null) 'retry': retryCount,
      if (error != null) 'error': error,
      if (latencyMs != null) 'latency_ms': latencyMs,
    };
    info(event, data: data);
    recordMetric(event, 1, tags: {
      'tag': tag,
      'id': id,
      if (retryCount != null) 'retry': retryCount.toString(),
    });
  }
}
