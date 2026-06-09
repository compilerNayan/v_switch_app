import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/api/tenant_api_client.dart';
import 'package:water_meter_app/core/auth/mock_auth_service.dart';
import 'package:water_meter_app/core/models/tenant_config.dart';
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
      expect(profile.onboardingComplete, isFalse);

      final building = await client.createBuilding(
        tenantId: profile.tenantId!,
        name: 'Sunrise Apartments',
        structure: const TenantStructure(
          blocks: [
            TenantBlock(
              id: 'A',
              label: 'Tower A',
              wings: [TenantWing(name: 'East', floorCount: 8)],
            ),
          ],
        ),
      );
      expect(building.name, 'Sunrise Apartments');
      expect(building.structure.blocks.first.wings.first.floorCount, 8);

      final me = await client.getMe();
      expect(me.tenantId, profile.tenantId);
      expect(me.onboardingComplete, isTrue);
    });

    test('preEnrollDevice succeeds in mock API mode', () async {
      await expectLater(
        client.preEnrollDevice(
          tenantId: 'tenant-mock',
          serialNumber: 'WM123456',
        ),
        completes,
      );
    });
  });
}
