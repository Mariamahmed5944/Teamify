import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/auth_repository.dart';
import 'disposable_registry.dart';

enum SessionStatus {
  unknown,
  unauthenticated,
  authenticated,
  pendingApproval,
}

class SessionController extends ChangeNotifier {
  final AuthRepository _authRepository;

  SessionStatus status = SessionStatus.unknown;
  ApiUser? currentUser;
  String? lastMessage;
  bool admin2faLoginPending = false;
  bool admin2faSetupRequired = false;

  SessionController(this._authRepository);

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isPendingApproval => status == SessionStatus.pendingApproval;
  bool get needsAdmin2faStep =>
      currentUser?.needsAdmin2faSetup == true ||
      admin2faLoginPending ||
      admin2faSetupRequired;

  Future<void> restoreSession() async {
    status = SessionStatus.unknown;
    notifyListeners();

    final hasSession = await _authRepository.hasSavedSession();
    if (!hasSession) {
      status = SessionStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      currentUser = await _authRepository.me();
      status = currentUser == null
          ? SessionStatus.unauthenticated
          : currentUser!.isPending
              ? SessionStatus.pendingApproval
              : SessionStatus.authenticated;
    } catch (_) {
      currentUser = null;
      status = SessionStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<AuthResult> login({
    required String email,
    required String password,
    String? totpCode,
  }) async {
    final result =
        await _authRepository.login(email: email, password: password, totpCode: totpCode);
    currentUser = result.user;
    final hasSession = await _authRepository.hasSavedSession();
    if (currentUser == null && hasSession) {
      try {
        currentUser = await _authRepository.me();
      } catch (_) {}
    }
    lastMessage = result.message;
    admin2faLoginPending = result.requires2faLogin;
    admin2faSetupRequired = result.requires2faSetup;
    if (currentUser == null && !hasSession) {
      status = SessionStatus.unauthenticated;
    } else {
      status = (currentUser?.isPending ?? false)
          ? SessionStatus.pendingApproval
          : SessionStatus.authenticated;
    }
    notifyListeners();
    return result;
  }

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
    required String userType,
    Map<String, dynamic> extra = const {},
  }) async {
    final result = await _authRepository.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      userType: userType,
      extra: extra,
    );
    currentUser = result.user;
    lastMessage = result.message;
    status = result.pendingApproval
        ? SessionStatus.pendingApproval
        : SessionStatus.authenticated;
    notifyListeners();
    return result;
  }

  void clearAdmin2faLoginPending() {
    admin2faLoginPending = false;
    admin2faSetupRequired = false;
    notifyListeners();
  }

  /// Update in-memory user after profile edits (avoids extra /me round-trip).
  void setCurrentUser(ApiUser? user) {
    currentUser = user;
    if (user == null) {
      status = SessionStatus.unauthenticated;
    } else {
      status = user.isPending
          ? SessionStatus.pendingApproval
          : SessionStatus.authenticated;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepository.logout();
    currentUser = null;
    admin2faLoginPending = false;
    admin2faSetupRequired = false;
    status = SessionStatus.unauthenticated;
    globalDisposableRegistry.disposeAll();
    notifyListeners();
  }

  /// Called when the API client clears tokens after a failed refresh.
  void forceUnauthenticated() {
    if (status == SessionStatus.unauthenticated && currentUser == null) {
      return;
    }
    currentUser = null;
    admin2faLoginPending = false;
    admin2faSetupRequired = false;
    status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  /// Apply tokens + user returned by Google/GitHub OAuth endpoints.
  Future<void> completeOAuthLogin(AuthResult result) async {
    currentUser = result.user;
    lastMessage = result.message;

    if (currentUser == null && await _authRepository.hasSavedSession()) {
      try {
        currentUser = await _authRepository.me();
      } catch (_) {}
    }

    status = currentUser == null
        ? SessionStatus.unauthenticated
        : currentUser!.isPending
            ? SessionStatus.pendingApproval
            : SessionStatus.authenticated;
    notifyListeners();
  }
}
