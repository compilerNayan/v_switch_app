import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/live/live_updates_debug_provider.dart';
import '../../core/models/current_reading.dart';
import '../../core/models/usage_response.dart';
import '../../core/models/quota_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/control_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../../core/providers/live_device_reading_provider.dart';
import '../../core/providers/unit_providers.dart';
import '../../core/providers/water_providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/units.dart';
import '../../shared/widgets/device_scaffold_actions.dart';
import '../../shared/widgets/usage_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(activeDeviceApiIdProvider);
    final liveReading = ref.watch(liveDeviceReadingProvider);
    final homeTelemetry = ref.watch(deviceHomeTelemetryProvider(deviceId));
    final currentAsync = ref.watch(currentReadingProvider);
    final wsDebug = ref.watch(liveUpdatesDebugProvider);
    final hourlyAsync = ref.watch(todayHourlyUsageProvider);
    final quotaAsync = ref.watch(quotaStateProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);
    final scheme = Theme.of(context).colorScheme;

    CurrentReading? resolvedLiveReading = liveReading;
    if (resolvedLiveReading == null && homeTelemetry != null) {
      resolvedLiveReading = CurrentReading(
        deviceId: homeTelemetry.deviceId,
        timestamp: homeTelemetry.lastSeenAt != null
            ? DateTime.tryParse(homeTelemetry.lastSeenAt!) ?? DateTime.now()
            : DateTime.now(),
        flowRateLpm: homeTelemetry.flowRateLpm,
        cumulativeLiters: homeTelemetry.todayLiters,
        status: homeTelemetry.isFlowing
            ? WaterDeviceStatus.flowing
            : (homeTelemetry.isOnline
                ? WaterDeviceStatus.idle
                : WaterDeviceStatus.offline),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentReadingProvider);
          ref.invalidate(todayHourlyUsageProvider);
          ref.invalidate(usageResponseProvider);
          ref.invalidate(quotaStateProvider);
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
                  if (!AppConfig.useMockApi)
                    _LiveSocketDebugBanner(debug: wsDebug),
                  if (!AppConfig.useMockApi) const SizedBox(height: 12),
                  resolvedLiveReading != null
                      ? _LiveFlowCard(
                          reading: resolvedLiveReading,
                          unit: volumeUnit,
                        )
                      : currentAsync.when(
                          data: (reading) =>
                              _LiveFlowCard(reading: reading, unit: volumeUnit),
                          loading: () => const _LoadingCard(height: 100),
                          error: (e, _) => _ErrorCard(message: e.toString()),
                        ),
                  const SizedBox(height: 12),
                  hourlyAsync.when(
                    data: (usage) => _TodaySummaryCard(
                      usage: usage,
                      unit: volumeUnit,
                      quota: quotaAsync.valueOrNull,
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

class _LiveSocketDebugBanner extends StatelessWidget {
  const _LiveSocketDebugBanner({required this.debug});

  final LiveUpdatesDebugState debug;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusText = !debug.socketEnabled
        ? 'WS disabled (check LIVE_UPDATES_WS_URL build flag)'
        : debug.socketConnected
            ? 'WS connected'
            : 'WS disconnected';

    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live socket debug',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '$statusText · messages: ${debug.messagesReceived} '
              '(flow: ${debug.waterFlowReceived}, 30m: ${debug.bucket30mReceived})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (debug.lastMessageType != null) ...[
              const SizedBox(height: 2),
              Text(
                'Last: ${debug.lastMessageType} at '
                '${debug.lastMessageAt != null ? TimeOfDay.fromDateTime(debug.lastMessageAt!).format(context) : '-'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (debug.lastError != null) ...[
              const SizedBox(height: 2),
              Text(
                'Error: ${debug.lastError}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ],
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
  const _TodaySummaryCard({
    required this.usage,
    required this.unit,
    this.quota,
  });

  final UsageResponse usage;
  final VolumeUnit unit;
  final QuotaResponse? quota;

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
            if (quota != null && quota!.enabled) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: quota!.dailyLimitLiters == 0
                      ? 0
                      : (quota!.status.usedLiters / quota!.dailyLimitLiters)
                          .clamp(0.0, 1.0)
                          .toDouble(),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Daily quota: ${VolumeFormatter.format(quota!.status.usedLiters, unit, decimals: 0)} / '
                '${VolumeFormatter.format(quota!.dailyLimitLiters, unit, decimals: 0)} · '
                'See Control tab',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
