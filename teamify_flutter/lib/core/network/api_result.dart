/// Generic result wrapper for all service layer calls.
///
/// Additions over original:
///  - [isOfflineQueued] : mutation was captured for later sync
///  - [isPendingSync]   : synonym exposed for UI consumption
class ApiResult<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool isNetworkError;

  /// True when the mutation was NOT executed but was queued offline.
  ///
  /// UI should show an "offline / pending sync" indicator when this is true.
  final bool isOfflineQueued;

  const ApiResult._({
    this.data,
    this.error,
    this.statusCode,
    this.isNetworkError = false,
    this.isOfflineQueued = false,
  });

  // ── Constructors ─────────────────────────────────────────────────────────

  /// Successful result containing [data].
  factory ApiResult.success(T data) => ApiResult._(data: data);

  /// Failed result with a human-readable [error] message.
  factory ApiResult.failure(
    String error, {
    int? statusCode,
    bool isNetworkError = false,
    bool isOfflineQueued = false,
  }) =>
      ApiResult._(
        error: error,
        statusCode: statusCode,
        isNetworkError: isNetworkError,
        isOfflineQueued: isOfflineQueued,
      );

  /// Special constructor: mutation queued for later sync.
  ///
  /// This is technically a "failure" (no immediate data), but the user's
  /// intent has been preserved and will be replayed when connectivity returns.
  factory ApiResult.queued(String message) => ApiResult._(
        error: message,
        isNetworkError: true,
        isOfflineQueued: true,
      );

  // ── Predicates ───────────────────────────────────────────────────────────

  bool get isSuccess => error == null;
  bool get isFailure => error != null && !isOfflineQueued;

  /// True for UI to render "pending sync" state (gray item, cloud-off icon).
  bool get isPendingSync => isOfflineQueued;

  // ── Transformers ─────────────────────────────────────────────────────────

  /// Maps success data; propagates failures unchanged.
  ApiResult<R> map<R>(R Function(T data) transform) {
    if (isSuccess) {
      return ApiResult.success(transform(data as T));
    }
    return ApiResult.failure(
      error ?? 'Unknown error',
      statusCode: statusCode,
      isNetworkError: isNetworkError,
      isOfflineQueued: isOfflineQueued,
    );
  }

  /// Executes [onSuccess] or [onFailure] and returns a value.
  R when<R>({
    required R Function(T data) success,
    required R Function(String error) failure,
  }) {
    if (isSuccess) return success(data as T);
    return failure(error ?? 'Unknown error');
  }
}

/// Await an [ApiResult] from a service call and throw on failure so widgets
/// like [RepositoryLoader] can stay [`Future<T>`]-based.
extension ApiResultFutureX<T> on Future<ApiResult<T>> {
  Future<T> unwrap() async {
    final r = await this;
    if (r.isSuccess) return r.data as T;
    throw Exception(r.error ?? 'Unknown error');
  }
}
