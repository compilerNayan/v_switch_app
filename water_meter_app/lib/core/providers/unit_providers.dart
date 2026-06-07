import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/water_unit.dart';
import 'app_providers.dart';

/// Route param `:deviceId` (WaterUnit.id). Set while a unit shell route is active.
final selectedRouteDeviceIdProvider = StateProvider<String?>((ref) => null);

final waterUnitsProvider = FutureProvider<List<WaterUnit>>((ref) async {
  final prefs = await ref.watch(preferencesStorageProvider.future);
  return prefs.getWaterUnits();
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
