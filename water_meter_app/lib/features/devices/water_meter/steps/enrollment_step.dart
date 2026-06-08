import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/provisioning_providers.dart';

class EnrollmentStep extends ConsumerWidget {
  const EnrollmentStep({super.key});

  String _statusMessage({
    required bool wifiConfigured,
    required bool tenantAssociated,
  }) {
    if (wifiConfigured && tenantAssociated) {
      return 'Ready to enroll (coming soon). Tap Enroll to confirm prerequisites.';
    }
    if (!wifiConfigured && !tenantAssociated) {
      return 'Configure device WiFi and register with your building first.';
    }
    if (!wifiConfigured) {
      return 'Device WiFi is not configured yet. Go back and complete the WiFi step.';
    }
    return 'Device is not registered with your building yet. Go back and complete the WiFi step.';
  }

  Future<void> _enroll(BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(provisioningNotifierProvider.notifier).enrollDevice();
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enrollment will be enabled in a future update.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningNotifierProvider);
    final serial = state.deviceSerial ?? '—';
    final canEnroll = state.canEnroll;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Enroll device',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Enroll is enabled after device WiFi is configured and the meter is '
          'registered with your building.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Text('Device serial: $serial'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      state.wifiConfigured ? Icons.check_circle : Icons.circle_outlined,
                      color: state.wifiConfigured
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Device WiFi configured'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      state.tenantAssociated
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: state.tenantAssociated
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Registered with building'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage(
                    wifiConfigured: state.wifiConfigured,
                    tenantAssociated: state.tenantAssociated,
                  ),
                ),
              ],
            ),
          ),
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
          onPressed: state.isLoading || !canEnroll
              ? null
              : () => _enroll(context, ref),
          child: state.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enroll'),
        ),
      ],
    );
  }
}
