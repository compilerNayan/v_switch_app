/// Compile-time configuration for API, auth, and build flavors.
class AppConfig {
  AppConfig._();

  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: true,
  );

  static const bool useMockAuth = bool.fromEnvironment(
    'USE_MOCK_AUTH',
    defaultValue: true,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.example.com/v1',
  );

  static const String cognitoUserPoolId = String.fromEnvironment(
    'COGNITO_USER_POOL_ID',
    defaultValue: '',
  );

  static const String cognitoClientId = String.fromEnvironment(
    'COGNITO_CLIENT_ID',
    defaultValue: '',
  );

  static const String cognitoRegion = String.fromEnvironment(
    'COGNITO_REGION',
    defaultValue: 'us-east-1',
  );

  static const String cognitoDomain = String.fromEnvironment(
    'COGNITO_DOMAIN',
    defaultValue: '',
  );

  static const String appName = 'Water Meter';

  static const String oauthRedirectUri = 'com.vswitch.watermeter://callback/';
  static const String oauthSignOutUri = 'com.vswitch.watermeter://signout/';

  static bool get isAmplifyConfigured =>
      cognitoUserPoolId.isNotEmpty && cognitoClientId.isNotEmpty;
}
