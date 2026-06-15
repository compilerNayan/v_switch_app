import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/top_consumers_config.dart';
import '../../core/models/water_unit.dart';
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 24),
            _SectionHeader(
              onConfigure: () => _showConfigSheet(context, ref, config),
            ),
            const SizedBox(height: 12),
            _TopConsumersPanel(rankings: top, volumeUnit: volumeUnit),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.onConfigure});

  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top consumers',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Highest usage today',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.tune_rounded,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
          tooltip: 'Configure top count',
          visualDensity: VisualDensity.compact,
          onPressed: onConfigure,
        ),
      ],
    );
  }
}

class _TopConsumersPanel extends StatelessWidget {
  const _TopConsumersPanel({
    required this.rankings,
    required this.volumeUnit,
  });

  final List<UnitUsage> rankings;
  final VolumeUnit volumeUnit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            for (var i = 0; i < rankings.length; i++)
              _TopConsumerRow(
                rank: i + 1,
                unit: rankings[i].unit,
                liters: rankings[i].liters,
                volumeUnit: volumeUnit,
                showDivider: i < rankings.length - 1,
              ),
          ],
        ),
      ),
    );
  }
}

class _TopConsumerRow extends StatelessWidget {
  const _TopConsumerRow({
    required this.rank,
    required this.unit,
    required this.liters,
    required this.volumeUnit,
    required this.showDivider,
  });

  final int rank;
  final WaterUnit unit;
  final double liters;
  final VolumeUnit volumeUnit;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final volume = VolumeFormatter.format(liters, volumeUnit, decimals: 2);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.35),
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RankBadge(rank: rank),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.topConsumerTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (unit.locationTagEntries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _LocationTagRow(tags: unit.locationTagEntries),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  volume,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'today',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLeader = rank == 1;

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLeader
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHigh,
      ),
      child: Text(
        '$rank',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isLeader ? scheme.primary : scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}

enum _LocationTagKind { wing, block, floor }

class _LocationTagRow extends StatelessWidget {
  const _LocationTagRow({required this.tags});

  final List<({String label, String value})> tags;

  static _LocationTagKind _kindFor(String label) {
    return switch (label) {
      'Wing' => _LocationTagKind.wing,
      'Block' => _LocationTagKind.block,
      _ => _LocationTagKind.floor,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          _LocationTag(
            label: tag.label,
            value: tag.value,
            kind: _kindFor(tag.label),
          ),
      ],
    );
  }
}

class _LocationTag extends StatelessWidget {
  const _LocationTag({
    required this.label,
    required this.value,
    required this.kind,
  });

  final String label;
  final String value;
  final _LocationTagKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (kind) {
      _LocationTagKind.wing => (
          const Color(0xFFE0F2F1),
          const Color(0xFF00695C),
        ),
      _LocationTagKind.block => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      _LocationTagKind.floor => (
          const Color(0xFFF3E5F5),
          const Color(0xFF6A1B9A),
        ),
    };

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Color.alphaBlend(foreground.withValues(alpha: 0.18), scheme.surface)
        : background;
    final fg = isDark ? foreground.withValues(alpha: 0.92) : foreground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
              height: 1.2,
            ),
      ),
    );
  }
}
