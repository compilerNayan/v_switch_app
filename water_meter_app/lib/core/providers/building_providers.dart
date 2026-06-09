import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/building_api_client.dart';
import '../models/device_health.dart';
import '../models/tariff_config.dart';
import '../models/top_consumers_config.dart';
import '../models/water_unit.dart';
import '../utils/top_consumers_rankings.dart';
import '../models/bulk_valve_snapshot.dart';
import '../utils/unit_filters.dart';
import 'app_providers.dart';
import 'device_tile_providers.dart';
import 'tenant_providers.dart';
import 'unit_providers.dart';

enum UnitSortMode {
  usageDesc,
  quotaPercent,
  name,
  floor,
}

enum UnitFilter {
  all,
  flowing,
  nearQuota,
  overQuota,
  offline,
  hasAlert,
}

final buildingSummaryProvider = FutureProvider<BuildingSummary>((ref) async {
  final client = ref.watch(buildingApiClientProvider);
  final profile = await ref.watch(userProfileProvider.future);
  return client.getSummary(tenantId: profile?.tenantId ?? 'demo');
});

final hasLocationFilterProvider = Provider<bool>((ref) {
  return ref.watch(selectedBlocksProvider).isNotEmpty ||
      ref.watch(selectedWingsProvider).isNotEmpty;
});

final filteredUnitsProvider = Provider<List<WaterUnit>>((ref) {
  final units = ref.watch(waterUnitsProvider).valueOrNull ?? [];
  return applyLocationFilters(
    units,
    selectedBlocks: ref.watch(selectedBlocksProvider),
    selectedWings: ref.watch(selectedWingsProvider),
  );
});

final filteredBuildingOverviewProvider =
    FutureProvider<BuildingSummary>((ref) async {
  if (!ref.watch(hasLocationFilterProvider)) {
    return ref.watch(buildingSummaryProvider.future);
  }

  final units = ref.watch(filteredUnitsProvider);
  final client = ref.watch(waterApiClientProvider);
  final prefs = await ref.watch(preferencesStorageProvider.future);
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
          await ref.watch(deviceTodayUsageProvider(unit.deviceId).future);
      totalToday += today;
      consumers.add((unitId: unit.id, name: unit.name, liters: today));

      final daily = await client.getDailySummary(
        deviceId: unit.deviceId,
        from: startOfMonth,
        to: now,
        timezone: prefs.timezone,
      );
      totalMonth +=
          daily.days.fold<double>(0, (sum, day) => sum + day.totalLiters);

      final reading =
          await ref.watch(deviceCurrentReadingProvider(unit.deviceId).future);
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
});

final buildingRankingsProvider =
    FutureProvider.family<List<BuildingRanking>, String>((ref, period) async {
  final client = ref.watch(buildingApiClientProvider);
  final profile = await ref.watch(userProfileProvider.future);
  return client.getRankings(
    tenantId: profile?.tenantId ?? 'demo',
    period: period,
  );
});

final unitSortModeProvider =
    StateProvider<UnitSortMode>((ref) => UnitSortMode.usageDesc);
final unitFilterProvider = StateProvider<UnitFilter>((ref) => UnitFilter.all);
final unitSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedBlocksProvider = StateProvider<Set<String>>((ref) => {});
final selectedWingsProvider = StateProvider<Set<String>>((ref) => {});

final distinctBlocksProvider = Provider<List<String>>((ref) {
  final tenantConfig = ref.watch(tenantConfigProvider).valueOrNull;
  if (tenantConfig != null && tenantConfig.hasBlocks) {
    return tenantConfig.structure.blocks.map((b) => b.id).toList();
  }
  final units = ref.watch(waterUnitsProvider).valueOrNull ?? [];
  return distinctBlocksFromUnits(units);
});

final floorsForWingProvider =
    Provider.family<List<String>, ({String blockId, String wingName})>(
        (ref, args) {
  final tenantConfig = ref.watch(tenantConfigProvider).valueOrNull;
  if (tenantConfig == null) return const [];
  final count = tenantConfig.structure.floorCountForWing(
    args.blockId,
    args.wingName,
  );
  if (count <= 0) return const [];
  return List.generate(count, (index) => '${index + 1}');
});

final distinctWingsProvider = Provider<List<String>>((ref) {
  final tenantConfig = ref.watch(tenantConfigProvider).valueOrNull;
  final selectedBlocks = ref.watch(selectedBlocksProvider);
  if (tenantConfig != null && tenantConfig.hasWings) {
    if (selectedBlocks.isEmpty) {
      return tenantConfig.structure.blocks
          .expand((b) => b.wingNames)
          .toSet()
          .toList()
        ..sort();
    }
    final wings = <String>{};
    for (final blockId in selectedBlocks) {
      wings.addAll(tenantConfig.structure.wingsForBlock(blockId));
    }
    return wings.toList()..sort();
  }
  final units = ref.watch(waterUnitsProvider).valueOrNull ?? [];
  return distinctWingsFromUnits(units, blocks: selectedBlocks);
});

final bulkValveSnapshotProvider = FutureProvider<BulkValveSnapshot?>((ref) async {
  final prefs = await ref.watch(preferencesStorageProvider.future);
  return prefs.getBulkValveSnapshot();
});

final tariffConfigProvider = StateProvider<TariffConfig>((ref) {
  final prefsAsync = ref.watch(preferencesStorageProvider);
  return prefsAsync.maybeWhen(
    data: (prefs) => prefs.tariffConfig,
    orElse: () => const TariffConfig(),
  );
});

class TopConsumersConfigNotifier
    extends StateNotifier<TopConsumersDashboardConfig> {
  TopConsumersConfigNotifier(this.ref)
      : super(const TopConsumersDashboardConfig()) {
    _load();
  }

  final Ref ref;

  Future<void> _load() async {
    final prefs = await ref.read(preferencesStorageProvider.future);
    state = prefs.topConsumersConfig;
  }

  Future<void> updateConfig(TopConsumersDashboardConfig config) async {
    state = config;
    final prefs = await ref.read(preferencesStorageProvider.future);
    await prefs.setTopConsumersConfig(config);
  }
}

final topConsumersConfigProvider = StateNotifierProvider<
    TopConsumersConfigNotifier, TopConsumersDashboardConfig>((ref) {
  return TopConsumersConfigNotifier(ref);
});

final topConsumersRankingsProvider =
    FutureProvider<List<UnitUsage>>((ref) async {
  final units = ref.watch(filteredUnitsProvider);
  final rankings = <UnitUsage>[];
  for (final unit in units) {
    final liters =
        await ref.watch(deviceTodayUsageProvider(unit.deviceId).future);
    rankings.add((unit: unit, liters: liters));
  }
  return sortByUsageDesc(rankings);
});

/// Human-readable summary of active block/wing filter selection.
final locationFilterLabelProvider = Provider<String?>((ref) {
  final blocks = ref.watch(selectedBlocksProvider);
  final wings = ref.watch(selectedWingsProvider);
  if (blocks.isEmpty && wings.isEmpty) return null;

  final parts = <String>[];
  if (blocks.isNotEmpty) {
    final sorted = blocks.toList()..sort();
    parts.add('Block ${sorted.join(', ')}');
  }
  if (wings.isNotEmpty) {
    final sorted = wings.toList()..sort();
    parts.add('Wing ${sorted.join(', ')}');
  }
  return parts.join(' · ');
});
