import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/water_providers.dart';
import '../../core/utils/units.dart';
import '../../shared/widgets/usage_chart.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyAsync = ref.watch(dailySummaryProvider);
    final hourlyAsync = ref.watch(hourlyPatternProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailySummaryProvider);
          ref.invalidate(hourlyPatternProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            dailyAsync.when(
              data: (daily) {
                final values = daily.days
                    .map((d) => VolumeFormatter.fromLiters(d.totalLiters, volumeUnit))
                    .toList();
                final labels = daily.days
                    .map((d) => DateFormat.E().format(d.date))
                    .toList();
                final avg = values.isEmpty
                    ? 0.0
                    : values.reduce((a, b) => a + b) / values.length;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily comparison (7 days)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Average: ${avg.toStringAsFixed(1)} ${volumeUnit.symbol}/day',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        SimpleBarChart(
                          values: values,
                          labels: labels,
                          unit: volumeUnit,
                          highlightLast: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const _InsightsLoadingCard(),
              error: (e, _) => _InsightsErrorCard(message: e.toString()),
            ),
            const SizedBox(height: 12),
            hourlyAsync.when(
              data: (pattern) {
                final values = pattern.hours
                    .map((h) => VolumeFormatter.fromLiters(h.avgLiters, volumeUnit))
                    .toList();
                final labels = pattern.hours
                    .map((h) => '${h.hour}')
                    .toList();
                final peak = pattern.hours.reduce(
                  (a, b) => a.avgLiters >= b.avgLiters ? a : b,
                );

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hour-of-day pattern',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Peak usage: ${peak.hour}:00–${(peak.hour + 1) % 24}:00 avg ${VolumeFormatter.format(peak.avgLiters, volumeUnit)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        SimpleBarChart(
                          values: values,
                          labels: labels,
                          unit: volumeUnit,
                          height: 200,
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const _InsightsLoadingCard(),
              error: (e, _) => _InsightsErrorCard(message: e.toString()),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsLoadingCard extends StatelessWidget {
  const _InsightsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _InsightsErrorCard extends StatelessWidget {
  const _InsightsErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}
