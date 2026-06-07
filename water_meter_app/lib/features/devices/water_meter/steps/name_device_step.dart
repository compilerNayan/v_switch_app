import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/provisioning/provisioning_state.dart';
import '../../../../core/providers/provisioning_providers.dart';

class NameDeviceStep extends ConsumerStatefulWidget {
  const NameDeviceStep({super.key});

  @override
  ConsumerState<NameDeviceStep> createState() => _NameDeviceStepState();
}

class _NameDeviceStepState extends ConsumerState<NameDeviceStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final existing =
          ref.read(provisioningNotifierProvider).deviceDisplayName;
      if (existing != null && mounted) {
        _nameController.text = existing;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    ref
        .read(provisioningNotifierProvider.notifier)
        .setDeviceDisplayName(_nameController.text);
    ref
        .read(provisioningNotifierProvider.notifier)
        .goToStep(WaterMeterSetupStep.enrollment);
  }

  @override
  Widget build(BuildContext context) {
    final serial = ref.watch(provisioningNotifierProvider).deviceSerial ?? '—';

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
              'Choose a short label you will see on the home screen.',
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
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _continue,
              child: const Text('Continue'),
            ),
            ],
          ),
        ),
      ],
    );
  }
}
