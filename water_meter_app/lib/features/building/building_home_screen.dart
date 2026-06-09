import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/water_unit.dart';
import '../../core/models/home_dashboard.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/building_providers.dart';
import '../../core/providers/control_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/device_tile_providers.dart';
import '../../core/providers/unit_providers.dart';
import '../../core/services/alert_evaluator.dart';
import '../../core/utils/unit_filters.dart';
import '../units/unit_tile.dart';
import 'building_summary_header.dart';

class BuildingHomeScreen extends ConsumerStatefulWidget {
  const BuildingHomeScreen({super.key});

  @override
  ConsumerState<BuildingHomeScreen> createState() => _BuildingHomeScreenState();
}

class _BuildingHomeScreenState extends ConsumerState<BuildingHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(alertEvaluatorProvider).evaluateAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final unitsAsync = ref.watch(waterUnitsProvider);
    final isAdmin = ref.watch(isDeviceAdminProvider);
    final unread = ref.watch(unreadAlertsCountProvider);
    final search = ref.watch(unitSearchQueryProvider);
    final filter = ref.watch(unitFilterProvider);
    final sort = ref.watch(unitSortModeProvider);
    final selectedBlocks = ref.watch(selectedBlocksProvider);
    final selectedWings = ref.watch(selectedWingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Building'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
              onPressed: () => context.push('/alerts'),
            ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.policy_outlined),
              onPressed: () => context.push('/policies'),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (_) {
          return unitsAsync.when(
            data: (units) {
              if (units.isEmpty) {
                return _EmptyState(
                  onAdd: () => context.push('/devices/water-meter/setup'),
                );
              }
              final filtered = _applyFilters(
                units,
                search,
                filter,
                selectedBlocks,
                selectedWings,
                ref,
              );
              final sorted = _applySort(filtered, sort, ref);

              return RefreshIndicator(
                onRefresh: () async {
                  invalidateHomeData(ref);
                  ref.invalidate(waterUnitsProvider);
                  ref.invalidate(buildingSummaryProvider);
                  ref.invalidate(filteredBuildingOverviewProvider);
                  ref.invalidate(topConsumersRankingsProvider);
                  await ref.read(alertEvaluatorProvider).evaluateAll();
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: BuildingSummaryHeader()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search units…',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              ref.read(unitSearchQueryProvider.notifier).state = v,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _FilterSortBar()),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount:
                              MediaQuery.sizeOf(context).width >= 600 ? 2 : 1,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio:
                              MediaQuery.sizeOf(context).width >= 600 ? 1.35 : 2.1,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == sorted.length) {
                              return AddUnitTile(
                                onTap: () =>
                                    context.push('/devices/water-meter/setup'),
                              );
                            }
                            return UnitTile(unit: sorted[index]);
                          },
                          childCount: sorted.length + 1,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/reports'),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Reports'),
            )
          : null,
    );
  }

  List<WaterUnit> _applyFilters(
    List<WaterUnit> units,
    String search,
    UnitFilter filter,
    Set<String> selectedBlocks,
    Set<String> selectedWings,
    WidgetRef ref,
  ) {
    var result = units;
    if (search.isNotEmpty) {
      result =
          result.where((u) => unitMatchesSearch(u, search)).toList();
    }
    result = applyLocationFilters(
      result,
      selectedBlocks: selectedBlocks,
      selectedWings: selectedWings,
    );
    if (filter == UnitFilter.all) return result;
    return result.where((u) => _matchesFilter(u, filter, ref)).toList();
  }

  bool _matchesFilter(WaterUnit unit, UnitFilter filter, WidgetRef ref) {
    final telemetry = ref.watch(deviceHomeTelemetryProvider(unit.deviceId));
    if (telemetry != null) {
      return _matchesFilterFromTelemetry(unit, filter, telemetry, ref);
    }

    switch (filter) {
      case UnitFilter.all:
        return true;
      case UnitFilter.offline:
        final health = ref.watch(deviceHealthProvider(unit.deviceId));
        return health.maybeWhen(data: (h) => !h.isOnline, orElse: () => false);
      case UnitFilter.flowing:
        final reading = ref.watch(deviceCurrentReadingProvider(unit.deviceId));
        return reading.maybeWhen(
          data: (r) => r.flowRateLpm > 0.2,
          orElse: () => false,
        );
      case UnitFilter.nearQuota:
        final usage = ref.watch(deviceTodayUsageProvider(unit.deviceId));
        final quota = ref.watch(deviceQuotaProvider(unit.deviceId));
        return usage.maybeWhen(
          data: (used) {
            final q = quota.valueOrNull;
            if (q == null || !q.enabled || q.dailyLimitLiters == 0) {
              return false;
            }
            return used / q.dailyLimitLiters >= 0.8 && used / q.dailyLimitLiters < 1;
          },
          orElse: () => false,
        );
      case UnitFilter.overQuota:
        final usage = ref.watch(deviceTodayUsageProvider(unit.deviceId));
        final quota = ref.watch(deviceQuotaProvider(unit.deviceId));
        return usage.maybeWhen(
          data: (used) {
            final q = quota.valueOrNull;
            if (q == null || !q.enabled || q.dailyLimitLiters == 0) {
              return false;
            }
            return used >= q.dailyLimitLiters;
          },
          orElse: () => false,
        );
      case UnitFilter.hasAlert:
        final alerts = ref.watch(alertsProvider);
        return alerts.maybeWhen(
          data: (list) => list.any(
            (a) => a.unitId == unit.id && !a.isResolved,
          ),
          orElse: () => false,
        );
    }
  }

  bool _matchesFilterFromTelemetry(
    WaterUnit unit,
    UnitFilter filter,
    DashboardTelemetryDevice telemetry,
    WidgetRef ref,
  ) {
    switch (filter) {
      case UnitFilter.all:
        return true;
      case UnitFilter.offline:
        return !telemetry.isOnline;
      case UnitFilter.flowing:
        return telemetry.isFlowing;
      case UnitFilter.nearQuota:
        if (!telemetry.quotaEnabled || telemetry.dailyLimitLiters == 0) {
          return false;
        }
        final ratio = telemetry.quotaUsedLiters / telemetry.dailyLimitLiters;
        return ratio >= 0.8 && ratio < 1;
      case UnitFilter.overQuota:
        if (!telemetry.quotaEnabled || telemetry.dailyLimitLiters == 0) {
          return false;
        }
        return telemetry.quotaUsedLiters >= telemetry.dailyLimitLiters;
      case UnitFilter.hasAlert:
        if (telemetry.hasAlert) return true;
        final alerts = ref.watch(alertsProvider);
        return alerts.maybeWhen(
          data: (list) => list.any(
            (a) => a.unitId == unit.id && !a.isResolved,
          ),
          orElse: () => false,
        );
    }
  }

  List<WaterUnit> _applySort(
    List<WaterUnit> units,
    UnitSortMode sort,
    WidgetRef ref,
  ) {
    final copy = [...units];
    switch (sort) {
      case UnitSortMode.name:
        copy.sort((a, b) => a.name.compareTo(b.name));
      case UnitSortMode.floor:
        copy.sort((a, b) => a.floor.compareTo(b.floor));
      case UnitSortMode.usageDesc:
        copy.sort((a, b) {
          final au = _todayUsage(ref, a.deviceId);
          final bu = _todayUsage(ref, b.deviceId);
          return bu.compareTo(au);
        });
      case UnitSortMode.quotaPercent:
        copy.sort((a, b) => _quotaPercent(ref, b).compareTo(_quotaPercent(ref, a)));
    }
    return copy;
  }

  double _todayUsage(WidgetRef ref, String deviceId) {
    final telemetry = ref.read(deviceHomeTelemetryProvider(deviceId));
    if (telemetry != null) return telemetry.todayLiters;
    return ref.read(deviceTodayUsageProvider(deviceId)).valueOrNull ?? 0;
  }

  double _quotaPercent(WidgetRef ref, WaterUnit unit) {
    final telemetry = ref.read(deviceHomeTelemetryProvider(unit.deviceId));
    if (telemetry != null) {
      if (!telemetry.quotaEnabled || telemetry.dailyLimitLiters == 0) return 0;
      return telemetry.quotaUsedLiters / telemetry.dailyLimitLiters;
    }
    final used =
        ref.read(deviceTodayUsageProvider(unit.deviceId)).valueOrNull ?? 0;
    final q = ref.read(deviceQuotaProvider(unit.deviceId)).valueOrNull;
    if (q == null || !q.enabled || q.dailyLimitLiters == 0) return 0;
    return used / q.dailyLimitLiters;
  }
}

