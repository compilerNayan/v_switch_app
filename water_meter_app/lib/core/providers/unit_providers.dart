import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/water_unit.dart';
import 'app_providers.dart';
import 'dashboard_providers.dart';

/// Route param `:deviceId` (WaterUnit.id). Set while a unit shell route is active.
final selectedRouteDeviceIdProvider = StateProvider<String?>((ref) => null);

final waterUnitsProvider = FutureProvider<List<WaterUnit>>((ref) async {
  if (AppConfig.useMockApi) {
    final prefs = await ref.watch(preferencesStorageProvider.future);
    return prefs.getWaterUnits();
  }

  try {
    final snapshot = await ref.watch(homeSnapshotProvider.future);
    if (snapshot != null) {
      return snapshot.metadata.devices.map((d) => d.toWaterUnit()).toList();
    }
  } catch (_) {}

  final profile = await ref.watch(userProfileProvider.future);
  final tenantId = profile?.tenantId;
  if (tenantId == null || tenantId.isEmpty) {
    return [];
  }

  final client = ref.watch(tenantApiClientProvider);
  return client.listUnits(tenantId);
});

/// Legacy alias
final userDevicesProvider = waterUnitsProvider;

final activeWaterUnitProvider = Provider<WaterUnit?>((ref) {
  final routeId = ref.watch(selectedRouteDeviceIdProvider);
  if (routeId == null) return null;
  final unitsAsync = ref.watch(waterUnitsProvider);
  return unitsAsync.maybeWhen(
    data: (units) {
      for (final unit in units) {
        if (unit.id == routeId) return unit;
      }
      return null;
    },
    orElse: () => null,
  );
});

final activeUserDeviceProvider = activeWaterUnitProvider;

final activeDeviceApiIdProvider = Provider<String>((ref) {
  final unit = ref.watch(activeWaterUnitProvider);
  if (unit != null) return unit.deviceId;
  return 'WM-DEMO';
});
