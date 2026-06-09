import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/top_consumers_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/building_providers.dart';
import '../../core/utils/top_consumers_rankings.dart';
import '../../core/utils/units.dart';

class TopConsumersDashboard extends ConsumerWidget {
  const TopConsumersDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(topConsumersConfigProvider);
    final rankingsAsync = ref.watch(topConsumersRankingsProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);

    return rankingsAsync.when(
      data: (rankings) {
        final top = takeTop(rankings, config.topCount);
        if (top.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Top consumers today',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  tooltip: 'Configure top count',
                  onPressed: () => _showConfigSheet(context, ref, config),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < top.length; i++)
              _RankRow(
                rank: i + 1,
                name: top[i].unit.name,
                liters: top[i].liters,
                volumeUnit: volumeUnit,
              ),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Failed to load rankings: $e'),
    );
  }

  void _showConfigSheet(
    BuildContext context,
    WidgetRef ref,
    TopConsumersDashboardConfig config,
  ) {
    var local = config;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Top consumers',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(local.topCount),
                    initialValue: local.topCount,
                    decoration: const InputDecoration(
                      labelText: 'Show top',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text('Top 3')),
                      DropdownMenuItem(value: 5, child: Text('Top 5')),
                      DropdownMenuItem(value: 10, child: Text('Top 10')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setSheetState(() => local = local.copyWith(topCount: v));
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await ref
                          .read(topConsumersConfigProvider.notifier)
                          .updateConfig(local);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.liters,
    required this.volumeUnit,
  });

  final int rank;
  final String name;
  final double liters;
  final VolumeUnit volumeUnit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            VolumeFormatter.formatCompact(liters, volumeUnit),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
