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
      expect(OnboardingRouter.redirectForProfile(null, '/auth/confirm'), isNull);
    });

    test('redirects owner with pending building setup', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
        tenantId: 'tenant-1',
        onboardingComplete: false,
        isTenantOwner: true,
      );
      expect(
        OnboardingRouter.redirectForProfile(profile, '/'),
        '/onboarding/building-setup',
      );
      expect(
        OnboardingRouter.redirectForProfile(
          profile,
          '/onboarding/building-setup',
        ),
        isNull,
      );
    });

    test('redirects onboarded owner away from auth routes', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
        tenantId: 'tenant-1',
        onboardingComplete: true,
        isTenantOwner: true,
      );
      expect(OnboardingRouter.redirectForProfile(profile, '/auth'), '/');
      expect(OnboardingRouter.redirectForProfile(profile, '/'), isNull);
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

    test('redirects new user without tenant to admin invite by default', () {
      const profile = UserProfile(
        userId: 'u1',
        email: 'a@b.com',
        displayName: 'User',
      );
      expect(
        OnboardingRouter.redirectForProfile(profile, '/'),
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
