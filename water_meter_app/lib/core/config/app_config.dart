/// Compile-time configuration for API and build flavors.
class AppConfig {
  AppConfig._();

  /// Set via: flutter run --dart-define=USE_MOCK_API=false
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: true,
  );

  /// Set via: flutter run --dart-define=API_BASE_URL=https://api.example.com/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com/v1',
  );

  static const String appName = 'Water Meter';
}
