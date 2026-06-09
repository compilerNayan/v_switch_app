import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/tenant_config.dart';

class BuildingStructureDraft {
  BuildingStructureDraft();

  final List<BlockDraft> blocks = [];

  void addBlock() => blocks.add(BlockDraft());

  void removeBlock(int index) {
    blocks[index].dispose();
    blocks.removeAt(index);
  }

  void dispose() {
    for (final block in blocks) {
      block.dispose();
    }
    blocks.clear();
  }

  static BuildingStructureDraft fromStructure(TenantStructure structure) {
    final draft = BuildingStructureDraft();
    for (final block in structure.blocks) {
      final blockDraft = BlockDraft(
        id: block.id,
        label: block.label,
      );
      for (final wing in block.wings) {
        blockDraft.addWing(
          name: wing.name,
          floorCount: wing.floorCount > 0 ? wing.floorCount.toString() : '',
        );
      }
      draft.blocks.add(blockDraft);
    }
    return draft;
  }

  TenantStructure toStructure() {
    return TenantStructure(
      blocks: blocks
          .map((block) {
            final id = block.idController.text.trim();
            final label = block.labelController.text.trim();
            final wings = block.wings
                .map((wing) {
                  final name = wing.nameController.text.trim();
                  if (name.isEmpty) return null;
                  final floorText = wing.floorCountController.text.trim();
                  final floorCount =
                      floorText.isEmpty ? 0 : int.tryParse(floorText) ?? 0;
                  return TenantWing(name: name, floorCount: floorCount);
                })
                .whereType<TenantWing>()
                .toList();
            return TenantBlock(
              id: id,
              label: label.isEmpty ? id : label,
              wings: wings,
            );
          })
          .where((block) => block.id.isNotEmpty)
          .toList(),
    );
  }

  String? validate() {
    for (final block in blocks) {
      if (block.idController.text.trim().isEmpty) {
        return 'Each block needs an ID';
      }
      for (final wing in block.wings) {
        if (wing.nameController.text.trim().isEmpty) {
          return 'Each wing needs a name';
        }
        final floorText = wing.floorCountController.text.trim();
        if (floorText.isNotEmpty && int.tryParse(floorText) == null) {
          return 'Floor count must be a number';
        }
      }
    }
    return null;
  }
}

class BlockDraft {
  BlockDraft({String id = '', String label = ''})
      : idController = TextEditingController(text: id),
        labelController = TextEditingController(text: label);

  final TextEditingController idController;
  final TextEditingController labelController;
  final List<WingDraft> wings = [];

  void addWing({String name = '', String floorCount = ''}) {
    wings.add(WingDraft(name: name, floorCount: floorCount));
  }

  void removeWing(int index) {
    wings[index].dispose();
    wings.removeAt(index);
  }

  void dispose() {
    idController.dispose();
    labelController.dispose();
    for (final wing in wings) {
      wing.dispose();
    }
  }
}

class WingDraft {
  WingDraft({String name = '', String floorCount = ''})
      : nameController = TextEditingController(text: name),
        floorCountController = TextEditingController(text: floorCount);

  final TextEditingController nameController;
  final TextEditingController floorCountController;

  void dispose() {
    nameController.dispose();
    floorCountController.dispose();
  }
}

class BuildingStructureFields extends StatelessWidget {
  const BuildingStructureFields({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final BuildingStructureDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Blocks, wings, and floors are optional. Add them if you want '
          'structured meter placement.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        ...List.generate(draft.blocks.length, (blockIndex) {
          final block = draft.blocks[blockIndex];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        'Block ${blockIndex + 1}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          draft.removeBlock(blockIndex);
                          onChanged();
                        },
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: block.idController,
                    decoration: const InputDecoration(
                      labelText: 'Block ID',
                      hintText: 'e.g. A',
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Required' : null,
                    onChanged: (_) => onChanged(),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: block.labelController,
                    decoration: const InputDecoration(
                      labelText: 'Block name (optional)',
                      hintText: 'e.g. Tower A',
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(block.wings.length, (wingIndex) {
                    final wing = block.wings[wingIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Wing ${wingIndex + 1}',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () {
                                      block.removeWing(wingIndex);
                                      onChanged();
                                    },
                                  ),
                                ],
                              ),
                              TextFormField(
                                controller: wing.nameController,
                                decoration: const InputDecoration(
                                  labelText: 'Wing name',
                                  hintText: 'e.g. East',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                        ? 'Required'
                                        : null,
                                onChanged: (_) => onChanged(),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: wing.floorCountController,
                                decoration: const InputDecoration(
                                  labelText: 'Number of floors (optional)',
                                  hintText: 'e.g. 10',
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) => onChanged(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  OutlinedButton.icon(
                    onPressed: () {
                      block.addWing();
                      onChanged();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add wing'),
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            draft.addBlock();
            onChanged();
          },
          icon: const Icon(Icons.add),
          label: const Text('Add block'),
        ),
      ],
    );
  }
}
