import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'api_result.dart';

/// Mixin providing standardized error-handling and retry logic for services.
mixin ServiceErrorHandler {
  /// Wraps any async call in an [ApiResult], catching Dio and generic errors.
  Future<ApiResult<T>> guard<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return ApiResult.success(result);
    } on DioException catch (e) {
      final apiError = e.error;
      if (apiError is ApiException) {
        return ApiResult.failure(
          apiError.message,
          statusCode: apiError.statusCode,
        );
      }
      // Network / timeout errors
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.connectionError) {
        return ApiResult.failure(
          'Network error. Please check your connection.',
          isNetworkError: true,
        );
      }
      return ApiResult.failure(
        e.message ?? 'Request failed',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      return ApiResult.failure(e.toString());
    }
  }

  /// Retries [action] up to [maxRetries] times with exponential backoff.
  Future<ApiResult<T>> guardWithRetry<T>(
    Future<T> Function() action, {
    int maxRetries = 2,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final result = await guard(action);
      if (result.isSuccess || !result.isNetworkError) return result;
      if (attempt < maxRetries) {
        await Future.delayed(Duration(seconds: 1 << attempt)); // 1s, 2s, 4s
      }
    }
    return ApiResult.failure('Request failed after retries', isNetworkError: true);
  }
}
