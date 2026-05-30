/// OAuth client IDs and redirect URI used by social sign-in (web).
class OAuthConfig {
  OAuthConfig._();

  static const googleClientId =
      '854339507790-tntdbhvs0onvvpms12frchr32mq4eud5.apps.googleusercontent.com';

  static const githubClientId = 'Ov23liRUeYFAPsv1xgtd';

  /// Optional fixed callback URL — must match GitHub/Google OAuth app settings.
  /// Example: --dart-define=OAUTH_REDIRECT_URI=http://localhost:8080/
  static const _configuredRedirectUri = String.fromEnvironment(
    'OAUTH_REDIRECT_URI',
    defaultValue: '',
  );

  /// Normalized callback URL (always ends with `/`).
  static String redirectUri() {
    final raw = _configuredRedirectUri.isNotEmpty
        ? _configuredRedirectUri
        : '${Uri.base.origin}/';
    return raw.endsWith('/') ? raw : '$raw/';
  }

  static Uri githubAuthorizeUri() {
    return Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': githubClientId,
      'redirect_uri': redirectUri(),
      'scope': 'user:email',
    });
  }

  static Uri googleAuthorizeUri({required String nonce}) {
    return Uri.https('accounts.google.com', '/o/oauth2/auth', {
      'client_id': googleClientId,
      'redirect_uri': redirectUri(),
      'response_type': 'id_token',
      'scope': 'openid email profile',
      'nonce': nonce,
      'prompt': 'select_account',
    });
  }
}
