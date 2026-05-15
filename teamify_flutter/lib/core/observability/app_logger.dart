import 'package:flutter/foundation.dart';

/// Lightweight logging and metrics scaffolding.
class AppLogger {
  static bool enableVerbose = kDebugMode;
  static final Map<String, dynamic> _crashContext = {};

  static void setCrashContext(String key, dynamic value) {
    _crashContext[key] = value;
  }

  static void log(String message) {
    if (enableVerbose) {
      debugPrint('[INFO] $message');
    }
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message');
    if (error != null) debugPrint(error.toString());
    if (stackTrace != null) debugPrint(stackTrace.toString());
    
    final contextStr = _crashContext.isNotEmpty ? '\nContext: $_crashContext' : '';
    debugPrint('[ERROR_CONTEXT] $contextStr');
    
    
    // Sentry.configureScope((scope) {
    //   _crashContext.forEach((k, v) => scope.setTag(k, v.toString()));
    // });
    // Sentry.captureException(error, stackTrace: stackTrace);
  }

  static void recordMetric(String name, num value, {Map<String, String>? tags}) {
    if (enableVerbose) {
      debugPrint('[METRIC] $name: $value ${tags ?? ""}');
    }
    
  }

  static void trackLatency(String operation, Duration duration) {
    recordMetric('latency.$operation', duration.inMilliseconds);
  }
}
