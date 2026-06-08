import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/building_api_client.dart';
import '../api/mock_building_api_client.dart';
import '../models/tariff_config.dart';
import '../models/top_consumers_config.dart';
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

final distinctWingsProvider = Provider<List<String>>((ref) {
  final tenantConfig = ref.watch(tenantConfigProvider).valueOrNull;
  final selectedBlocks = ref.watch(selectedBlocksProvider);
  if (tenantConfig != null && tenantConfig.hasWings) {
    if (selectedBlocks.isEmpty) {
      return tenantConfig.structure.blocks
          .expand((b) => b.wings)
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
  final units = await ref.watch(waterUnitsProvider.future);
  final rankings = <UnitUsage>[];
  for (final unit in units) {
    final liters =
        await ref.watch(deviceTodayUsageProvider(unit.deviceId).future);
    rankings.add((unit: unit, liters: liters));
  }
  return sortByUsageDesc(rankings);
});
