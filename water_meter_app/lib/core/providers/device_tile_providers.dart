import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/valve_actions.dart';
import '../models/current_reading.dart';
import '../models/device_health.dart';
import '../models/quota_config.dart';
import '../models/usage_response.dart';
import '../models/valve_state.dart';
import '../utils/granularity.dart';
import 'app_providers.dart';

final deviceCurrentReadingProvider = FutureProvider.autoDispose
    .family<CurrentReading, String>((ref, deviceId) async {
  final client = ref.watch(waterApiClientProvider);
  return client.getCurrentReading(deviceId);
});

final deviceTodayUsageProvider =
    FutureProvider.autoDispose.family<double, String>((ref, deviceId) async {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final client = ref.watch(waterApiClientProvider);
  final timezone = ref.watch(timezoneProvider);
  final usage = await client.getUsage(
    deviceId: deviceId,
    from: startOfToday,
    to: now,
    granularity: Granularity.h1,
    timezone: timezone,
  );
  return usage.summary.totalVolumeLiters;
});

final deviceQuotaProvider =
    FutureProvider.autoDispose.family<QuotaResponse, String>((ref, deviceId) async {
  final client = ref.watch(waterApiClientProvider);
  return client.getQuota(deviceId);
});

final deviceValveProvider =
    FutureProvider.autoDispose.family<ValveState, String>((ref, deviceId) async {
  final client = ref.watch(waterApiClientProvider);
  return client.getValveState(deviceId);
});

final deviceHealthProvider =
    FutureProvider.autoDispose.family<DeviceHealth, String>((ref, deviceId) async {
  final reading = await ref.watch(deviceCurrentReadingProvider(deviceId).future);
  return DeviceHealth.fromReading(
    unitId: deviceId,
    readingTimestamp: reading.timestamp.toLocal(),
  );
});

Future<ValveState> toggleDeviceValveForId(
  WidgetRef ref,
  String deviceId, {
  bool forceOff = false,
}) async {
  final client = ref.read(waterApiClientProvider);
  final current = await ref.read(deviceValveProvider(deviceId).future);
  final updated = forceOff
      ? await setDeviceValvePressure(client, deviceId, 0)
      : await toggleDeviceValve(client, deviceId, current);
  ref.invalidate(deviceValveProvider(deviceId));
  return updated;
}
