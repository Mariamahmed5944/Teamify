import 'package:flutter_test/flutter_test.dart';
import 'package:teamify/core/network/api_result.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Bug #1 — ApiResult<void> must not report false failure
  // ═══════════════════════════════════════════════════════════════════════════

  group('ApiResult', () {
    test('success with data reports isSuccess', () {
      final result = ApiResult.success('hello');
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.data, 'hello');
    });

    test('success(null) for void returns still reports isSuccess', () {
      // This is the P0 bug — guard() wraps void functions as
      // ApiResult.success(null). Before the fix, when() would fall
      // through to the failure branch.
      final result = ApiResult<dynamic>.success(null);
      expect(result.isSuccess, isTrue);
      expect(result.error, isNull);
    });

    test('when() routes void success to success branch', () {
      final result = ApiResult<dynamic>.success(null);
      final got = result.when(
        success: (_) => 'OK',
        failure: (e) => 'FAIL: $e',
      );
      expect(got, 'OK');
    });

    test('when() routes data success to success branch', () {
      final result = ApiResult.success(42);
      final got = result.when(
        success: (d) => 'value=$d',
        failure: (e) => 'FAIL',
      );
      expect(got, 'value=42');
    });

    test('when() routes failure to failure branch', () {
      final result = ApiResult<int>.failure('oops', statusCode: 400);
      final got = result.when(
        success: (d) => 'OK',
        failure: (e) => 'error=$e',
      );
      expect(got, 'error=oops');
    });

    test('map() transforms success data', () {
      final result = ApiResult.success(10);
      final mapped = result.map((d) => d * 2);
      expect(mapped.isSuccess, isTrue);
      expect(mapped.data, 20);
    });

    test('map() preserves failure', () {
      final result = ApiResult<int>.failure('bad', isNetworkError: true);
      final mapped = result.map((d) => d * 2);
      expect(mapped.isFailure, isTrue);
      expect(mapped.error, 'bad');
      expect(mapped.isNetworkError, isTrue);
    });

    test('failure exposes statusCode', () {
      final result = ApiResult<String>.failure('unauth', statusCode: 401);
      expect(result.statusCode, 401);
      expect(result.isNetworkError, isFalse);
    });

    test('network error is distinguishable from API error', () {
      final netErr =
          ApiResult<String>.failure('timeout', isNetworkError: true);
      final apiErr =
          ApiResult<String>.failure('not found', statusCode: 404);

      expect(netErr.isNetworkError, isTrue);
      expect(apiErr.isNetworkError, isFalse);
    });
  });
}
