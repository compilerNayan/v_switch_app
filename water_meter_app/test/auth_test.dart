import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/auth/mock_auth_service.dart';
import 'package:water_meter_app/core/models/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('MockAuthService tenant flow', () {
    late MockAuthService auth;

    setUp(() async {
      auth = MockAuthService();
      await auth.initialize();
    });

    test('sign in creates unboarded profile', () async {
      final profile = await auth.signInWithGoogle();
      expect(profile.onboardingComplete, isFalse);
      expect(profile.role, isNull);
    });

    test('admin flow creates tenant', () async {
      await auth.signInWithGoogle();
      await auth.setRole(UserRole.admin);
      final profile = await auth.createTenant();
      expect(profile.role, UserRole.admin);
      expect(profile.tenantId, isNotNull);
      expect(profile.inviteCode, MockAuthService.mockInviteCode);
      expect(profile.onboardingComplete, isTrue);
    });

    test('readonly join with valid invite code', () async {
      await auth.signInWithGoogle();
      await auth.setRole(UserRole.readonly);
      final profile = await auth.joinTenant(MockAuthService.mockInviteCode);
      expect(profile.role, UserRole.readonly);
      expect(profile.tenantId, isNotNull);
      expect(profile.onboardingComplete, isTrue);
    });

    test('readonly join rejects invalid invite code', () async {
      await auth.signInWithGoogle();
      await auth.setRole(UserRole.readonly);
      expect(
        () => auth.joinTenant('BAD-CODE'),
        throwsA(isA<TenantJoinException>()),
      );
    });
  });
}
