import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_health.dart';
import '../providers/app_providers.dart';
import '../providers/device_tile_providers.dart';
import '../providers/unit_providers.dart';
import '../storage/preferences_storage.dart';
import 'building_api_client.dart';
import 'water_api_client.dart';

final buildingApiClientProvider = Provider<BuildingApiClient>((ref) {
  return MockBuildingApiClient(ref);
});

class MockBuildingApiClient implements BuildingApiClient {
  MockBuildingApiClient(this.ref);

  final Ref ref;

  @override
  Future<BuildingSummary> getSummary({required String tenantId}) async {
    final units = await ref.read(waterUnitsProvider.future);
    final prefs = await ref.read(preferencesStorageProvider.future);
    final client = ref.read(waterApiClientProvider);
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    var totalToday = 0.0;
    var totalMonth = 0.0;
    var online = 0;
    var offline = 0;
    final consumers = <({String unitId, String name, double liters})>[];

    for (final unit in units) {
      try {
        final today =
            await ref.read(deviceTodayUsageProvider(unit.deviceId).future);
        totalToday += today;
        consumers.add((unitId: unit.id, name: unit.name, liters: today));

        final daily = await client.getDailySummary(
          deviceId: unit.deviceId,
          from: startOfMonth,
          to: now,
          timezone: prefs.timezone,
        );
        totalMonth +=
            daily.days.fold<double>(0, (s, d) => s + d.totalLiters);

        final reading =
            await ref.read(deviceCurrentReadingProvider(unit.deviceId).future);
        final health = DeviceHealth.fromReading(
          unitId: unit.id,
          readingTimestamp: reading.timestamp.toLocal(),
        );
        if (health.isOnline) {
          online++;
        } else {
          offline++;
        }
      } catch (_) {
        offline++;
      }
    }

    consumers.sort((a, b) => b.liters.compareTo(a.liters));

    return BuildingSummary(
      totalTodayLiters: totalToday,
      totalMonthLiters: totalMonth,
      unitsOnline: online,
      unitsOffline: offline,
      unitsTotal: units.length,
      activeAlerts: prefs
          .getAlerts()
          .where((a) => !a.isRead && !a.isResolved)
          .length,
      topConsumers: consumers.take(3).toList(),
    );
  }

  @override
  Future<List<BuildingRanking>> getRankings({
    required String tenantId,
    required String period,
  }) async {
    final units = await ref.read(waterUnitsProvider.future);
    final rankings = <BuildingRanking>[];

    for (final unit in units) {
      try {
        final liters =
            await ref.read(deviceTodayUsageProvider(unit.deviceId).future);
        final quota =
            await ref.read(deviceQuotaProvider(unit.deviceId).future);
        double? pct;
        if (quota.enabled && quota.dailyLimitLiters > 0) {
          pct = (liters / quota.dailyLimitLiters).clamp(0.0, 2.0);
        }
        rankings.add(BuildingRanking(
          unitId: unit.id,
          name: unit.name,
          liters: liters,
          quotaPercent: pct,
        ));
      } catch (_) {}
    }

    rankings.sort((a, b) => b.liters.compareTo(a.liters));
    return rankings;
  }
}
