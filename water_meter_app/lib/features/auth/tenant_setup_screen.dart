import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exceptions.dart';
import '../../core/models/tenant_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/tenant_providers.dart';

class TenantSetupScreen extends ConsumerStatefulWidget {
  const TenantSetupScreen({super.key});

  @override
  ConsumerState<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends ConsumerState<TenantSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _configureStructure = false;
  bool _isLoading = false;
  String? _error;
  final List<_BlockDraft> _blocks = [];

  @override
  void dispose() {
    _nameController.dispose();
    for (final block in _blocks) {
      block.dispose();
    }
    super.dispose();
  }

  void _addBlock() {
    setState(() => _blocks.add(_BlockDraft()));
  }

  void _removeBlock(int index) {
    setState(() {
      _blocks[index].dispose();
      _blocks.removeAt(index);
    });
  }

  TenantStructure _buildStructure() {
    if (!_configureStructure || _blocks.isEmpty) {
      return const TenantStructure();
    }
    return TenantStructure(
      blocks: _blocks
          .map((b) {
            final id = b.idController.text.trim();
            final label = b.labelController.text.trim().isEmpty
                ? id
                : b.labelController.text.trim();
            final wings = b.wingsController.text
                .split(',')
                .map((w) => w.trim())
                .where((w) => w.isNotEmpty)
                .toList();
            return TenantBlock(id: id, label: label, wings: wings);
          })
          .where((b) => b.id.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_configureStructure) {
      for (final block in _blocks) {
        if (block.idController.text.trim().isEmpty) {
          setState(() => _error = 'Each block needs an ID');
          return;
        }
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = ref.read(tenantApiClientProvider);
      await client.createTenant(
        name: _nameController.text.trim(),
        structure: _buildStructure(),
      );
      ref.invalidate(userProfileProvider);
      ref.invalidate(tenantConfigProvider);
      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() => _error = e.error.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up building')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Create your building',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'You are the first admin. Name the building and optionally '
              'define blocks and wings for filters and enrollment.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
            ],
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Building name',
                      hintText: 'e.g. Sunrise Apartments',
                      prefixIcon: Icon(Icons.apartment),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Configure blocks & wings'),
                    subtitle: const Text(
                      'Optional — drives location filters and meter enrollment',
                    ),
                    value: _configureStructure,
                    onChanged: (v) {
                      setState(() {
                        _configureStructure = v;
                        if (v && _blocks.isEmpty) _addBlock();
                      });
                    },
                  ),
                  if (_configureStructure) ...[
                    const SizedBox(height: 8),
                    ...List.generate(_blocks.length, (index) {
                      final block = _blocks[index];
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
                                    'Block ${index + 1}',
                                    style:
                                        Theme.of(context).textTheme.titleSmall,
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _removeBlock(index),
                                  ),
                                ],
                              ),
                              TextFormField(
                                controller: block.idController,
                                decoration: const InputDecoration(
                                  labelText: 'Block ID',
                                  hintText: 'e.g. A',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: block.labelController,
                                decoration: const InputDecoration(
                                  labelText: 'Display label (optional)',
                                  hintText: 'e.g. Tower A',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: block.wingsController,
                                decoration: const InputDecoration(
                                  labelText: 'Wings (comma-separated)',
                                  hintText: 'e.g. East, West',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    OutlinedButton.icon(
                      onPressed: _addBlock,
                      icon: const Icon(Icons.add),
                      label: const Text('Add block'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create building'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockDraft {
  _BlockDraft()
      : idController = TextEditingController(),
        labelController = TextEditingController(),
        wingsController = TextEditingController();

  final TextEditingController idController;
  final TextEditingController labelController;
  final TextEditingController wingsController;

  void dispose() {
    idController.dispose();
    labelController.dispose();
    wingsController.dispose();
  }
}
