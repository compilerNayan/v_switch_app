import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/usage_response.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/water_providers.dart';
import '../../core/utils/granularity.dart';
import '../../core/utils/units.dart';
import '../../shared/widgets/device_scaffold_actions.dart';
import '../../shared/widgets/usage_chart.dart';

class UsageScreen extends ConsumerStatefulWidget {
  const UsageScreen({super.key});

  @override
  ConsumerState<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends ConsumerState<UsageScreen> {
  late DateTime _barChartDay;
  Granularity? _barGranularity;
  CumulativeRangePreset _cumulativePreset = CumulativeRangePreset.sevenDays;
  bool _queryInitialized = false;

  @override
  void initState() {
    super.initState();
    _barChartDay = GranularityRules.startOfDay(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    if (!_queryInitialized) {
      _queryInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncQueries(DateTime.now());
      });
    }

    final now = DateTime.now();
    final barGranularity = _barGranularity ??
        GranularityRules.defaultBarGranularityForDay(_barChartDay, now);
    final allowedBarGranularities =
        GranularityRules.barGranularitiesForDay(_barChartDay, now);

    final todaySummaryAsync = ref.watch(todayUsageSummaryProvider);
    final yesterdaySummaryAsync = ref.watch(yesterdayUsageSummaryProvider);
    final barUsageAsync = ref.watch(barUsageResponseProvider);
    final cumulativeUsageAsync = ref.watch(cumulativeUsageResponseProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DeviceBackButton(),
        title: const DeviceScreenTitle(fallback: 'Usage'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _DaySummaryCard(
                  label: 'Today',
                  usageAsync: todaySummaryAsync,
                  unit: volumeUnit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DaySummaryCard(
                  label: 'Yesterday',
                  usageAsync: yesterdaySummaryAsync,
                  unit: volumeUnit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ChartSection(
            title: 'Usage by period',
            subtitle: _barChartSubtitle(_barChartDay, now, barGranularity),
            controls: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DayNavigator(
                  day: _barChartDay,
                  now: now,
                  onPrevious: () => _shiftBarDay(-1),
                  onNext: () => _shiftBarDay(1),
                  onPickDate: () => _pickBarDay(now),
                ),
                const SizedBox(height: 8),
                _QuickDayChips(
                  now: now,
                  selectedDay: _barChartDay,
                  onSelect: _selectBarDay,
                ),
                const SizedBox(height: 8),
                _GranularityChips(
                  options: allowedBarGranularities,
                  selected: barGranularity,
                  onSelected: (granularity) {
                    setState(() => _barGranularity = granularity);
                    _syncQueries(now, barGranularity: granularity);
                  },
                ),
              ],
            ),
            child: barUsageAsync.when(
              data: (usage) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UsageChart(
                    dataPoints: usage.dataPoints,
                    granularity: usage.granularity,
                    unit: volumeUnit,
                    mode: ChartDisplayMode.bar,
                    height: 200,
                  ),
                  if (usage.dataPoints.length > 24) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tap a bar for time and volume',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _UsageStatsRow(usage: usage, unit: volumeUnit),
                ],
              ),
              loading: () => const _ChartLoading(height: 200),
              error: (e, _) => _ChartError(message: e.toString()),
            ),
          ),
          const SizedBox(height: 16),
          _ChartSection(
            title: 'Cumulative usage',
            subtitle: 'Running total over the selected range',
            controls: _RangeChips(
              selected: _cumulativePreset,
              onSelected: (preset) {
                setState(() => _cumulativePreset = preset);
                _syncQueries(now, cumulativePreset: preset);
              },
            ),
            child: cumulativeUsageAsync.when(
              data: (usage) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  UsageChart(
                    dataPoints: usage.dataPoints,
                    granularity: usage.granularity,
                    unit: volumeUnit,
                    mode: ChartDisplayMode.cumulativeLine,
                    height: 200,
                  ),
                  const SizedBox(height: 12),
                  _UsageStatsRow(
                    usage: usage,
                    unit: volumeUnit,
                    averageLabel: 'Avg / ${_cumulativePreset.label}',
                  ),
                ],
              ),
              loading: () => const _ChartLoading(height: 200),
              error: (e, _) => _ChartError(message: e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  void _selectBarDay(DateTime day) {
    setState(() {
      _barChartDay = GranularityRules.startOfDay(day);
      _barGranularity = null;
    });
    _syncQueries(DateTime.now());
  }

  void _shiftBarDay(int deltaDays) {
    final next = _barChartDay.add(Duration(days: deltaDays));
    final today = GranularityRules.startOfDay(DateTime.now());
    if (next.isAfter(today)) return;
    _selectBarDay(next);
  }

  Future<void> _pickBarDay(DateTime now) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _barChartDay,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: GranularityRules.startOfDay(now),
    );
    if (picked != null) {
      _selectBarDay(picked);
    }
  }

