import '../models/user_profile.dart';

/// Determines the next onboarding route for an authenticated user.
class OnboardingRouter {
  OnboardingRouter._();

  static String? redirectForProfile(UserProfile? profile, String location) {
    if (profile == null || !profile.isAuthenticated) {
      return location == '/auth' ? null : '/auth';
    }

    final authRoutes = {'/auth'};
    final tenantOnboardingRoutes = {'/onboarding/role', '/onboarding/join'};

    if (profile.onboardingComplete) {
      if (authRoutes.contains(location) || tenantOnboardingRoutes.contains(location)) {
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
      return location == '/onboarding/role' ? null : '/onboarding/role';
    }

    return null;
  }
}
