import '../models/user_profile.dart';

/// Determines the next onboarding route for an authenticated user.
class OnboardingRouter {
  OnboardingRouter._();

  static const tenantOnboardingRoutes = {
    '/onboarding/dummy-devices',
    '/onboarding/dummy-devices/count',
    '/onboarding/dummy-devices/provision',
    '/onboarding/building-setup',
    '/onboarding/admin-invite',
  };

  static String? redirectForProfile(
    UserProfile? profile,
    String location, {
    bool tenantExists = false,
  }) {
    if (profile == null || !profile.isAuthenticated) {
      return location == '/auth' || location == '/auth/confirm'
          ? null
          : '/auth';
    }

    const authRoutes = {'/auth', '/auth/confirm'};

    if (profile.tenantId != null &&
        profile.isTenantOwner &&
        !profile.onboardingComplete) {
      if (tenantOnboardingRoutes.contains(location)) {
        return null;
      }
      return '/onboarding/dummy-devices';
    }

    if (profile.onboardingComplete && profile.tenantId != null) {
      if (authRoutes.contains(location) ||
          tenantOnboardingRoutes.contains(location)) {
        return '/';
      }
      return null;
    }

    if (tenantExists) {
      return location == '/onboarding/admin-invite'
          ? null
          : '/onboarding/admin-invite';
    }

    return location == '/onboarding/admin-invite'
        ? null
        : '/onboarding/admin-invite';
  }
}
