import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_water_api_client.dart';
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

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  await ref.watch(authInitProvider.future);
  final auth = ref.watch(authServiceProvider);
  final token = await auth.getIdToken();
  if (token == null) return null;

  if (AppConfig.useMockAuth) {
    return auth.getCurrentUser();
  }

  final client = ref.watch(tenantApiClientProvider);
  try {
    return await client.getMe();
  } on ApiException catch (e) {
    if (e.statusCode == 404) {
      return auth.getCurrentUser();
    }
    rethrow;
  }
});

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

final waterApiClientProvider = Provider<WaterApiClient>((ref) {
  if (AppConfig.useMockApi) {
    final auth = ref.watch(authServiceProvider);
    return MockWaterApiClient(
      canManageQuota: () async {
        final profile = await auth.getCurrentUser();
        return profile?.onboardingComplete == true && profile?.tenantId != null;
      },
    );
  }
  final auth = ref.watch(authServiceProvider);
  return DioWaterApiClient(
    credentialsProvider: () async {
      final token = await auth.getIdToken();
      if (token == null) return null;
      return (deviceId: '', apiKey: token);
    },
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
