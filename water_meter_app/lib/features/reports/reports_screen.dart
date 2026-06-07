import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/tariff_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/building_providers.dart';
import '../../core/providers/unit_providers.dart';
import '../../core/services/report_builder.dart';
import '../../core/utils/units.dart';

enum ReportPeriod { thisMonth, lastMonth }

final reportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.thisMonth);

final monthlyReportProvider =
    FutureProvider<List<UnitReportRow>>((ref) async {
  final period = ref.watch(reportPeriodProvider);
  final units = await ref.watch(waterUnitsProvider.future);
  final client = ref.watch(waterApiClientProvider);
  final tariff = ref.watch(tariffConfigProvider);
  final timezone = ref.watch(timezoneProvider);

  final now = DateTime.now();
  late final DateTime from;
  late final DateTime to;

  switch (period) {
    case ReportPeriod.thisMonth:
      from = DateTime(now.year, now.month, 1);
      to = now;
    case ReportPeriod.lastMonth:
      from = DateTime(now.year, now.month - 1, 1);
      to = DateTime(now.year, now.month, 0);
  }

  return ReportBuilder.buildMonthlyReport(
    units: units,
    client: client,
    tariff: tariff,
    from: from,
    to: to,
    timezone: timezone,
  );
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final reportAsync = ref.watch(monthlyReportProvider);
    final tariff = ref.watch(tariffConfigProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          reportAsync.maybeWhen(
            data: (rows) => IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export CSV',
              onPressed: rows.isEmpty
                  ? null
                  : () => _exportCsv(rows, tariff),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<ReportPeriod>(
              segments: const [
                ButtonSegment(
                  value: ReportPeriod.thisMonth,
                  label: Text('This month'),
                ),
                ButtonSegment(
                  value: ReportPeriod.lastMonth,
                  label: Text('Last month'),
                ),
              ],
              selected: {period},
              onSelectionChanged: (selection) {
                ref.read(reportPeriodProvider.notifier).state =
                    selection.first;
              },
            ),
          ),
          Expanded(
            child: reportAsync.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No units to report'));
                }

                var totalLiters = 0.0;
                var totalCost = 0.0;
                for (final row in rows) {
                  totalLiters += row.totalLiters;
                  totalCost += row.estimatedCost;
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(monthlyReportProvider),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total usage',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      VolumeFormatter.formatCompact(
                                        totalLiters,
                                        volumeUnit,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Estimated cost',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      '${tariff.currencySymbol}${totalCost.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: [
                              const DataColumn(label: Text('Unit')),
                              const DataColumn(label: Text('Flat')),
                              DataColumn(
                                label: Text('Usage (${volumeUnit.symbol})'),
                              ),
                              DataColumn(
                                label: Text('Cost (${tariff.currencySymbol})'),
                              ),
                            ],
                            rows: rows.map((row) {
                              return DataRow(
                                cells: [
                                  DataCell(Text(row.unit.name)),
                                  DataCell(Text(row.unit.flatNumber)),
                                  DataCell(Text(
                                    VolumeFormatter.fromLiters(
                                      row.totalLiters,
                                      volumeUnit,
                                    ).toStringAsFixed(1),
                                  )),
                                  DataCell(Text(
                                    row.estimatedCost.toStringAsFixed(2),
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _exportCsv(rows, tariff),
                        icon: const Icon(Icons.download),
                        label: const Text('Export CSV'),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _exportCsv(List<UnitReportRow> rows, TariffConfig tariff) {
    final csv = ReportBuilder.toCsv(rows, tariff);
    final periodLabel = rows.isNotEmpty ? 'water-report' : 'report';
    Share.share(csv, subject: '$periodLabel.csv');
  }
}
