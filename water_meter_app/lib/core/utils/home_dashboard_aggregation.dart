import '../api/building_api_client.dart';
import '../models/home_dashboard.dart';
import '../models/water_unit.dart';
import '../utils/top_consumers_rankings.dart';

BuildingSummary aggregateBuildingOverview({
  required List<WaterUnit> units,
  required Map<String, DashboardTelemetryDevice> telemetry,
  required int activeAlerts,
}) {
  var totalToday = 0.0;
  var totalMonth = 0.0;
  var online = 0;
  var offline = 0;
  final consumers = <({String unitId, String name, double liters})>[];

  for (final unit in units) {
    final device = telemetry[unit.deviceId];
    if (device == null) {
      offline++;
      continue;
    }
    totalToday += device.todayLiters;
    totalMonth += device.monthLiters;
    if (device.isOnline) {
      online++;
    } else {
      offline++;
    }
    consumers.add((unitId: unit.id, name: unit.name, liters: device.todayLiters));
  }

  consumers.sort((a, b) => b.liters.compareTo(a.liters));

  return BuildingSummary(
    totalTodayLiters: totalToday,
    totalMonthLiters: totalMonth,
    unitsOnline: online,
    unitsOffline: offline,
    unitsTotal: units.length,
    activeAlerts: activeAlerts,
    topConsumers: consumers.take(3).toList(),
  );
}

List<UnitUsage> rankingsFromTelemetry({
  required List<WaterUnit> units,
  required Map<String, DashboardTelemetryDevice> telemetry,
}) {
  final rankings = <UnitUsage>[];
  for (final unit in units) {
    final device = telemetry[unit.deviceId];
    rankings.add((unit: unit, liters: device?.todayLiters ?? 0));
  }
  return sortByUsageDesc(rankings);
}
