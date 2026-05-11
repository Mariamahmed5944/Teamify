import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../models/models.dart';
import 'repository_helpers.dart';

class AuthResult {
  final ApiUser? user;
  final bool pendingApproval;
  final String message;

  const AuthResult({
    this.user,
    this.pendingApproval = false,
    this.message = '',
  });
}

class AuthRepository {
  final ApiClient _client;
  final TokenStorage _tokenStorage;

  AuthRepository({
    required ApiClient client,
    required TokenStorage tokenStorage,
  })  : _client = client,
        _tokenStorage = tokenStorage;

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: {'email': email, 'password': password},
      options: Options(extra: {'skipAuth': true}),
    );
    await _saveTokens(response.data);
    final user = _extractUser(response.data);
    return AuthResult(user: user, message: asString(response.data?['message']));
  }

  Future<AuthResult> register({
    required String displayName,
    required String email,
    required String password,
    required String role,
    required String userType,
    String? fullName,
    Map<String, dynamic> extra = const {},
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/api/auth/register',
      data: {
        'display_name': displayName,
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role,
        'user_type': userType,
        ...extra,
      },
      options: Options(extra: {'skipAuth': true}),
    );
    await _saveTokens(response.data);
    final user = _extractUser(response.data);
    return AuthResult(
      user: user,
      pendingApproval: user?.isPending ?? false,
      message: asString(response.data?['message']),
    );
  }

  Future<ApiUser?> me() async {
    final response = await _client.get<Map<String, dynamic>>('/api/auth/me');
    return _extractUser(response.data);
  }

  Future<void> logout() async {
    try {
      await _client.post<Map<String, dynamic>>('/api/auth/logout');
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<bool> hasSavedSession() async {
    final token = await _tokenStorage.readAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> _saveTokens(Map<String, dynamic>? data) async {
    final access = data?['access_token']?.toString();
    final refresh = data?['refresh_token']?.toString();
    if (access != null && refresh != null) {
      await _tokenStorage.saveTokens(
          accessToken: access, refreshToken: refresh);
    }
  }

  ApiUser? _extractUser(Map<String, dynamic>? data) {
    if (data == null) return null;
    final userMap = responseMap(data['user']);
    if (userMap.isNotEmpty) return ApiUser.fromJson(userMap);
    if (data.containsKey('id') || data.containsKey('email')) {
      return ApiUser.fromJson(data);
    }
    return null;
  }
}
