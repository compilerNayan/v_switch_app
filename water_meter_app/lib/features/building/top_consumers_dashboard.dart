import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/top_consumers_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/building_providers.dart';
import '../../core/providers/tenant_providers.dart';
import '../../core/utils/top_consumers_rankings.dart';
import '../../core/utils/units.dart';

class TopConsumersDashboard extends ConsumerStatefulWidget {
  const TopConsumersDashboard({super.key});

  @override
  ConsumerState<TopConsumersDashboard> createState() =>
      _TopConsumersDashboardState();
}

class _TopConsumersDashboardState extends ConsumerState<TopConsumersDashboard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(topConsumersConfigProvider);
    final rankingsAsync = ref.watch(topConsumersRankingsProvider);
    final volumeUnit = ref.watch(volumeUnitProvider);
    final blocks = ref.watch(distinctBlocksProvider);
    final tenantConfig = ref.watch(tenantConfigProvider).valueOrNull;
    var pages = config.enabledPages.where((page) {
      switch (page) {
        case TopConsumersPageType.overall:
          return true;
        case TopConsumersPageType.byBlock:
          return tenantConfig?.hasBlocks ?? blocks.isNotEmpty;
        case TopConsumersPageType.byWing:
          return tenantConfig?.hasWings ?? blocks.isNotEmpty;
      }
    }).toList();
    if (pages.isEmpty) pages = [TopConsumersPageType.overall];

    if (_currentPage >= pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = 0);
      });
    }

    return rankingsAsync.when(
      data: (rankings) {
        if (rankings.isEmpty) return const SizedBox.shrink();

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
                if (pages.length > 1)
                  Text(
                    pages[_currentPage.clamp(0, pages.length - 1)].label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  tooltip: 'Configure dashboard',
                  onPressed: () => _showConfigSheet(context, ref, config),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _pageHeightFor(pages[_currentPage.clamp(0, pages.length - 1)], config.topCount),
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: pages.map((pageType) {
                  switch (pageType) {
                    case TopConsumersPageType.overall:
                      return _OverallPage(
                        rankings: takeTop(rankings, config.topCount),
                        volumeUnit: volumeUnit,
                      );
                    case TopConsumersPageType.byBlock:
                      return _GroupedPage(
                        sections: topPerBlock(rankings, config.topCount),
                        volumeUnit: volumeUnit,
                      );
                    case TopConsumersPageType.byWing:
                      return _ByWingPage(
                        rankings: rankings,
                        blocks: blocks,
                        selectedBlock: config.wingViewBlock,
                        topCount: config.topCount,
                        volumeUnit: volumeUnit,
                        onBlockChanged: (block) {
                          ref
                              .read(topConsumersConfigProvider.notifier)
                              .updateConfig(
                                config.copyWith(wingViewBlock: block),
                              );
                        },
                      );
                  }
                }).toList(),
              ),
            ),
            if (pages.length > 1) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pages.length, (index) {
                  final active = index == _currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: active ? 16 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }),
              ),
            ],
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

  double _pageHeightFor(TopConsumersPageType type, int topCount) {
    switch (type) {
      case TopConsumersPageType.overall:
        return 24.0 + topCount * 34.0;
      case TopConsumersPageType.byBlock:
        return 220;
      case TopConsumersPageType.byWing:
        return 240;
    }
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
                    'Top consumers dashboard',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('All building'),
                    value: local.showOverall,
                    onChanged: (v) {
                      if (!v && !local.showByBlock && !local.showByWing) return;
                      setSheetState(() => local = local.copyWith(showOverall: v));
                    },
                  ),
                  SwitchListTile(
                    title: const Text('By block'),
                    value: local.showByBlock,
                    onChanged: (v) {
                      if (!v && !local.showOverall && !local.showByWing) return;
                      setSheetState(() => local = local.copyWith(showByBlock: v));
                    },
                  ),
                  SwitchListTile(
                    title: const Text('By wing in block'),
                    value: local.showByWing,
                    onChanged: (v) {
                      if (!v && !local.showOverall && !local.showByBlock) return;
                      setSheetState(() => local = local.copyWith(showByWing: v));
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
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

class _OverallPage extends StatelessWidget {
  const _OverallPage({
    required this.rankings,
    required this.volumeUnit,
  });

  final List<UnitUsage> rankings;
  final VolumeUnit volumeUnit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < rankings.length; i++)
          _RankRow(
            rank: i + 1,
            name: rankings[i].unit.name,
            liters: rankings[i].liters,
            volumeUnit: volumeUnit,
          ),
      ],
    );
  }
}

class _GroupedPage extends StatelessWidget {
  const _GroupedPage({
    required this.sections,
    required this.volumeUnit,
  });

  final Map<String, List<UnitUsage>> sections;
  final VolumeUnit volumeUnit;

  @override
  Widget build(BuildContext context) {
    final keys = sections.keys.toList()..sort();
    return ListView(
      children: [
        for (final key in keys) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Text(
              key,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          for (var i = 0; i < sections[key]!.length; i++)
            _RankRow(
              rank: i + 1,
              name: sections[key]![i].unit.name,
              liters: sections[key]![i].liters,
              volumeUnit: volumeUnit,
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ByWingPage extends StatelessWidget {
  const _ByWingPage({
    required this.rankings,
    required this.blocks,
    required this.selectedBlock,
    required this.topCount,
    required this.volumeUnit,
    required this.onBlockChanged,
  });

  final List<UnitUsage> rankings;
  final List<String> blocks;
  final String? selectedBlock;
  final int topCount;
  final VolumeUnit volumeUnit;
  final ValueChanged<String> onBlockChanged;

  @override
  Widget build(BuildContext context) {
    final block = selectedBlock != null && blocks.contains(selectedBlock)
        ? selectedBlock!
        : (blocks.isNotEmpty ? blocks.first : '');
    final sections =
        block.isEmpty ? <String, List<UnitUsage>>{} : topPerWingInBlock(rankings, block, topCount);

    return ListView(
      children: [
        if (blocks.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: blocks.map((b) {
                final selected = b == block;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: FilterChip(
                    label: Text(b),
                    selected: selected,
                    onSelected: (_) => onBlockChanged(b),
                  ),
                );
              }).toList(),
            ),
          ),
        if (sections.isEmpty)
          const Text('No usage data for this block')
        else
          for (final entry in sections.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key))) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            for (var i = 0; i < entry.value.length; i++)
              _RankRow(
                rank: i + 1,
                name: entry.value[i].unit.name,
                liters: entry.value[i].liters,
                volumeUnit: volumeUnit,
              ),
            const SizedBox(height: 8),
          ],
      ],
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
