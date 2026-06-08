import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/building_providers.dart';
import '../../core/providers/unit_providers.dart';
import '../../core/utils/unit_filters.dart';

class UnitLocationFilterButton extends ConsumerWidget {
  const UnitLocationFilterButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allBlocks = ref.watch(distinctBlocksProvider);
    final allWings = ref.watch(distinctWingsProvider);
    if (allBlocks.isEmpty && allWings.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedBlocks = ref.watch(selectedBlocksProvider);
    final selectedWings = ref.watch(selectedWingsProvider);
    final activeCount = selectedBlocks.length + selectedWings.length;

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _showFilterSheet(context, ref),
          icon: Badge(
            isLabelVisible: activeCount > 0,
            label: Text('$activeCount'),
            child: const Icon(Icons.filter_list),
          ),
          label: const Text('Block / Wing'),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _LocationFilterSheet(),
    );
  }
}

class _LocationFilterSheet extends ConsumerStatefulWidget {
  const _LocationFilterSheet();

  @override
  ConsumerState<_LocationFilterSheet> createState() =>
      _LocationFilterSheetState();
}

class _LocationFilterSheetState extends ConsumerState<_LocationFilterSheet> {
  late Set<String> _blocks;
  late Set<String> _wings;

  @override
  void initState() {
    super.initState();
    _blocks = Set.of(ref.read(selectedBlocksProvider));
    _wings = Set.of(ref.read(selectedWingsProvider));
  }

  @override
  Widget build(BuildContext context) {
    final allBlocks = ref.watch(distinctBlocksProvider);
    final allWings = ref.watch(distinctWingsProvider);
    final units = ref.watch(waterUnitsProvider).valueOrNull ?? [];
    final wingOptions = _blocks.isEmpty
        ? allWings
        : distinctWingsFromUnits(units, blocks: _blocks);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Filter by location',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _SectionHeader(
                      title: 'Blocks',
                      onClear: _blocks.isEmpty
                          ? null
                          : () => setState(() => _blocks.clear()),
                      onSelectAll: allBlocks.isEmpty
                          ? null
                          : () => setState(() => _blocks = Set.of(allBlocks)),
                    ),
                    if (allBlocks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No blocks defined yet'),
                      )
                    else
                      ...allBlocks.map(
                        (block) => CheckboxListTile(
                          title: Text(block),
                          value: _blocks.contains(block),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _blocks.add(block);
                              } else {
                                _blocks.remove(block);
                              }
                            });
                          },
                        ),
                      ),
                    const Divider(height: 24),
                    _SectionHeader(
                      title: 'Wings',
                      onClear: _wings.isEmpty
                          ? null
                          : () => setState(() => _wings.clear()),
                      onSelectAll: wingOptions.isEmpty
                          ? null
                          : () => setState(() => _wings = Set.of(wingOptions)),
                    ),
                    if (wingOptions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No wings defined yet'),
                      )
                    else
                      ...wingOptions.map(
                        (wing) => CheckboxListTile(
                          title: Text(wing),
                          value: _wings.contains(wing),
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _wings.add(wing);
                              } else {
                                _wings.remove(wing);
                              }
                            });
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _blocks.clear();
                        _wings.clear();
                      });
                    },
                    child: const Text('Clear all'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      ref.read(selectedBlocksProvider.notifier).state =
                          Set.of(_blocks);
                      ref.read(selectedWingsProvider.notifier).state =
                          Set.of(_wings);
                      Navigator.pop(context);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.onClear,
    this.onSelectAll,
  });

  final String title;
  final VoidCallback? onClear;
  final VoidCallback? onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const Spacer(),
        if (onSelectAll != null)
          TextButton(onPressed: onSelectAll, child: const Text('All')),
        if (onClear != null)
          TextButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }
}
