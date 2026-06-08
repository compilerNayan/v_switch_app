import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/provisioning/provisioning_state.dart';
import '../../../../core/providers/building_providers.dart';
import '../../../../core/providers/provisioning_providers.dart';
import '../../../../core/providers/tenant_providers.dart';

class NameDeviceStep extends ConsumerStatefulWidget {
  const NameDeviceStep({super.key});

  @override
  ConsumerState<NameDeviceStep> createState() => _NameDeviceStepState();
}

class _NameDeviceStepState extends ConsumerState<NameDeviceStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _blockController = TextEditingController();
  final _wingController = TextEditingController();
  String? _selectedBlock;
  String? _selectedWing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(provisioningNotifierProvider);
      if (!mounted) return;
      if (state.deviceDisplayName != null) {
        _nameController.text = state.deviceDisplayName!;
      }
      if (state.block != null) {
        _blockController.text = state.block!;
        _selectedBlock = state.block;
      }
      if (state.wing != null) {
        _wingController.text = state.wing!;
        _selectedWing = state.wing;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _blockController.dispose();
    _wingController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(provisioningNotifierProvider.notifier);
    notifier.setDeviceDisplayName(_nameController.text);
    final block = _selectedBlock ?? _blockController.text.trim();
    final wing = _selectedWing ?? _wingController.text.trim();
    notifier.setBlock(block);
    notifier.setWing(wing);
    if (AppConfig.useMockProvisioning) {
      await notifier.mockEnrollAndRegister();
    } else {
      notifier.goToStep(WaterMeterSetupStep.enrollment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provisioningNotifierProvider);
    final serial = state.deviceSerial ?? '—';
    final isMock = AppConfig.useMockProvisioning;
    final tenantConfig = ref.watch(tenantConfigProvider).valueOrNull;
    final blockOptions = ref.watch(distinctBlocksProvider);
    final wingOptions = tenantConfig != null && tenantConfig.hasWings
        ? tenantConfig.structure.wingsForBlock(_selectedBlock ?? '')
        : ref.watch(distinctWingsProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Name your device',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a label and location for this water meter.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Text('Device serial: $serial'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Device name',
                  hintText: 'e.g. D205, Kitchen, Flat 3',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 32,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Required';
                  if (trimmed.length > 32) return 'Max 32 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (tenantConfig != null &&
                  tenantConfig.hasBlocks &&
                  blockOptions.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedBlock,
                  decoration: const InputDecoration(
                    labelText: 'Block',
                    prefixIcon: Icon(Icons.apartment_outlined),
                  ),
                  items: blockOptions
                      .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedBlock = v;
                    _selectedWing = null;
                  }),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                )
              else
                TextFormField(
                  controller: _blockController,
                  decoration: InputDecoration(
                    labelText: 'Block',
                    hintText: 'e.g. A, B, Tower 1',
                    prefixIcon: const Icon(Icons.apartment_outlined),
                    helperText: blockOptions.isNotEmpty
                        ? 'Existing: ${blockOptions.take(6).join(', ')}'
                        : null,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              const SizedBox(height: 16),
              if (tenantConfig != null &&
                  tenantConfig.hasWings &&
                  wingOptions.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: _selectedWing,
                  decoration: const InputDecoration(
                    labelText: 'Wing',
                    prefixIcon: Icon(Icons.holiday_village_outlined),
                  ),
                  items: wingOptions
                      .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedWing = v),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                )
              else
                TextFormField(
                  controller: _wingController,
                  decoration: InputDecoration(
                    labelText: 'Wing',
                    hintText: 'e.g. East, North',
                    prefixIcon: const Icon(Icons.holiday_village_outlined),
                    helperText: wingOptions.isNotEmpty
                        ? 'Existing: ${wingOptions.take(6).join(', ')}'
                        : null,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: state.isLoading ? null : _continue,
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isMock ? 'Add device (mock)' : 'Continue'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
