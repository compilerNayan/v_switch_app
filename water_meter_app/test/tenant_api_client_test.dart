import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/api/tenant_api_client.dart';
import 'package:water_meter_app/core/auth/mock_auth_service.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});

  group('TenantApiClient mock registerUser', () {
    late MockAuthService auth;
    late PreferencesStorage prefs;
    late TenantApiClient client;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await PreferencesStorage.create();
      auth = MockAuthService(prefs: prefs);
      await auth.initialize();
      client = TenantApiClient(
        authService: auth,
        prefsProvider: () async => prefs,
      );
    });

    test('registerUser creates owner profile with tenant', () async {
      await auth.signUp(
        email: 'owner@example.com',
        password: 'password123',
        firstName: 'Raj',
        lastName: 'Sharma',
        phone: '+919876543210',
        gender: 'male',
      );
      await auth.confirmSignUp(
        email: 'owner@example.com',
        code: MockAuthService.mockConfirmCode,
      );
      await auth.signInWithPassword(
        email: 'owner@example.com',
        password: 'password123',
      );

      final profile = await client.registerUser(
        email: 'owner@example.com',
        phone: '+919876543210',
        firstName: 'Raj',
        lastName: 'Sharma',
        tenantName: 'Sunrise Apartments',
      );

      expect(profile.tenantId, isNotNull);
      expect(profile.isTenantOwner, isTrue);
      expect(profile.onboardingComplete, isTrue);

      final me = await client.getMe();
      expect(me.tenantId, profile.tenantId);
    });
  });
}
