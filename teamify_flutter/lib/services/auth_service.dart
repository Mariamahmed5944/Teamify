import '../../core/cache/cache_manager.dart';
import '../../core/network/api_result.dart';
import '../../core/network/service_error_handler.dart';
import '../../data/models/models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/session/session_controller.dart';

/// Service layer for authentication workflows.
///
/// Wraps [AuthRepository] to provide:
/// - Unified error handling via [ApiResult]
/// - Session state management
/// - Business logic for multi-step auth flows (OTP, OAuth, 2FA)
class AuthService with ServiceErrorHandler {
  final AuthRepository _repo;
  final SessionController _session;
  final CacheManager _cache;

  AuthService({
    required AuthRepository repo,
    required SessionController session,
    required CacheManager cache,
  })  : _repo = repo,
        _session = session,
        _cache = cache;

  // ── Core auth ────────────────────────────────────────────────────────────

  Future<ApiResult<ApiUser?>> login({
    required String email,
    required String password,
  }) =>
      guard(() async {
        final result = await _session.login(email: email, password: password);
        return result.user;
      });

  Future<ApiResult<ApiUser?>> register({
    required String displayName,
    required String email,
    required String password,
    required String role,
    required String userType,
    String? fullName,
    Map<String, dynamic> extra = const {},
  }) =>
      guard(() async {
        final result = await _session.register(
          displayName: displayName,
          email: email,
          password: password,
          role: role,
          userType: userType,
          fullName: fullName,
          extra: extra,
        );
        return result.user;
      });

  Future<ApiResult<void>> logout() => guard(() async {
        await _session.logout();
        await _cache.clearAll();
      });

  // ── Password recovery (multi-step) ───────────────────────────────────────

  Future<ApiResult<void>> forgotPassword(String email) =>
      guard(() => _repo.forgotPassword(email));

  Future<ApiResult<String>> verifyOtp(String email, String otp) =>
      guard(() async {
        final data = await _repo.verifyOtp(email, otp);
        return data['token']?.toString() ?? '';
      });

  Future<ApiResult<void>> resetPassword(String token, String newPassword) =>
      guard(() => _repo.resetPassword(token, newPassword));

  // ── OAuth ───────────────────────────────────────────────────────────────

  Future<ApiResult<ApiUser?>> loginWithGoogle(String idToken,
          {String? userType}) =>
      guard(() async {
        // Call repo for token saving side-effect
        await _repo.loginWithGoogle(idToken, userType: userType);
        // Restore session properly to batch state updates + notifyListeners
        await _session.restoreSession();
        return _session.currentUser;
      });

  // ── 2FA ─────────────────────────────────────────────────────────────────

  Future<ApiResult<Map<String, dynamic>>> setup2fa() =>
      guard(() => _repo.setup2fa());

  Future<ApiResult<void>> verify2fa(String token) =>
      guard(() => _repo.verify2fa(token));

  Future<ApiResult<void>> disable2fa(String token) =>
      guard(() => _repo.disable2fa(token));
}
