/// Generic result wrapper for all service layer calls.
///
/// Provides a consistent API for both success and failure cases,
/// eliminating the need for try/catch at the UI level.
class ApiResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool isNetworkError;

  const ApiResult._({
    this.data,
    this.error,
    this.statusCode,
    this.isNetworkError = false,
  });

  /// Successful result containing [data].
  factory ApiResult.success(T data) => ApiResult._(data: data);

  /// Failed result with a human-readable [error] message.
  factory ApiResult.failure(
    String error, {
    int? statusCode,
    bool isNetworkError = false,
  }) =>
      ApiResult._(
        error: error,
        statusCode: statusCode,
        isNetworkError: isNetworkError,
      );

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  /// Transforms the success [data] using [transform], keeps failures intact.
  ApiResult<R> map<R>(R Function(T data) transform) {
    if (isSuccess) {
      return ApiResult.success(transform(data as T));
    }
    return ApiResult.failure(
      error ?? 'Unknown error',
      statusCode: statusCode,
      isNetworkError: isNetworkError,
    );
  }

  /// Convenience: execute [onSuccess] or [onFailure] and return a value.
  R when<R>({
    required R Function(T data) success,
    required R Function(String error) failure,
  }) {
    if (isSuccess) return success(data as T);
    return failure(error ?? 'Unknown error');
  }
}
