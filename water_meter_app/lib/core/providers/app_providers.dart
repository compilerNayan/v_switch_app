import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/dio_water_api_client.dart';
import '../api/mock_water_api_client.dart';
import '../api/water_api_client.dart';
import '../config/app_config.dart';
import '../storage/credentials_storage.dart';
import '../storage/preferences_storage.dart';
import '../utils/units.dart';

final credentialsStorageProvider = Provider<CredentialsStorage>(
  (ref) => CredentialsStorage(),
);

final preferencesStorageProvider = FutureProvider<PreferencesStorage>(
  (ref) => PreferencesStorage.create(),
);

final authStateProvider = FutureProvider<({String deviceId, String apiKey})?>(
  (ref) async {
    return ref.watch(credentialsStorageProvider).read();
  },
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
    return MockWaterApiClient();
  }
  final storage = ref.watch(credentialsStorageProvider);
  return DioWaterApiClient(
    credentialsProvider: () => storage.read(),
  );
});

final deviceIdProvider = Provider<String>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.maybeWhen(
    data: (creds) => creds?.deviceId ?? 'WM-DEMO',
    orElse: () => 'WM-DEMO',
  );
});
