import '../models/user_profile.dart';

/// Determines the next onboarding route for an authenticated user.
class OnboardingRouter {
  OnboardingRouter._();

  static String? redirectForProfile(UserProfile? profile, String location) {
    if (profile == null || !profile.isAuthenticated) {
      return location == '/auth' ? null : '/auth';
    }

    final authRoutes = {'/auth'};
    final onboardingRoutes = {'/onboarding/role', '/onboarding/join'};

    if (profile.onboardingComplete) {
      if (authRoutes.contains(location) || onboardingRoutes.contains(location)) {
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
