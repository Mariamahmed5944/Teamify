import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  final Dio dio;
  final TokenStorage tokenStorage;

  bool _isRefreshing = false;

  ApiClient({
    Dio? dio,
    TokenStorage? tokenStorage,
  })  : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.apiBaseUrl,
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ),
        tokenStorage = tokenStorage ?? TokenStorage() {
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: _addAuthHeader,
            onError: _handleError,
          ),
        );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<void> _addAuthHeader(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final skipAuth = options.extra['skipAuth'] == true;
    if (!skipAuth) {
      final token = await tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = error.response?.statusCode;
    final alreadyRetried = error.requestOptions.extra['retried'] == true;

    if (statusCode == 401 && !alreadyRetried && !_isRefreshing) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        try {
          final retryOptions = error.requestOptions;
          retryOptions.extra['retried'] = true;
          final accessToken = await tokenStorage.readAccessToken();
          if (accessToken != null) {
            retryOptions.headers['Authorization'] = 'Bearer $accessToken';
          }
          final response = await dio.fetch<dynamic>(retryOptions);
          handler.resolve(response);
          return;
        } catch (_) {
          await tokenStorage.clear();
        }
      }
    }

    final apiException = ApiException.fromResponse(
      statusCode,
      error.response?.data,
    );
    handler.reject(
      DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: apiException,
        message: apiException.message,
      ),
    );
  }

  Future<bool> _refreshAccessToken() async {
    _isRefreshing = true;
    try {
      final refreshToken = await tokenStorage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      final response = await dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
          extra: {'skipAuth': true},
        ),
      );
      final token = response.data?['access_token']?.toString();
      if (token == null || token.isEmpty) return false;

      await tokenStorage.saveAccessToken(token);
      return true;
    } catch (_) {
      await tokenStorage.clear();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }
}
