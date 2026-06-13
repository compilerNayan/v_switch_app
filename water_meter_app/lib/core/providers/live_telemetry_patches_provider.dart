import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../live/live_update_message.dart';
import '../models/home_dashboard.dart';

/// How long to keep showing the last live flow reading after updates stop.
const Duration liveFlowStaleAfter = Duration(seconds: 3);

/// Ephemeral per-device telemetry overlay from WebSocket `water_flow` events.
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
  });

  final double flowRateLpm;
  final String status;
  final bool isOnline;
  final String lastSeenAt;

  @override
  bool operator ==(Object other) {
    return other is LiveTelemetryPatch &&
        other.flowRateLpm == flowRateLpm &&
        other.status == status &&
        other.isOnline == isOnline &&
        other.lastSeenAt == lastSeenAt;
  }

  @override
  int get hashCode =>
      Object.hash(flowRateLpm, status, isOnline, lastSeenAt);
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
    final key = normalizeDeviceId(event.deviceId);
    _scheduleStaleTimer(key);
    final next = Map<String, LiveTelemetryPatch>.from(state);
    next[key] = LiveTelemetryPatch(
      flowRateLpm: event.flowRateLpm,
      status: event.status,
      isOnline: true,
      lastSeenAt: event.ts,
    );
    state = next;
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
