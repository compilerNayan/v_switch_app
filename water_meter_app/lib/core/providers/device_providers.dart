import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/iot_device_type.dart';
import '../models/user_device.dart';
import 'app_providers.dart';

/// Route param `:deviceId` (UserDevice.id). Overridden inside device shell routes.
final selectedRouteDeviceIdProvider = Provider<String>((ref) {
  throw StateError('selectedRouteDeviceIdProvider must be overridden in device routes');
});

final userDevicesProvider = FutureProvider<List<UserDevice>>((ref) async {
  final prefs = await ref.watch(preferencesStorageProvider.future);
  return prefs.getUserDevices();
});

final activeUserDeviceProvider = Provider<UserDevice?>((ref) {
  final routeId = ref.watch(selectedRouteDeviceIdProvider);
  final devicesAsync = ref.watch(userDevicesProvider);
  return devicesAsync.maybeWhen(
    data: (devices) {
      for (final device in devices) {
        if (device.id == routeId) return device;
      }
      return null;
    },
    orElse: () => null,
  );
});

final activeDeviceApiIdProvider = Provider<String>((ref) {
  final device = ref.watch(activeUserDeviceProvider);
  if (device != null) return device.deviceId;
  return 'WM-DEMO';
});

IoTDeviceType? iconForDeviceType(String typeId) {
  for (final type in IoTDeviceType.catalog) {
    if (type.id == typeId) return type;
  }
  return null;
}
