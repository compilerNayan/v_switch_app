import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/home_dashboard.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/providers/live_telemetry_patches_provider.dart';
import 'package:water_meter_app/core/utils/home_dashboard_aggregation.dart';

WaterUnit _unit(String id, String deviceId) {
  return WaterUnit(id: id, name: id, deviceId: deviceId);
}

DashboardTelemetryDevice _telemetry({
  required String unitId,
  required String deviceId,
  double todayLiters = 0,
  double monthLiters = 0,
  bool isOnline = true,
}) {
  return DashboardTelemetryDevice(
    unitId: unitId,
    deviceId: deviceId,
    todayLiters: todayLiters,
    monthLiters: monthLiters,
    isOnline: isOnline,
    status: isOnline ? 'idle' : 'offline',
    flowRateLpm: 0,
    quotaEnabled: false,
    dailyLimitLiters: 0,
    quotaUsedLiters: 0,
    valveOpenPercent: 100,
    valveIsOff: false,
    hasAlert: false,
  );
}

void main() {
  test('aggregateBuildingOverview sums telemetry and counts online/offline', () {
    final units = [
      _unit('u1', 'd1'),
      _unit('u2', 'd2'),
      _unit('u3', 'd3'),
    ];
    final telemetry = {
      'd1': _telemetry(
        unitId: 'u1',
        deviceId: 'd1',
        todayLiters: 10,
        monthLiters: 100,
        isOnline: true,
      ),
      'd2': _telemetry(
        unitId: 'u2',
        deviceId: 'd2',
        todayLiters: 20,
        monthLiters: 200,
        isOnline: false,
      ),
    };

    final summary = aggregateBuildingOverview(
      units: units,
      telemetry: telemetry,
      activeAlerts: 1,
    );

    expect(summary.totalTodayLiters, 30);
    expect(summary.totalMonthLiters, 300);
    expect(summary.unitsOnline, 1);
    expect(summary.unitsOffline, 2);
    expect(summary.unitsTotal, 3);
    expect(summary.activeAlerts, 1);
    expect(summary.topConsumers.length, 2);
    expect(summary.topConsumers.first.name, 'u2');
  });

  test('rankingsFromTelemetry sorts units by today usage', () {
    final units = [_unit('u1', 'd1'), _unit('u2', 'd2')];
    final telemetry = {
      'd1': _telemetry(unitId: 'u1', deviceId: 'd1', todayLiters: 5),
      'd2': _telemetry(unitId: 'u2', deviceId: 'd2', todayLiters: 15),
    };

    final rankings = rankingsFromTelemetry(units: units, telemetry: telemetry);

    expect(rankings.first.unit.id, 'u2');
    expect(rankings.first.liters, 15);
    expect(rankings.last.unit.id, 'u1');
  });

  test('aggregateBuildingOverview reflects live today usage from merged telemetry', () {
    final units = [_unit('u1', 'd1'), _unit('u2', 'd2')];
    final base = {
      'd1': _telemetry(unitId: 'u1', deviceId: 'd1', todayLiters: 10),
      'd2': _telemetry(unitId: 'u2', deviceId: 'd2', todayLiters: 20),
    };
    final merged = {
      'd1': mergeTelemetryPatch(
        base['d1'],
        const LiveTelemetryPatch(
          flowRateLpm: 2.7,
          status: 'flowing',
          isOnline: true,
          lastSeenAt: '2026-06-15T10:00:01Z',
          todayLiters: 15,
        ),
      )!,
      'd2': mergeTelemetryPatch(
        base['d2'],
        const LiveTelemetryPatch(
          flowRateLpm: 1.8,
          status: 'flowing',
          isOnline: true,
          lastSeenAt: '2026-06-15T10:00:01Z',
          todayLiters: 25,
        ),
      )!,
    };

    final summary = aggregateBuildingOverview(
      units: units,
      telemetry: merged,
      activeAlerts: 0,
    );

    expect(summary.totalTodayLiters, 40);
  });
}
