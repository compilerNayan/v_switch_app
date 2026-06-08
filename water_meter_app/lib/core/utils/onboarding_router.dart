import '../models/user_profile.dart';

/// Determines the next onboarding route for an authenticated user.
class OnboardingRouter {
  OnboardingRouter._();

  static String? redirectForProfile(
    UserProfile? profile,
    String location, {
    bool tenantExists = false,
  }) {
    if (profile == null || !profile.isAuthenticated) {
      return location == '/auth' ? null : '/auth';
    }

    const authRoutes = {'/auth'};
    const tenantOnboardingRoutes = {
      '/onboarding/tenant-setup',
      '/onboarding/admin-invite',
    };

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

    return location == '/onboarding/tenant-setup'
        ? null
        : '/onboarding/tenant-setup';
  }
}
