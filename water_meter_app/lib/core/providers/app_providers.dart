import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_water_api_client.dart';
import '../api/mock_water_api_client.dart';
import '../api/tenant_api_client.dart';
import '../api/water_api_client.dart';
import '../auth/amplify_auth_service.dart';
import '../auth/auth_service.dart';
import '../auth/mock_auth_service.dart';
import '../config/app_config.dart';
import '../models/user_profile.dart';
import '../storage/preferences_storage.dart';
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
  return auth.getCurrentUser();
});

final tenantApiClientProvider = Provider<TenantApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return TenantApiClient(authService: auth);
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

final waterApiClientProvider = Provider<WaterApiClient>((ref) {
  if (AppConfig.useMockApi) {
    final auth = ref.watch(authServiceProvider);
    return MockWaterApiClient(
      canManageQuota: () async {
        final profile = await auth.getCurrentUser();
        return profile?.role == UserRole.admin;
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
