import 'package:flutter/foundation.dart';

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

  /// Skips hotspot/WiFi steps; assigns a random serial and mock-enrolls.
  static const bool useMockProvisioning = bool.fromEnvironment(
    'USE_MOCK_PROVISIONING',
    defaultValue: true,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://water-meter-data-injection-env.eba-udmynr49.ap-south-1.elasticbeanstalk.com',
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
    defaultValue: 'ap-south-1',
  );

  static const String cognitoDomain = String.fromEnvironment(
    'COGNITO_DOMAIN',
    defaultValue: '',
  );

  static const String appName = 'Water Meter';

  static const String oauthRedirectUri = 'com.vswitch.watermeter://callback/';
  static const String oauthSignOutUri = 'com.vswitch.watermeter://signout/';

  /// Same host as [apiBaseUrl]. Kept for builds that still pass INJECTION_API_BASE_URL.
  static const String injectionApiBaseUrl = String.fromEnvironment(
    'INJECTION_API_BASE_URL',
    defaultValue:
        'https://water-meter-data-injection-env.eba-udmynr49.ap-south-1.elasticbeanstalk.com',
  );

  static const String liveUpdatesWsUrl = String.fromEnvironment(
    'LIVE_UPDATES_WS_URL',
    defaultValue: '',
  );

  static const bool liveUpdatesEnabled = bool.fromEnvironment(
    'LIVE_UPDATES_ENABLED',
    defaultValue: true,
  );

  static bool get isAmplifyConfigured =>
      cognitoUserPoolId.isNotEmpty && cognitoClientId.isNotEmpty;

  /// Browser build: sign-in only, building home + unit dashboard/usage.
  static bool get isWebDashboard => kIsWeb;
}
