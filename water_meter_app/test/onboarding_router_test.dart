import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/user_profile.dart';
import 'package:water_meter_app/core/utils/onboarding_router.dart';

void main() {
  group('OnboardingRouter', () {
    test('redirects unauthenticated users to /auth', () {
      expect(OnboardingRouter.redirectForProfile(null, '/'), '/auth');
      expect(OnboardingRouter.redirectForProfile(null, '/devices/add'), '/auth');
    });

    test('allows /auth when not authenticated', () {
      expect(OnboardingRouter.redirectForProfile(null, '/auth'), isNull);
    });

    test('redirects new user to tenant setup when no tenant exists', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
      );
      expect(
        OnboardingRouter.redirectForProfile(profile, '/'),
        '/onboarding/tenant-setup',
      );
    });

    test('redirects new user to admin invite when tenant exists', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
      );
      expect(
        OnboardingRouter.redirectForProfile(
          profile,
          '/',
          tenantExists: true,
        ),
        '/onboarding/admin-invite',
      );
    });

    test('allows building home when onboarding complete', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
        tenantId: 'tenant-1',
        onboardingComplete: true,
      );
      expect(OnboardingRouter.redirectForProfile(profile, '/'), isNull);
      expect(
        OnboardingRouter.redirectForProfile(profile, '/devices/add'),
        isNull,
      );
      expect(
        OnboardingRouter.redirectForProfile(profile, '/auth'),
        '/',
      );
    });
  });
}
