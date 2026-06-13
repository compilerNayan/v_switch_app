import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/live/live_update_message.dart';
import 'package:water_meter_app/core/models/home_dashboard.dart';
import 'package:water_meter_app/core/models/tenant_config.dart';
import 'package:water_meter_app/core/models/tenant_metadata.dart';
import 'package:water_meter_app/core/providers/dashboard_providers.dart';

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

HomeSnapshot _snapshot() {
  return HomeSnapshot(
    metadata: const TenantMetadataResponse(
      tenantId: 'tenant-1',
      metadataHash: 'hash-1',
      buildingName: 'Test Building',
      structure: TenantStructure(),
      devices: [],
    ),
    dashboard: HomeDashboardResponse(
      metadataHash: 'hash-1',
      generatedAt: '2026-06-09T10:00:00Z',
      devices: [
        _device(deviceId: 'WM000001'),
        _device(deviceId: 'WM000002'),
      ],
    ),
  );
}

void main() {
  test('applyWaterFlow patches matching device telemetry', () async {
    final container = ProviderContainer(
      overrides: [
        homeSnapshotProvider.overrideWith(() => _TestHomeSnapshotNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await container.read(homeSnapshotProvider.future);
    final notifier = container.read(homeSnapshotProvider.notifier);

    notifier.applyWaterFlow(
      const LiveUpdateWaterFlow(
        tenantId: 'tenant-1',
        deviceId: 'WM000001',
        unitId: 'wm-WM000001',
        ts: '2026-06-09T10:30:05Z',
        ml: 45,
        flowRateLpm: 2.7,
        status: 'flowing',
      ),
    );

    final snapshot = container.read(homeSnapshotProvider).value!;
    final updated = snapshot.telemetryByDeviceId['WM000001']!;
    final untouched = snapshot.telemetryByDeviceId['WM000002']!;

    expect(updated.flowRateLpm, 2.7);
    expect(updated.status, 'flowing');
    expect(updated.lastSeenAt, '2026-06-09T10:30:05Z');
    expect(untouched.flowRateLpm, 0);
    expect(untouched.status, 'idle');
  });
}

class _TestHomeSnapshotNotifier extends HomeSnapshotNotifier {
  @override
  Future<HomeSnapshot?> build() async => _snapshot();
}
