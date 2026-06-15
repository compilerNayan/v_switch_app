import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_providers.dart';
import '../../core/providers/building_providers.dart';
import '../../core/utils/units.dart';
import 'building_location_filter.dart';
import 'top_consumers_dashboard.dart';

class BuildingSummaryHeader extends ConsumerWidget {
  const BuildingSummaryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(filteredBuildingOverviewProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);
    final filterLabel = ref.watch(locationFilterLabelProvider);
    final scheme = Theme.of(context).colorScheme;

    return summaryAsync.when(
      data: (summary) {
        final today =
            VolumeFormatter.formatDashboard(summary.totalTodayLiters, volumeUnit);
        final month = VolumeFormatter.formatDashboard(
          summary.totalMonthLiters,
          volumeUnit,
        );

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Building overview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const BuildingLocationFilterButton(compact: true),
                  ],
                ),
                if (filterLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    filterLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _UsageStatTile(
                        label: 'Today',
                        display: today,
                        icon: Icons.water_drop_outlined,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _UsageStatTile(
                        label: 'This month',
                        display: month,
                        icon: Icons.calendar_month_outlined,
                        color: scheme.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatusChip(
                        label: 'Online',
                        count: summary.unitsOnline,
                        color: Colors.green,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusChip(
                        label: 'Offline',
                        count: summary.unitsOffline,
                        color: scheme.error,
                        icon: Icons.cloud_off_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _StatusChip(
                        label: 'Total',
                        count: summary.unitsTotal,
                        color: scheme.outline,
                        icon: Icons.apartment_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const TopConsumersDashboard(),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load building summary: $e'),
        ),
      ),
    );
  }
}

class _UsageStatTile extends StatelessWidget {
  const _UsageStatTile({
    required this.label,
    required this.display,
    required this.icon,
    required this.color,
  });

  final String label;
  final VolumeDisplay display;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            display.primary,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (display.compact != null) ...[
            const SizedBox(height: 2),
            Text(
              display.compact!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
