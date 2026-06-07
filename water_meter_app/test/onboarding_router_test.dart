import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/user_profile.dart';
import 'package:water_meter_app/core/utils/onboarding_router.dart';

void main() {
  group('OnboardingRouter', () {
    test('redirects unauthenticated users to /auth', () {
      expect(OnboardingRouter.redirectForProfile(null, '/'), '/auth');
      expect(OnboardingRouter.redirectForProfile(null, '/usage'), '/auth');
    });

    test('allows /auth when not authenticated', () {
      expect(OnboardingRouter.redirectForProfile(null, '/auth'), isNull);
    });

    test('redirects authenticated user without role to role selection', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
      );
      expect(
        OnboardingRouter.redirectForProfile(profile, '/'),
        '/onboarding/role',
      );
    });

    test('redirects readonly user without tenant to join screen', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
        role: UserRole.readonly,
      );
      expect(
        OnboardingRouter.redirectForProfile(profile, '/'),
        '/onboarding/join',
      );
    });

    test('allows main app when onboarding complete', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
        role: UserRole.admin,
        tenantId: 'tenant-1',
        onboardingComplete: true,
      );
      expect(OnboardingRouter.redirectForProfile(profile, '/'), isNull);
      expect(
        OnboardingRouter.redirectForProfile(profile, '/auth'),
        '/',
      );
    });
  });
}
