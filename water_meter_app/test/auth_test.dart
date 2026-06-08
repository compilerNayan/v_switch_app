import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/auth/mock_auth_service.dart';
import 'package:water_meter_app/core/models/tenant_config.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';

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
      final result = await auth.signUp(
        email: 'owner@example.com',
        password: 'password123',
        firstName: 'Raj',
        lastName: 'Sharma',
        phone: '+919876543210',
      );
      expect(result.requiresConfirmation, isTrue);

      await auth.confirmSignUp(
        email: 'owner@example.com',
        code: MockAuthService.mockConfirmCode,
      );

      final profile = await auth.signInWithPassword(
        email: 'owner@example.com',
        password: 'password123',
      );
      expect(profile.onboardingComplete, isFalse);
      expect(profile.tenantId, isNull);
      expect(profile.firstName, 'Raj');
    });

    test('register user creates tenant for owner', () async {
      await auth.signUp(
        email: 'owner@example.com',
        password: 'password123',
        firstName: 'Raj',
        lastName: 'Sharma',
        phone: '+919876543210',
      );
      await auth.confirmSignUp(
        email: 'owner@example.com',
        code: MockAuthService.mockConfirmCode,
      );
      await auth.signInWithPassword(
        email: 'owner@example.com',
        password: 'password123',
      );

      final profile = await auth.registerUser(
        email: 'owner@example.com',
        phone: '+919876543210',
        firstName: 'Raj',
        lastName: 'Sharma',
        tenantName: 'Sunrise Apartments',
        prefs: prefs,
      );

      expect(profile.onboardingComplete, isTrue);
      expect(profile.isTenantOwner, isTrue);
      expect(profile.tenantId, isNotNull);
      expect(prefs.getTenantConfig()?.name, 'Sunrise Apartments');
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

    test('create tenant flow', () async {
      await auth.signInWithGoogle();
      final profile = await auth.createTenant(
        name: 'Demo Building',
        structure: const TenantStructure(
          blocks: [TenantBlock(id: 'A', label: 'Tower A', wings: ['East'])],
        ),
        prefs: prefs,
      );
      expect(profile.onboardingComplete, isTrue);
      expect(profile.isTenantOwner, isTrue);
      expect(profile.tenantId, isNotNull);
      expect(prefs.getTenantConfig()?.name, 'Demo Building');
    });

    test('join as admin with valid invite code', () async {
      await auth.signInWithGoogle();
      await auth.createTenant(
        name: 'Demo Building',
        structure: const TenantStructure(),
        prefs: prefs,
      );
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
      expect(profile.tenantId, isNotNull);
    });

    test('join rejects invalid invite code', () async {
      await auth.signInWithGoogle();
      await auth.createTenant(
        name: 'Demo Building',
        structure: const TenantStructure(),
        prefs: prefs,
      );
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
