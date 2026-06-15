import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/building_api_client.dart';
import '../api/dio_building_api_client.dart';
import '../api/dio_water_api_client.dart';
import '../api/mock_building_api_client.dart';
import '../api/mock_water_api_client.dart';
import '../api/tenant_api_client.dart';
import '../api/water_api_client.dart';
import '../api/api_exceptions.dart';
import '../auth/amplify_auth_service.dart';
import '../auth/auth_service.dart';
import '../auth/mock_auth_service.dart';
import '../auth/pending_registration.dart';
import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../storage/preferences_storage.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  if (AppConfig.useMockAuth) {
    return MockAuthService();
  }
  return AmplifyAuthService();
});

final authInitProvider = FutureProvider<void>((ref) async {
  final auth = ref.read(authServiceProvider);
  await auth.initialize();
});

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
  UserProfileNotifier.new,
);

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    await ref.watch(authInitProvider.future);
    final auth = ref.watch(authServiceProvider);
    final token = await auth.getIdToken();
    if (token == null) {
      final prefs = await ref.watch(preferencesStorageProvider.future);
      await prefs.setCachedUserProfile(null);
      return null;
    }

    if (AppConfig.useMockAuth) {
      return auth.getCurrentUser();
    }

    final prefs = await ref.watch(preferencesStorageProvider.future);
    final cached = prefs.getCachedUserProfile();
    if (cached != null) {
      Future.microtask(() => refresh());
      return cached;
    }

    final cognitoProfile = await auth.getCurrentUser();
    if (cognitoProfile != null) {
      Future.microtask(() => refresh());
      return cognitoProfile;
    }

    return _fetchAndCache();
  }

  Future<void> refresh() async {
    if (!state.hasValue) {
      state = const AsyncLoading<UserProfile?>();
    } else {
      state = const AsyncLoading<UserProfile?>().copyWithPrevious(state);
    }
    state = await AsyncValue.guard(_fetchAndCache);
  }

  Future<UserProfile?> _fetchAndCache() async {
    final auth = ref.read(authServiceProvider);
    final client = ref.read(tenantApiClientProvider);
    final prefs = await ref.read(preferencesStorageProvider.future);

    try {
      final profile = await client.getMe();
      await prefs.setCachedUserProfile(profile);
      return profile;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        final profile = await auth.getCurrentUser();
        if (profile != null) {
          await prefs.setCachedUserProfile(profile);
        }
        return profile;
      }
      rethrow;
    }
  }
}

final pendingRegistrationProvider =
    StateProvider<PendingRegistration?>((ref) => null);

final tenantApiClientProvider = Provider<TenantApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return TenantApiClient(
    authService: auth,
    prefsProvider: () => ref.read(preferencesStorageProvider.future),
  );
});

final preferencesStorageProvider = FutureProvider<PreferencesStorage>(
  (ref) => PreferencesStorage.create(),
);

final volumeUnitProvider = StateProvider<VolumeUnit>((ref) {
  final prefsAsync = ref.watch(preferencesStorageProvider);
  return prefsAsync.maybeWhen(
    data: (prefs) => prefs.volumeUnit,
    orElse: () => VolumeUnit.liters,
  );
});

final timezoneProvider = StateProvider<String>((ref) {
  final prefsAsync = ref.watch(preferencesStorageProvider);
  return prefsAsync.maybeWhen(
    data: (prefs) => prefs.timezone,
    orElse: () => DateTime.now().timeZoneName,
  );
});

final appThemeIdProvider = StateProvider<AppThemeId>((ref) {
  final prefsAsync = ref.watch(preferencesStorageProvider);
  return prefsAsync.maybeWhen(
    data: (prefs) => prefs.appThemeId,
    orElse: () => AppThemeId.ocean,
  );
});

final appThemeProvider = Provider<ThemeData>((ref) {
  final themeId = ref.watch(appThemeIdProvider);
  return AppTheme.themeFor(themeId);
});

Future<String?> _tenantIdForRef(Ref ref) async {
  final profile = ref.read(userProfileProvider).valueOrNull;
  if (profile?.tenantId != null) return profile!.tenantId;
  return ref.read(userProfileProvider.future).then((p) => p?.tenantId);
}

final buildingApiClientProvider = Provider<BuildingApiClient>((ref) {
  if (AppConfig.useMockApi) {
    return MockBuildingApiClient(ref);
  }
  final auth = ref.watch(authServiceProvider);
  return DioBuildingApiClient(
    authTokenProvider: () => auth.getIdToken(),
  );
});

final waterApiClientProvider = Provider<WaterApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);

  if (AppConfig.useMockApi) {
    return MockWaterApiClient(
      canManageQuota: () async {
        final profile = await auth.getCurrentUser();
        return profile?.onboardingComplete == true && profile?.tenantId != null;
      },
    );
  }

  return DioWaterApiClient(
    credentialsProvider: () async {
      final token = await auth.getIdToken();
      if (token == null) return null;
      return (deviceId: '', apiKey: token);
    },
    tenantIdProvider: () => _tenantIdForRef(ref),
  );
});

class AuthListenable extends ChangeNotifier {
  AuthListenable(this.ref) {
    ref.listen(userProfileProvider, (_, __) => notifyListeners());
  }

  final Ref ref;
}

final authListenableProvider = Provider<AuthListenable>((ref) {
  final listenable = AuthListenable(ref);
  ref.onDispose(listenable.dispose);
  return listenable;
});
