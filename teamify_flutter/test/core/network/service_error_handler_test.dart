import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teamify/core/network/api_exception.dart';
import 'package:teamify/core/network/service_error_handler.dart';

/// Concrete test class using the ServiceErrorHandler mixin.
class _TestService with ServiceErrorHandler {}

void main() {
  late _TestService service;

  setUp(() {
    service = _TestService();
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // guard() — basic error handling
  // ═══════════════════════════════════════════════════════════════════════════

  group('ServiceErrorHandler.guard()', () {
    test('returns success on normal completion', () async {
      final result = await service.guard(() async {
        return 42;
      });
      expect(result.isSuccess, isTrue);
      expect(result.data, 42);
    });

    test('returns success for void actions', () async {
      final result = await service.guard<void>(() async {
        // void — no return value
      });
      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
    });

    test('catches ApiException and extracts message', () async {
      final result = await service.guard<int>(() async {
        throw DioException(
          requestOptions: RequestOptions(path: '/test'),
          error: const ApiException('User not found', statusCode: 404),
        );
      });
      expect(result.isFailure, isTrue);
      expect(result.error, 'User not found');
      expect(result.statusCode, 404);
      expect(result.isNetworkError, isFalse);
    });

    // ── Bug #9: sendTimeout must be classified as network error ────────────

    test('connectionTimeout is classified as network error', () async {
      final result = await service.guard<int>(() async {
        throw DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionTimeout,
        );
      });
      expect(result.isNetworkError, isTrue);
    });

    test('receiveTimeout is classified as network error', () async {
      final result = await service.guard<int>(() async {
        throw DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.receiveTimeout,
        );
      });
      expect(result.isNetworkError, isTrue);
    });

    test('sendTimeout is classified as network error (Bug #9)', () async {
      final result = await service.guard<int>(() async {
        throw DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.sendTimeout,
        );
      });
      expect(result.isNetworkError, isTrue);
    });

    test('connectionError is classified as network error', () async {
      final result = await service.guard<int>(() async {
        throw DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.connectionError,
        );
      });
      expect(result.isNetworkError, isTrue);
    });

    test('badResponse is NOT classified as network error', () async {
      final result = await service.guard<int>(() async {
        throw DioException(
          requestOptions: RequestOptions(path: '/test'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: 500,
          ),
        );
      });
      expect(result.isNetworkError, isFalse);
      expect(result.statusCode, 500);
    });

    test('non-Dio exceptions are caught gracefully', () async {
      final result = await service.guard<int>(() async {
        throw FormatException('bad data');
      });
      expect(result.isFailure, isTrue);
      expect(result.error, contains('FormatException'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // guardWithRetry() — retry logic
  // ═══════════════════════════════════════════════════════════════════════════

  group('ServiceErrorHandler.guardWithRetry()', () {
    test('returns success on first attempt if no error', () async {
      var callCount = 0;
      final result = await service.guardWithRetry(() async {
        callCount++;
        return 'ok';
      });
      expect(result.isSuccess, isTrue);
      expect(callCount, 1);
    });

    test('retries on network error and succeeds', () async {
      var callCount = 0;
      final result = await service.guardWithRetry(
        () async {
          callCount++;
          if (callCount < 2) {
            throw DioException(
              requestOptions: RequestOptions(path: '/test'),
              type: DioExceptionType.connectionTimeout,
            );
          }
          return 'recovered';
        },
        maxRetries: 2,
      );
      expect(result.isSuccess, isTrue);
      expect(result.data, 'recovered');
      expect(callCount, 2);
    });

    test('does NOT retry on API errors (non-network)', () async {
      var callCount = 0;
      final result = await service.guardWithRetry(
        () async {
          callCount++;
          throw DioException(
            requestOptions: RequestOptions(path: '/test'),
            error: const ApiException('forbidden', statusCode: 403),
          );
        },
        maxRetries: 3,
      );
      expect(result.isFailure, isTrue);
      expect(callCount, 1); // No retries for 403
      expect(result.error, 'forbidden');
    });

    test('exhausts retries and returns final failure', () async {
      var callCount = 0;
      final result = await service.guardWithRetry(
        () async {
          callCount++;
          throw DioException(
            requestOptions: RequestOptions(path: '/test'),
            type: DioExceptionType.connectionError,
          );
        },
        maxRetries: 2,
      );
      expect(result.isFailure, isTrue);
      expect(result.isNetworkError, isTrue);
      expect(callCount, 3); // initial + 2 retries
    });
  });
}
