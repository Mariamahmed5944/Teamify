import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _accessKey = 'teamify_access_token';
  static const _refreshKey = 'teamify_refresh_token';

  final FlutterSecureStorage _storage;

  /// Web: secure storage can fail silently; keep in-memory copy for the session.
  String? _memAccess;
  String? _memRefresh;

  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              webOptions: WebOptions(
                dbName: 'TeamifySecureStorage',
                publicKey: 'TeamifyWebKey',
              ),
            );

  Future<String?> readAccessToken() async {
    if (_memAccess != null && _memAccess!.isNotEmpty) return _memAccess;
    try {
      final token = await _storage.read(key: _accessKey);
      if (token != null && token.isNotEmpty) {
        _memAccess = token;
      }
      return token;
    } catch (_) {
      return _memAccess;
    }
  }

  Future<String?> readRefreshToken() async {
    if (_memRefresh != null && _memRefresh!.isNotEmpty) return _memRefresh;
    try {
      final token = await _storage.read(key: _refreshKey);
      if (token != null && token.isNotEmpty) {
        _memRefresh = token;
      }
      return token;
    } catch (_) {
      return _memRefresh;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _memAccess = accessToken;
    _memRefresh = refreshToken;
    try {
      await _storage.write(key: _accessKey, value: accessToken);
      await _storage.write(key: _refreshKey, value: refreshToken);
    } catch (_) {
      if (kDebugMode) {
        // Web fallback: in-memory tokens still work for this browser session.
      }
    }
  }

  Future<void> saveAccessToken(String accessToken) {
    _memAccess = accessToken;
    try {
      return _storage.write(key: _accessKey, value: accessToken);
    } catch (_) {
      return Future.value();
    }
  }

  Future<void> clear() async {
    _memAccess = null;
    _memRefresh = null;
    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (_) {}
  }
}
