import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/building_api_client.dart';
import '../api/mock_building_api_client.dart';
import '../models/tariff_config.dart';
import 'app_providers.dart';

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

final unitSortModeProvider = StateProvider<UnitSortMode>((ref) => UnitSortMode.usageDesc);
final unitFilterProvider = StateProvider<UnitFilter>((ref) => UnitFilter.all);
final unitSearchQueryProvider = StateProvider<String>((ref) => '');

final tariffConfigProvider = StateProvider<TariffConfig>((ref) {
  final prefsAsync = ref.watch(preferencesStorageProvider);
  return prefsAsync.maybeWhen(
    data: (prefs) => prefs.tariffConfig,
    orElse: () => const TariffConfig(),
  );
});