  void _syncQueries(
    DateTime now, {
    Granularity? barGranularity,
    CumulativeRangePreset? cumulativePreset,
  }) {
    final resolvedBarGranularity = barGranularity ??
        _barGranularity ??
        GranularityRules.defaultBarGranularityForDay(_barChartDay, now);

    ref.read(barUsageQueryProvider.notifier).state = BarUsageQuery(
      day: GranularityRules.startOfDay(_barChartDay),
      granularity: resolvedBarGranularity,
    );
    ref.read(cumulativeUsageQueryProvider.notifier).state = CumulativeUsageQuery(
      preset: cumulativePreset ?? _cumulativePreset,
    );
    ref.invalidate(barUsageResponseProvider);
    ref.invalidate(cumulativeUsageResponseProvider);
  }

  String _barChartSubtitle(DateTime day, DateTime now, Granularity granularity) {
    final dayLabel = GranularityRules.isSameDay(day, now)
        ? 'Today'
        : DateFormat.yMMMd().format(day.toLocal());
    return '$dayLabel · ${granularity.label} buckets';
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({
    required this.label,
    required this.usageAsync,
    required this.unit,
  });

  final String label;
  final AsyncValue<UsageResponse> usageAsync;
  final VolumeUnit unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: usageAsync.when(
          data: (usage) {
            final total = usage.summary.totalVolumeLiters;
            final delta = usage.summary.deltaPercent;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Text(
                  VolumeFormatter.formatCompact(total, unit),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (delta != 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% vs prior',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: delta >= 0
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ],
            );
          },
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ),
          error: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text('—', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.subtitle,
    required this.controls,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget controls;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            controls,
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _DayNavigator extends StatelessWidget {
  const _DayNavigator({
    required this.day,
    required this.now,
    required this.onPrevious,
    required this.onNext,
    required this.onPickDate,
  });

  final DateTime day;
  final DateTime now;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final canGoForward = day.isBefore(GranularityRules.startOfDay(now));
    final label = GranularityRules.isSameDay(day, now)
        ? 'Today'
        : DateFormat.yMMMd().format(day.toLocal());

    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: canGoForward ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _QuickDayChips extends StatelessWidget {
  const _QuickDayChips({
    required this.now,
    required this.selectedDay,
    required this.onSelect,
  });

  final DateTime now;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Today'),
          selected: GranularityRules.isSameDay(selectedDay, now),
          onSelected: (_) => onSelect(DateRangePreset.today.day(now)),
        ),
        ChoiceChip(
          label: const Text('Yesterday'),
          selected: GranularityRules.isSameDay(
            selectedDay,
            DateRangePreset.yesterday.day(now),
          ),
          onSelected: (_) => onSelect(DateRangePreset.yesterday.day(now)),
        ),
      ],
    );
  }
}

class _GranularityChips extends StatelessWidget {
  const _GranularityChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<Granularity> options;
  final Granularity selected;
  final ValueChanged<Granularity> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((granularity) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(granularity.label),
              selected: selected == granularity,
              onSelected: (_) => onSelected(granularity),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({
    required this.selected,
    required this.onSelected,
  });

  final CumulativeRangePreset selected;
  final ValueChanged<CumulativeRangePreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: CumulativeRangePreset.values.map((preset) {
        return ChoiceChip(
          label: Text(preset.label),
          selected: selected == preset,
          onSelected: (_) => onSelected(preset),
        );
      }).toList(),
    );
  }
}

class _UsageStatsRow extends StatelessWidget {
  const _UsageStatsRow({
    required this.usage,
    required this.unit,
    this.averageLabel = 'Avg / bucket',
  });

  final UsageResponse usage;
  final VolumeUnit unit;
  final String averageLabel;

  @override
  Widget build(BuildContext context) {
    final summary = usage.summary;
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Total',
            value: VolumeFormatter.formatCompact(summary.totalVolumeLiters, unit),
          ),
        ),
        Expanded(
          child: _SummaryTile(
            label: averageLabel,
            value: VolumeFormatter.formatCompact(
              summary.averagePerBucketLiters,
              unit,
            ),
          ),
        ),
        Expanded(
          child: _SummaryTile(
            label: 'Peak',
            value: VolumeFormatter.formatCompact(
              summary.peakBucket.volumeLiters,
              unit,
            ),
            subtitle: DateFormat.Hm().format(
              summary.peakBucket.timestamp.toLocal(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ChartError extends StatelessWidget {
  const _ChartError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        'Could not load chart: $message',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
