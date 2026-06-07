import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
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

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(provisioningNotifierProvider.notifier);
    notifier.setDeviceDisplayName(_nameController.text);
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
