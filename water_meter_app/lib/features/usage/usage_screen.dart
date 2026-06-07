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
  DateRangePreset _preset = DateRangePreset.today;
  Granularity? _selectedGranularity;
  ChartDisplayMode _chartMode = ChartDisplayMode.bar;
  bool _queryInitialized = false;

  @override
  Widget build(BuildContext context) {
    if (!_queryInitialized) {
      _queryInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _updateQueryForPreset(DateTime.now());
      });
    }

    final query = ref.watch(usageQueryProvider);
    final range = query != null
        ? (from: query.from, to: query.to)
        : _preset.range(DateTime.now());
    final allowed = GranularityRules.allowedForRange(range.from, range.to);
    final granularity = query?.granularity ??
        GranularityRules.resolve(
          range.from,
          range.to,
          _selectedGranularity,
        );

    final usageAsync = ref.watch(usageResponseProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DeviceBackButton(),
        title: const DeviceScreenTitle(fallback: 'Usage'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: DateRangePreset.values.map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(preset.label),
                    selected: _preset == preset,
                    onSelected: (_) {
                      setState(() {
                        _preset = preset;
                        _selectedGranularity = null;
                      });
                      _updateQueryForPreset(DateTime.now());
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: allowed.map((g) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(g.label),
                    selected: granularity == g,
                    onSelected: (_) {
                      setState(() => _selectedGranularity = g);
                      _updateQueryForPreset(DateTime.now(), granularity: g);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SegmentedButton<ChartDisplayMode>(
              segments: const [
                ButtonSegment(
                  value: ChartDisplayMode.bar,
                  label: Text('Bar'),
                  icon: Icon(Icons.bar_chart),
                ),
                ButtonSegment(
                  value: ChartDisplayMode.cumulativeLine,
                  label: Text('Cumulative'),
                  icon: Icon(Icons.show_chart),
                ),
              ],
              selected: {_chartMode},
              onSelectionChanged: (modes) {
                setState(() => _chartMode = modes.first);
              },
            ),
          ),
          Expanded(
            child: usageAsync.when(
              data: (usage) => _UsageBody(
                usage: usage,
                unit: volumeUnit,
                chartMode: _chartMode,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _updateQueryForPreset(
    DateTime now, {
    Granularity? granularity,
  }) {
    final range = _preset.range(now);
    final resolved = granularity ??
        GranularityRules.resolve(
          range.from,
          range.to,
          _selectedGranularity,
        );
    ref.read(usageQueryProvider.notifier).state = UsageQuery(
      from: range.from,
      to: range.to,
      granularity: resolved,
    );
    ref.invalidate(usageResponseProvider);
  }
}

class _UsageBody extends StatelessWidget {
  const _UsageBody({
    required this.usage,
    required this.unit,
    required this.chartMode,
  });

  final UsageResponse usage;
  final VolumeUnit unit;
  final ChartDisplayMode chartMode;

  @override
  Widget build(BuildContext context) {
    final summary = usage.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: UsageChart(
                dataPoints: usage.dataPoints,
                granularity: usage.granularity,
                unit: unit,
                mode: chartMode,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Total',
                      value: VolumeFormatter.formatCompact(
                        summary.totalVolumeLiters,
                        unit,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Avg / bucket',
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
              ),
            ),
          ),
        ],
      ),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
