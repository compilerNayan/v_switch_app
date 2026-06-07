import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/building_api_client.dart';
import '../providers/app_providers.dart';
import '../providers/building_providers.dart';
import '../providers/device_tile_providers.dart';
import '../providers/unit_providers.dart';
import '../providers/water_providers.dart';
class UnitInsight {
  const UnitInsight({
    required this.title,
    required this.description,
    required this.severity,
  });

  final String title;
  final String description;
  final String severity;
}

final unitVsAverageProvider =
    FutureProvider.family<({double unit, double average, double ratio}), String>(
        (ref, deviceId) async {
  final units = await ref.watch(waterUnitsProvider.future);
  var total = 0.0;
  var count = 0;
  for (final unit in units) {
    try {
      final usage =
          await ref.read(deviceTodayUsageProvider(unit.deviceId).future);
      total += usage;
      count++;
    } catch (_) {}
  }
  final avg = count == 0 ? 0.0 : total / count;
  final unitUsage =
      await ref.read(deviceTodayUsageProvider(deviceId).future);
  final ratio = avg == 0 ? 1.0 : unitUsage / avg;
  return (unit: unitUsage, average: avg, ratio: ratio);
});

final monthOverMonthProvider =
    FutureProvider.family<({double thisMonth, double lastMonth}), String>(
        (ref, deviceId) async {
  final now = DateTime.now();
  final client = ref.watch(waterApiClientProvider);
  final timezone = ref.watch(timezoneProvider);
  final thisStart = DateTime(now.year, now.month, 1);
  final lastStart = DateTime(now.year, now.month - 1, 1);
  final lastEnd = thisStart.subtract(const Duration(days: 1));

  final thisMonth = await client.getDailySummary(
    deviceId: deviceId,
    from: thisStart,
    to: now,
    timezone: timezone,
  );
  final lastMonth = await client.getDailySummary(
    deviceId: deviceId,
    from: lastStart,
    to: lastEnd,
    timezone: timezone,
  );

  return (
    thisMonth: thisMonth.days.fold<double>(0, (s, d) => s + d.totalLiters),
    lastMonth: lastMonth.days.fold<double>(0, (s, d) => s + d.totalLiters),
  );
});

final topConsumersWeekProvider = FutureProvider<List<BuildingRanking>>((ref) async {
  return ref.watch(buildingRankingsProvider('week').future);
});

final unitInsightCardsProvider =
    FutureProvider.family<List<UnitInsight>, String>((ref, deviceId) async {
  final cards = <UnitInsight>[];
  final vsAvg = await ref.watch(unitVsAverageProvider(deviceId).future);
  if (vsAvg.ratio > 1.5) {
    cards.add(UnitInsight(
      title: 'Above building average',
      description:
          'Using ${(vsAvg.ratio * 100).toStringAsFixed(0)}% of building average today',
      severity: 'warning',
    ));
  } else if (vsAvg.ratio < 0.6 && vsAvg.unit > 0) {
    cards.add(UnitInsight(
      title: 'Below building average',
      description: 'Lower than typical usage for this building',
      severity: 'info',
    ));
  }

  final mom = await ref.watch(monthOverMonthProvider(deviceId).future);
  if (mom.lastMonth > 0) {
    final change = ((mom.thisMonth - mom.lastMonth) / mom.lastMonth) * 100;
    if (change.abs() > 15) {
      cards.add(UnitInsight(
        title: change > 0 ? 'Usage up vs last month' : 'Usage down vs last month',
        description: '${change.abs().toStringAsFixed(0)}% change month over month',
        severity: change > 30 ? 'warning' : 'info',
      ));
    }
  }

  return cards;
});
