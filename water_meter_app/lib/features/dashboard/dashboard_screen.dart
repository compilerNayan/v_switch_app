import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/current_reading.dart';
import '../../core/models/usage_response.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/water_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/units.dart';
import '../../shared/widgets/device_scaffold_actions.dart';
import '../../shared/widgets/usage_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentAsync = ref.watch(currentReadingProvider);
    final hourlyAsync = ref.watch(todayHourlyUsageProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentReadingProvider);
          ref.invalidate(todayHourlyUsageProvider);
          ref.invalidate(usageResponseProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 120,
              pinned: true,
              leading: const DeviceBackButton(),
              flexibleSpace: FlexibleSpaceBar(
                title: const DeviceScreenTitle(fallback: 'Dashboard'),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.dashboardHeaderGradient(scheme),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  currentAsync.when(
                    data: (reading) => _LiveFlowCard(reading: reading, unit: volumeUnit),
                    loading: () => const _LoadingCard(height: 100),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                  ),
                  const SizedBox(height: 12),
                  hourlyAsync.when(
                    data: (usage) => _TodaySummaryCard(
                      usage: usage,
                      unit: volumeUnit,
                    ),
                    loading: () => const _LoadingCard(height: 160),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                  ),
                  const SizedBox(height: 12),
                  hourlyAsync.when(
                    data: (usage) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Today by hour',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            UsageChart(
                              dataPoints: usage.dataPoints,
                              granularity: usage.granularity,
                              unit: volumeUnit,
                              mode: ChartDisplayMode.bar,
                              height: 160,
                              compactLabels: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const _LoadingCard(height: 200),
                    error: (e, _) => _ErrorCard(message: e.toString()),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveFlowCard extends StatelessWidget {
  const _LiveFlowCard({required this.reading, required this.unit});

  final CurrentReading reading;
  final VolumeUnit unit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isFlowing = reading.status == WaterDeviceStatus.flowing;

    return Card(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.water_drop,
              size: 40,
              color: isFlowing ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live flow',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    '${VolumeFormatter.fromLiters(reading.flowRateLpm, unit).toStringAsFixed(1)} ${unit.symbol}/min',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${reading.status.label} · Updated ${DateFormat.Hm().format(reading.timestamp.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.usage, required this.unit});

  final UsageResponse usage;
  final VolumeUnit unit;

  @override
  Widget build(BuildContext context) {
    final total = usage.summary.totalVolumeLiters;
    final delta = usage.summary.deltaPercent;
    final isIncrease = delta > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's usage", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              VolumeFormatter.format(total, unit, decimals: 1),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                  color: isIncrease ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  '${delta.abs().toStringAsFixed(1)}% vs previous period',
                  style: TextStyle(
                    color: isIncrease ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SparklineChart(
              dataPoints: usage.dataPoints,
              unit: unit,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
