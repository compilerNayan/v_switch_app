import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/live/live_update_message.dart';
import 'package:water_meter_app/core/models/home_dashboard.dart';
import 'package:water_meter_app/core/providers/live_telemetry_patches_provider.dart';

DashboardTelemetryDevice _device({
  required String deviceId,
  double flowRateLpm = 0,
  String status = 'idle',
}) {
  return DashboardTelemetryDevice(
    unitId: 'wm-$deviceId',
    deviceId: deviceId,
    todayLiters: 10,
    monthLiters: 100,
    isOnline: true,
    status: status,
    flowRateLpm: flowRateLpm,
    quotaEnabled: false,
    dailyLimitLiters: 0,
    quotaUsedLiters: 0,
    valveOpenPercent: 100,
    valveIsOff: false,
    hasAlert: false,
  );
}

void main() {
    test('applyWaterFlowTick updates multiple devices in one state write', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(liveTelemetryPatchesProvider.notifier).applyWaterFlowTick(
          const LiveUpdateWaterFlowTick(
            tenantId: 'tenant-1',
            ts: '2026-06-09T10:30:05Z',
            devices: [
              WaterFlowTickDevice(
                deviceId: 'WM000001',
                unitId: 'wm-WM000001',
                ts: '2026-06-09T10:30:05Z',
                ml: 45,
                flowRateLpm: 2.7,
                cumulativeLiters: 88.2,
                todayLiters: 12.5,
                status: 'flowing',
              ),
              WaterFlowTickDevice(
                deviceId: 'WM000002',
                unitId: 'wm-WM000002',
                ts: '2026-06-09T10:30:05Z',
                ml: 30,
                flowRateLpm: 1.8,
                cumulativeLiters: 50.1,
                status: 'flowing',
              ),
            ],
          ),
        );

    expect(
      container.read(liveTelemetryPatchProvider('WM000001'))?.flowRateLpm,
      2.7,
    );
    expect(
      container.read(liveTelemetryPatchProvider('WM000001'))?.todayLiters,
      12.5,
    );
    expect(
      container.read(liveTelemetryPatchProvider('WM000002'))?.flowRateLpm,
      1.8,
    );
  });

  test('mergeTelemetryPatch applies live today usage to tile telemetry', () {
    final patch = const LiveTelemetryPatch(
      flowRateLpm: 2.7,
      status: 'flowing',
      isOnline: true,
      lastSeenAt: '2026-06-09T10:30:05Z',
      todayLiters: 25.5,
    );

    final merged = mergeTelemetryPatch(
      _device(deviceId: 'WM000001', flowRateLpm: 0),
      patch,
    );

    expect(merged?.todayLiters, 25.5);
    expect(merged?.quotaUsedLiters, 25.5);
  });

  test('mergeTelemetryPatch applies live month usage', () {
    final patch = const LiveTelemetryPatch(
      flowRateLpm: 2.7,
      status: 'flowing',
      isOnline: true,
      lastSeenAt: '2026-06-09T10:30:05Z',
      monthLiters: 14532.5,
    );

    final merged = mergeTelemetryPatch(
      _device(deviceId: 'WM000001'),
      patch,
    );

    expect(merged?.monthLiters, 14532.5);
  });

  test('zeros flow after stale timeout when updates stop', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(liveTelemetryPatchesProvider.notifier).applyWaterFlow(
          const LiveUpdateWaterFlow(
            tenantId: 'tenant-1',
            deviceId: 'WM000001',
            unitId: 'wm-WM000001',
            ts: '2026-06-09T10:30:05Z',
            ml: 100,
            flowRateLpm: 6.0,
            cumulativeLiters: 123.1,
            status: 'flowing',
          ),
        );

    expect(
      container.read(liveTelemetryPatchProvider('WM000001'))?.flowRateLpm,
      6.0,
    );
    expect(
      container.read(liveTelemetryPatchProvider('WM000001'))?.cumulativeLiters,
      123.1,
    );

    await Future<void>.delayed(liveFlowStaleAfter);

    final expired = container.read(liveTelemetryPatchProvider('WM000001'));
    expect(expired?.flowRateLpm, 0);
    expect(expired?.status, 'idle');
    expect(expired?.cumulativeLiters, 123.1);
  });

  test('clearDevice removes live meter reading overlay', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(liveTelemetryPatchesProvider.notifier).applyWaterFlow(
          const LiveUpdateWaterFlow(
            tenantId: 'tenant-1',
            deviceId: 'WM000001',
            unitId: 'wm-WM000001',
            ts: '2026-06-09T10:30:05Z',
            ml: 45,
            flowRateLpm: 2.7,
            cumulativeLiters: 50.5,
            status: 'flowing',
          ),
        );

    expect(container.read(deviceLiveMeterReadingProvider('WM000001')), isNotNull);

    container.read(liveTelemetryPatchesProvider.notifier).clearDevice('WM000001');

    expect(container.read(deviceLiveMeterReadingProvider('WM000001')), isNull);
  });

  test('live patch updates only the matching device telemetry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(liveTelemetryPatchesProvider.notifier).applyWaterFlow(
          const LiveUpdateWaterFlow(
            tenantId: 'tenant-1',
            deviceId: 'WM000001',
            unitId: 'wm-WM000001',
            ts: '2026-06-09T10:30:05Z',
            ml: 45,
            flowRateLpm: 2.7,
            cumulativeLiters: 88.2,
            status: 'flowing',
          ),
        );

    final patch = container.read(liveTelemetryPatchProvider('WM000001'));
    expect(patch?.flowRateLpm, 2.7);
    expect(patch?.status, 'flowing');

    final merged = mergeTelemetryPatch(_device(deviceId: 'WM000001'), patch);
    expect(merged?.flowRateLpm, 2.7);
    expect(merged?.status, 'flowing');
    expect(merged?.lastSeenAt, '2026-06-09T10:30:05Z');

    final otherPatch = container.read(liveTelemetryPatchProvider('WM000002'));
    expect(otherPatch, isNull);
  });
}
