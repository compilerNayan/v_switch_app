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
  Timer? _enrollmentTimer;
  bool _isAssociating = false;
  bool _isPollingEnrollment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAssociationPolling();
      _maybeStartEnrollmentPolling();
    });
  }

  @override
  void dispose() {
    _associationTimer?.cancel();
    _enrollmentTimer?.cancel();
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

  void _maybeStartEnrollmentPolling() {
    final state = ref.read(provisioningNotifierProvider);
    if (state.enrollStarted && !state.enrollComplete) {
      _startEnrollmentPolling();
    }
  }

  void _startEnrollmentPolling() {
    _enrollmentTimer?.cancel();
    _pollEnrollment();
    _enrollmentTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollEnrollment(),
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

  Future<void> _pollEnrollment() async {
    final state = ref.read(provisioningNotifierProvider);
    if (!state.enrollStarted || state.enrollComplete || _isPollingEnrollment) {
      if (state.enrollComplete) {
        _enrollmentTimer?.cancel();
      }
      return;
    }

    setState(() => _isPollingEnrollment = true);
    try {
      await ref
          .read(provisioningNotifierProvider.notifier)
          .pollEnrollmentStatus();
    } finally {
      if (mounted) {
        setState(() => _isPollingEnrollment = false);
      }
    }
  }

  Future<void> _enroll() async {
    final ok = await ref.read(provisioningNotifierProvider.notifier).enrollDevice();
    if (ok && mounted) {
      _startEnrollmentPolling();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(provisioningNotifierProvider, (previous, next) {
      if (next.enrollStarted &&
          !next.enrollComplete &&
          !(previous?.enrollStarted ?? false)) {
        _startEnrollmentPolling();
      }
      if (next.enrollComplete) {
        _enrollmentTimer?.cancel();
      }
    });

    final state = ref.watch(provisioningNotifierProvider);
    final serial = state.deviceSerial ?? '—';
    final canEnroll = state.canEnroll;
    final waitingForInternet = state.wifiConfigured && !state.tenantAssociated;
    final isEnrolling = state.isEnrolling;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Enroll device',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Enroll starts LAN device enrollment and creates the unit in your building.',
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
                _ChecklistRow(
                  done: state.wifiConfigured,
                  label: 'Device WiFi configured',
                ),
                const SizedBox(height: 8),
                _ChecklistRow(
                  done: state.tenantAssociated,
                  label: 'Registered with building',
                  loading: _isAssociating && !state.tenantAssociated,
                ),
                const SizedBox(height: 8),
                _ChecklistRow(
                  done: state.metadataComplete,
                  label: 'Unit details complete',
                ),
                const SizedBox(height: 8),
                _ChecklistRow(
                  done: state.enrollComplete,
                  label: 'Device enrollment',
                  loading: isEnrolling,
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
        if (isEnrolling)
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Enrolling device…'),
              ],
            ),
          )
        else
          FilledButton(
            onPressed: state.isLoading || !canEnroll ? null : _enroll,
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

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.done,
    required this.label,
    this.loading = false,
  });

  final bool done;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (loading)
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.primary,
            ),
          )
        else
          Icon(
            done ? Icons.check_circle : Icons.circle_outlined,
            color: done ? scheme.primary : null,
          ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
