import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/auth_repository.dart';

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

  SessionController(this._authRepository);

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isPendingApproval => status == SessionStatus.pendingApproval;

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
  }) async {
    final result =
        await _authRepository.login(email: email, password: password);
    currentUser = result.user;
    lastMessage = result.message;
    status = (result.user?.isPending ?? false)
        ? SessionStatus.pendingApproval
        : SessionStatus.authenticated;
    notifyListeners();
    return result;
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
    final result = await _authRepository.register(
      displayName: displayName,
      email: email,
      password: password,
      role: role,
      userType: userType,
      fullName: fullName,
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

  Future<void> logout() async {
    await _authRepository.logout();
    currentUser = null;
    status = SessionStatus.unauthenticated;
    notifyListeners();
  }
}
