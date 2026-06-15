import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../live/live_update_message.dart';
import '../models/home_dashboard.dart';

/// How long to keep showing the last live flow reading after updates stop.
const Duration liveFlowStaleAfter = Duration(seconds: 3);

/// Ephemeral per-device telemetry overlay from WebSocket `water_flow_tick` events.
final liveTelemetryPatchesProvider =
    NotifierProvider<LiveTelemetryPatchesNotifier, Map<String, LiveTelemetryPatch>>(
  LiveTelemetryPatchesNotifier.new,
);

class LiveTelemetryPatch {
  const LiveTelemetryPatch({
    required this.flowRateLpm,
    required this.status,
    required this.isOnline,
    required this.lastSeenAt,
    this.cumulativeLiters,
  });

  final double flowRateLpm;
  final String status;
  final bool isOnline;
  final String lastSeenAt;
  final double? cumulativeLiters;

  @override
  bool operator ==(Object other) {
    return other is LiveTelemetryPatch &&
        other.flowRateLpm == flowRateLpm &&
        other.status == status &&
        other.isOnline == isOnline &&
        other.lastSeenAt == lastSeenAt &&
        other.cumulativeLiters == cumulativeLiters;
  }

  @override
  int get hashCode =>
      Object.hash(flowRateLpm, status, isOnline, lastSeenAt, cumulativeLiters);
}

class LiveTelemetryPatchesNotifier
    extends Notifier<Map<String, LiveTelemetryPatch>> {
  final Map<String, Timer> _staleTimers = {};

  @override
  Map<String, LiveTelemetryPatch> build() {
    ref.onDispose(_cancelAllTimers);
    return const {};
  }

  void applyWaterFlow(LiveUpdateWaterFlow event) {
    _applyDeviceFlow(
      deviceId: event.deviceId,
      flowRateLpm: event.flowRateLpm,
      status: event.status,
      ts: event.ts,
      cumulativeLiters: event.cumulativeLiters,
    );
  }

  void applyWaterFlowTick(LiveUpdateWaterFlowTick event) {
    if (event.devices.isEmpty) return;

    final next = Map<String, LiveTelemetryPatch>.from(state);
    for (final device in event.devices) {
      final key = normalizeDeviceId(device.deviceId);
      _scheduleStaleTimer(key);
      next[key] = LiveTelemetryPatch(
        flowRateLpm: device.flowRateLpm,
        status: device.status,
        isOnline: true,
        lastSeenAt: device.ts,
        cumulativeLiters: device.cumulativeLiters,
      );
    }
    state = next;
  }

  void _applyDeviceFlow({
    required String deviceId,
    required double flowRateLpm,
    required String status,
    required String ts,
    double? cumulativeLiters,
  }) {
    final key = normalizeDeviceId(deviceId);
    _scheduleStaleTimer(key);
    final next = Map<String, LiveTelemetryPatch>.from(state);
    next[key] = LiveTelemetryPatch(
      flowRateLpm: flowRateLpm,
      status: status,
      isOnline: true,
      lastSeenAt: ts,
      cumulativeLiters: cumulativeLiters,
    );
    state = next;
  }

  void applyDevicePresence(LiveUpdateDevicePresence event) {
    final key = normalizeDeviceId(event.deviceId);
    final existing = state[key];
    final next = Map<String, LiveTelemetryPatch>.from(state);
    next[key] = LiveTelemetryPatch(
      flowRateLpm: existing?.flowRateLpm ?? 0,
      status: event.isOnline
          ? (existing?.status ?? 'idle')
          : 'offline',
      isOnline: event.isOnline,
      lastSeenAt: event.ts,
      cumulativeLiters: existing?.cumulativeLiters,
    );
    state = next;
    if (!event.isOnline) {
      _cancelTimer(key);
    }
  }

  void clear() {
    _cancelAllTimers();
    state = const {};
  }

  void clearDevice(String deviceId) {
    final key = normalizeDeviceId(deviceId);
    _cancelTimer(key);
    if (!state.containsKey(key)) return;
    final next = Map<String, LiveTelemetryPatch>.from(state);
    next.remove(key);
    state = next;
  }

  void _scheduleStaleTimer(String key) {
    _cancelTimer(key);
    _staleTimers[key] = Timer(liveFlowStaleAfter, () => _expireFlow(key));
  }

  void _expireFlow(String key) {
    _staleTimers.remove(key);
    final existing = state[key];
    if (existing == null) return;
    if (existing.flowRateLpm == 0 && existing.status == 'idle') return;

    final next = Map<String, LiveTelemetryPatch>.from(state);
    next[key] = LiveTelemetryPatch(
      flowRateLpm: 0,
      status: 'idle',
      isOnline: existing.isOnline,
      lastSeenAt: existing.lastSeenAt,
      cumulativeLiters: existing.cumulativeLiters,
    );
    state = next;
  }

  void _cancelTimer(String key) {
    _staleTimers.remove(key)?.cancel();
  }

  void _cancelAllTimers() {
    for (final timer in _staleTimers.values) {
      timer.cancel();
    }
    _staleTimers.clear();
  }
}

/// Live meter reading from WebSocket; cleared on authoritative `bucket_30m`.
final deviceLiveMeterReadingProvider =
    Provider.family<DeviceMeterReading?, String>((ref, deviceId) {
  final patch = ref.watch(liveTelemetryPatchProvider(deviceId));
  final cumulative = patch?.cumulativeLiters;
  if (cumulative == null || cumulative <= 0) return null;
  return DeviceMeterReading(
    cumulativeLiters: cumulative,
    isLiveEstimate: true,
  );
});

class DeviceMeterReading {
  const DeviceMeterReading({
    required this.cumulativeLiters,
    required this.isLiveEstimate,
  });

  final double cumulativeLiters;
  final bool isLiveEstimate;
}

String normalizeDeviceId(String deviceId) => deviceId.trim().toUpperCase();

/// Rebuilds only when this device's live patch changes.
final liveTelemetryPatchProvider =
    Provider.family<LiveTelemetryPatch?, String>((ref, deviceId) {
  final key = normalizeDeviceId(deviceId);
  return ref.watch(
    liveTelemetryPatchesProvider.select((patches) => patches[key]),
  );
});

DashboardTelemetryDevice? mergeTelemetryPatch(
  DashboardTelemetryDevice? base,
  LiveTelemetryPatch? patch,
) {
  if (base == null) return null;
  if (patch == null) return base;
  return base.copyWith(
    flowRateLpm: patch.flowRateLpm,
    status: patch.status,
    isOnline: patch.isOnline,
    lastSeenAt: patch.lastSeenAt,
  );
}
