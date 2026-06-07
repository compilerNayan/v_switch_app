import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/usage_response.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/water_providers.dart';
import '../../core/utils/granularity.dart';
import '../../core/utils/units.dart';
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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final range = _preset.range(now);
    final allowed = GranularityRules.allowedForRange(range.from, range.to);
    final granularity = GranularityRules.resolve(
      range.from,
      range.to,
      _selectedGranularity,
    );

    if (_selectedGranularity != null &&
        !GranularityRules.isAllowed(_selectedGranularity!, range.from, range.to)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Granularity adjusted to ${granularity.label} for this range',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() => _selectedGranularity = granularity);
        _updateQuery(range.from, range.to, granularity);
      });
    } else {
      _ensureQuery(range.from, range.to, granularity);
    }

    final usageAsync = ref.watch(usageResponseProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Usage')),
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
                      final r = preset.range(now);
                      final g = GranularityRules.defaultForRange(r.from, r.to);
                      _updateQuery(r.from, r.to, g);
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
                      _updateQuery(range.from, range.to, g);
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

  void _ensureQuery(DateTime from, DateTime to, Granularity granularity) {
    final current = ref.read(usageQueryProvider);
    if (current == null ||
        current.from != from ||
        current.to != to ||
        current.granularity != granularity) {
      _updateQuery(from, to, granularity);
    }
  }

  void _updateQuery(DateTime from, DateTime to, Granularity granularity) {
    ref.read(usageQueryProvider.notifier).state = UsageQuery(
      from: from,
      to: to,
      granularity: granularity,
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
