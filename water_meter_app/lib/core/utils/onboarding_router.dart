import '../models/user_profile.dart';

/// Determines the next onboarding route for an authenticated user.
class OnboardingRouter {
  OnboardingRouter._();

  static const deviceOnboardingRoute = '/onboarding/devices';

  static String? redirectForProfile(
    UserProfile? profile,
    String location, {
    bool deviceOnboardingComplete = false,
  }) {
    if (profile == null || !profile.isAuthenticated) {
      return location == '/auth' ? null : '/auth';
    }

    final authRoutes = {'/auth'};
    final tenantOnboardingRoutes = {'/onboarding/role', '/onboarding/join'};
    final allOnboardingRoutes = {
      ...tenantOnboardingRoutes,
      deviceOnboardingRoute,
    };

    if (profile.onboardingComplete) {
      if (!deviceOnboardingComplete) {
        if (location == deviceOnboardingRoute) return null;
        return deviceOnboardingRoute;
      }

      if (authRoutes.contains(location) || allOnboardingRoutes.contains(location)) {
        return '/';
      }
      return null;
    }

    if (profile.needsRoleSelection) {
      return location == '/onboarding/role' ? null : '/onboarding/role';
    }

    if (profile.needsTenantJoin) {
      return location == '/onboarding/join' ? null : '/onboarding/join';
    }

    if (profile.needsTenantCreation) {
      // Admin tenant creation is handled automatically on role screen
      return location == '/onboarding/role' ? null : '/onboarding/role';
    }

    return null;
  }
}
