class AppConfig {
  static bool isDemoMode = true;
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://teamify-backend-5hq0.onrender.com',
  );
}
