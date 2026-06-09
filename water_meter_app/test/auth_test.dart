import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/auth/mock_auth_service.dart';
import 'package:water_meter_app/core/models/tenant_config.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';

Future<void> _signUpOwner(MockAuthService auth) async {
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});

  group('MockAuthService password flow', () {
    late MockAuthService auth;
    late PreferencesStorage prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await PreferencesStorage.create();
      auth = MockAuthService(prefs: prefs);
      await auth.initialize();
    });

    test('sign up and confirm creates unboarded profile after sign in', () async {
      await _signUpOwner(auth);
      final profile = await auth.getCurrentUser();
      expect(profile, isNotNull);
      expect(profile!.email, 'owner@example.com');
      expect(profile.tenantId, isNull);
    });

    test('register user creates tenant for owner', () async {
      await _signUpOwner(auth);
      final profile = await auth.registerUser(
        email: 'owner@example.com',
        phone: '+919876543210',
        firstName: 'Raj',
        lastName: 'Sharma',
        prefs: prefs,
      );

      expect(profile.onboardingComplete, isFalse);
      expect(profile.isTenantOwner, isTrue);
      expect(profile.tenantId, isNotNull);
      expect(profile.tenantId, hasLength(7));
      expect(prefs.getTenantConfig()?.name, '');
    });
  });

  group('MockAuthService tenant flow', () {
    late MockAuthService auth;
    late PreferencesStorage prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await PreferencesStorage.create();
      auth = MockAuthService(prefs: prefs);
      await auth.initialize();
    });

    Future<void> seedOwnerTenant() async {
      await _signUpOwner(auth);
      await auth.registerUser(
        email: 'owner@example.com',
        phone: '+919876543210',
        firstName: 'Raj',
        lastName: 'Sharma',
        prefs: prefs,
      );
      await auth.createBuilding(
        tenantId: prefs.getTenantConfig()!.tenantId,
        name: 'Demo Building',
        structure: const TenantStructure(
          blocks: [
            TenantBlock(
              id: 'A',
              label: 'Tower A',
              wings: [TenantWing(name: 'East', floorCount: 5)],
            ),
          ],
        ),
        prefs: prefs,
      );
    }

    test('building setup completes onboarding', () async {
      await _signUpOwner(auth);
      await auth.registerUser(
        email: 'owner@example.com',
        phone: '+919876543210',
        firstName: 'Raj',
        lastName: 'Sharma',
        prefs: prefs,
      );
      final tenantId = prefs.getTenantConfig()!.tenantId;
      await auth.createBuilding(
        tenantId: tenantId,
        name: 'Demo Building',
        structure: const TenantStructure(),
        prefs: prefs,
      );
      final profile = await auth.getCurrentUser();
      expect(profile!.onboardingComplete, isTrue);
      expect(profile.isTenantOwner, isTrue);
      expect(profile.tenantId, tenantId);
      expect(prefs.getTenantConfig()?.name, 'Demo Building');
    });

    test('join as admin with valid invite code', () async {
      await seedOwnerTenant();
      await auth.signOut();
      auth = MockAuthService(prefs: prefs);
      await auth.initialize();
      await auth.signInWithGoogle();
      final profile = await auth.joinAsAdmin(
        inviteCode: MockAuthService.mockAdminInviteCode,
        prefs: prefs,
      );
      expect(profile.onboardingComplete, isTrue);
      expect(profile.isTenantOwner, isFalse);
      expect(profile.tenantId, prefs.getTenantConfig()?.tenantId);
    });

    test('join rejects invalid invite code', () async {
      await seedOwnerTenant();
      await auth.signOut();
      auth = MockAuthService(prefs: prefs);
      await auth.initialize();
      await auth.signInWithGoogle();
      expect(
        () => auth.joinAsAdmin(inviteCode: 'BAD-CODE', prefs: prefs),
        throwsA(isA<TenantJoinException>()),
      );
    });
  });
}
