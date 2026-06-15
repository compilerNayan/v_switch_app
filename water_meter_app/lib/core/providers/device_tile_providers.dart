import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/valve_actions.dart';
import '../config/app_config.dart';
import '../models/current_reading.dart';
import '../models/device_health.dart';
import '../models/quota_config.dart';
import '../models/usage_response.dart';
import '../models/valve_state.dart';
import '../utils/granularity.dart';
import '../utils/valve_pressure.dart';
import 'app_providers.dart';
import 'dashboard_providers.dart';
import 'valve_patches_provider.dart';

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

Future<ValveState> setDeviceValveForId(
  WidgetRef ref,
  String deviceId, {
  required bool turnOn,
  bool forceOff = false,
}) async {
  final client = ref.read(waterApiClientProvider);
  final prefs = await ref.read(preferencesStorageProvider.future);
  final telemetry = ref.read(deviceHomeTelemetryProvider(deviceId));
  final cachedPressure = prefs.getValveLastPressure(deviceId);

  ValveState? current;
  if (!AppConfig.useMockApi && telemetry != null) {
    current = ValveState(
      deviceId: deviceId,
      timestamp: DateTime.now().toUtc(),
      targetPressurePercent: telemetry.valveOpenPercent,
      actualPressurePercent: telemetry.valveOpenPercent,
      lastUserPressurePercent: cachedPressure,
      isOff: telemetry.valveIsOff,
      controlMode: ValveControlMode.manual,
      effectivePressurePercent: telemetry.valveOpenPercent,
    );
  } else {
    current = await ref.read(deviceValveProvider(deviceId).future);
  }

  final shouldTurnOn = forceOff ? false : turnOn;
  final valvePatches = ref.read(valvePatchesProvider.notifier);

  if (shouldTurnOn) {
    final restorePercent = resolveRestorePressurePercent(
      cachedPressure: cachedPressure,
      current: current,
      telemetryOpenPercent: telemetry?.valveOpenPercent,
      telemetryIsOff: telemetry?.valveIsOff,
    );
    valvePatches.apply(
      deviceId,
      isOff: false,
      openPercent: restorePercent,
    );
    try {
      final updated = await setDeviceValvePressure(
        client,
        deviceId,
        restorePercent,
      );
      await prefs.setValveLastPressure(deviceId, restorePercent);
      ref.invalidate(deviceValveProvider(deviceId));
      return updated;
    } catch (error) {
      valvePatches.clear(deviceId);
      rethrow;
    }
  }

  final offPressure = pressureBeforeTurningOff(
    current: current,
    telemetryOpenPercent: telemetry?.valveOpenPercent,
    telemetryIsOff: telemetry?.valveIsOff,
    cachedPressure: cachedPressure,
  );
  await prefs.setValveLastPressure(deviceId, offPressure);
  valvePatches.apply(deviceId, isOff: true, openPercent: 0);
  try {
    final updated = await setDeviceValvePressure(client, deviceId, 0);
    ref.invalidate(deviceValveProvider(deviceId));
    return updated;
  } catch (error) {
    valvePatches.clear(deviceId);
    rethrow;
  }
}

Future<ValveState> toggleDeviceValveForId(
  WidgetRef ref,
  String deviceId, {
  bool forceOff = false,
  bool? turnOn,
}) async {
  if (turnOn != null) {
    return setDeviceValveForId(ref, deviceId, turnOn: turnOn, forceOff: forceOff);
  }

  final telemetry = ref.read(deviceHomeTelemetryProvider(deviceId));
  final isOff = telemetry?.valveIsOff ??
      (await ref.read(deviceValveProvider(deviceId).future)).isOff;
  return setDeviceValveForId(ref, deviceId, turnOn: isOff, forceOff: forceOff);
}
