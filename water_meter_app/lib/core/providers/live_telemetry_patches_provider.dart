import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../live/live_update_message.dart';
import '../models/home_dashboard.dart';

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
  @override
  Map<String, LiveTelemetryPatch> build() => const {};

  void applyWaterFlow(LiveUpdateWaterFlow event) {
    final key = normalizeDeviceId(event.deviceId);
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
    state = const {};
  }

  void clearDevice(String deviceId) {
    final key = normalizeDeviceId(deviceId);
    if (!state.containsKey(key)) return;
    final next = Map<String, LiveTelemetryPatch>.from(state);
    next.remove(key);
    state = next;
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