class _FilterSortBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(unitFilterProvider);
    final sort = ref.watch(unitSortModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: UnitFilter.values.map((f) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_filterLabel(f)),
                  selected: filter == f,
                  onSelected: (_) =>
                      ref.read(unitFilterProvider.notifier).state = f,
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButton<UnitSortMode>(
            isExpanded: true,
            value: sort,
            items: const [
              DropdownMenuItem(
                value: UnitSortMode.usageDesc,
                child: Text('Sort: Usage (high → low)'),
              ),
              DropdownMenuItem(
                value: UnitSortMode.quotaPercent,
                child: Text('Sort: Quota %'),
              ),
              DropdownMenuItem(
                value: UnitSortMode.name,
                child: Text('Sort: Name'),
              ),
              DropdownMenuItem(
                value: UnitSortMode.floor,
                child: Text('Sort: Floor'),
              ),
            ],
            onChanged: (v) {
              if (v != null) ref.read(unitSortModeProvider.notifier).state = v;
            },
          ),
        ),
      ],
    );
  }

  String _filterLabel(UnitFilter f) {
    switch (f) {
      case UnitFilter.all:
        return 'All';
      case UnitFilter.flowing:
        return 'Flowing';
      case UnitFilter.nearQuota:
        return 'Near quota';
      case UnitFilter.overQuota:
        return 'Over quota';
      case UnitFilter.offline:
        return 'Offline';
      case UnitFilter.hasAlert:
        return 'Alerts';
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined,
                size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 24),
            Text('No water meters yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Add your first unit to start monitoring water consumption.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add water meter'),
            ),
          ],
        ),
      ),
    );
  }
}

