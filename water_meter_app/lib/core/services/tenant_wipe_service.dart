import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exceptions.dart';
import '../api/tenant_api_client.dart';
import '../auth/auth_service.dart';
import '../models/user_profile.dart';
import '../providers/app_providers.dart';
import '../providers/dashboard_providers.dart';
import '../providers/unit_providers.dart';
import '../storage/preferences_storage.dart';
import '../storage/session_storage.dart';

final tenantWipeServiceProvider = Provider<TenantWipeService>((ref) {
  return TenantWipeService(
    tenantApiClient: ref.watch(tenantApiClientProvider),
    authService: ref.watch(authServiceProvider),
    prefsProvider: () => ref.read(preferencesStorageProvider.future),
    invalidateProfile: () => ref.invalidate(userProfileProvider),
    invalidateUnits: () => ref.invalidate(waterUnitsProvider),
    invalidateHome: () => ref.invalidate(homeSnapshotProvider),
  );
});

class TenantWipeService {
  TenantWipeService({
    required TenantApiClient tenantApiClient,
    required AuthService authService,
    required Future<PreferencesStorage> Function() prefsProvider,
    required void Function() invalidateProfile,
    required void Function() invalidateUnits,
    required void Function() invalidateHome,
  })  : _tenantApiClient = tenantApiClient,
        _authService = authService,
        _prefsProvider = prefsProvider,
        _invalidateProfile = invalidateProfile,
        _invalidateUnits = invalidateUnits,
        _invalidateHome = invalidateHome;

  final TenantApiClient _tenantApiClient;
  final AuthService _authService;
  final Future<PreferencesStorage> Function() _prefsProvider;
  final void Function() _invalidateProfile;
  final void Function() _invalidateUnits;
  final void Function() _invalidateHome;

  void ensureCanWipe(UserProfile? profile) {
    if (profile == null || !profile.isAuthenticated) {
      throw const ApiException(
        statusCode: 401,
        error: ApiError(
          code: 'UNAUTHORIZED',
          message: 'Sign in to continue.',
        ),
      );
    }
    final tenantId = profile.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      throw const ApiException(
        statusCode: 400,
        error: ApiError(
          code: 'NO_TENANT',
          message: 'No tenant is linked to this account.',
        ),
      );
    }
    if (!profile.isTenantOwner) {
      throw const ApiException(
        statusCode: 403,
        error: ApiError(
          code: 'FORBIDDEN',
          message: 'Only the building owner can wipe this tenant.',
        ),
      );
    }
  }

  Future<void> wipeTenant(UserProfile profile) async {
    ensureCanWipe(profile);
    final tenantId = profile.tenantId!;

    await _tenantApiClient.deleteTenant(tenantId);

    final prefs = await _prefsProvider();
    await prefs.clearAccountData(tenantId: tenantId);
    await SessionStorage().clear();
    try {
      await _authService.signOut();
    } catch (_) {
      // Cognito user may already be deleted by the backend.
    }

    _invalidateProfile();
    _invalidateUnits();
    _invalidateHome();
  }
}
