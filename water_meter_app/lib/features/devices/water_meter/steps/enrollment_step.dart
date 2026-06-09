import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/provisioning_providers.dart';

class EnrollmentStep extends ConsumerStatefulWidget {
  const EnrollmentStep({super.key});

  @override
  ConsumerState<EnrollmentStep> createState() => _EnrollmentStepState();
}

class _EnrollmentStepState extends ConsumerState<EnrollmentStep> {
  Timer? _associationTimer;
  bool _isAssociating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAssociationPolling());
  }

  @override
  void dispose() {
    _associationTimer?.cancel();
    super.dispose();
  }

  void _startAssociationPolling() {
    _associationTimer?.cancel();
    _tryAssociate();
    _associationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _tryAssociate(),
    );
  }

  Future<void> _tryAssociate() async {
    final state = ref.read(provisioningNotifierProvider);
    if (state.tenantAssociated || _isAssociating) {
      return;
    }

    setState(() => _isAssociating = true);
    try {
      await ref
          .read(provisioningNotifierProvider.notifier)
          .associateDeviceWithTenant();
    } finally {
      if (mounted) {
        setState(() => _isAssociating = false);
      }
    }
  }

  String _statusMessage({
    required bool wifiConfigured,
    required bool tenantAssociated,
    required bool isAssociating,
  }) {
    if (wifiConfigured && tenantAssociated) {
      return 'Ready to enroll (coming soon). Tap Enroll to confirm prerequisites.';
    }
    if (!wifiConfigured) {
      return 'Device WiFi is not configured yet. Go back and complete the WiFi step.';
    }
    if (isAssociating) {
      return 'Checking internet connection and registering with your building…';
    }
    return 'Reconnect your phone to home WiFi. Registration will continue '
        'automatically when internet is available.';
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
  Widget build(BuildContext context) {
    final state = ref.watch(provisioningNotifierProvider);
    final serial = state.deviceSerial ?? '—';
    final canEnroll = state.canEnroll;
    final waitingForInternet = state.wifiConfigured && !state.tenantAssociated;

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
        if (waitingForInternet) ...[
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer.withValues(
                  alpha: 0.5,
                ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_isAssociating)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.wifi_find,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reconnect your phone to home WiFi. The app will register '
                      'the meter once internet is available.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
                    isAssociating: _isAssociating,
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
        if (waitingForInternet) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isAssociating ? null : _tryAssociate,
            child: const Text('Retry registration'),
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
