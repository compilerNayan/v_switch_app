import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/provisioning/wifi_ssid_service.dart';
import '../../../../core/providers/provisioning_providers.dart';

class EnrollmentStep extends ConsumerStatefulWidget {
  const EnrollmentStep({super.key});

  @override
  ConsumerState<EnrollmentStep> createState() => _EnrollmentStepState();
}

class _EnrollmentStepState extends ConsumerState<EnrollmentStep>
    with WidgetsBindingObserver {
  bool _canEnroll = false;
  String? _currentSsid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateEnrollState());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateEnrollState();
    }
  }

  Future<void> _updateEnrollState() async {
    final serial = ref.read(provisioningNotifierProvider).deviceSerial;
    final ssidService = ref.read(wifiSsidServiceProvider);
    final onWifi = await ssidService.isConnectedToWifi();
    final ssid = await ssidService.getCurrentSsid();
    final canEnroll = WifiSsidService.canEnroll(
      savedSerial: serial,
      currentSsid: ssid,
      isOnWifi: onWifi,
    );
    if (mounted) {
      setState(() {
        _canEnroll = canEnroll;
        _currentSsid = ssid.isEmpty ? null : ssid;
      });
    }
  }

  Future<void> _enroll() async {
    await ref.read(provisioningNotifierProvider.notifier).enrollDevice();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provisioningNotifierProvider);
    final serial = state.deviceSerial ?? '—';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Enroll device',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Reconnect your phone to your home WiFi, then enroll the device.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 16),
        Text('Device serial: $serial'),
        if (_currentSsid != null) ...[
          const SizedBox(height: 8),
          Text('Current network: $_currentSsid'),
        ],
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _canEnroll
                  ? 'Ready to enroll. Tap Enroll to register this device.'
                  : 'Switch to your home WiFi (not IoT_) to enable enrollment.',
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
          onPressed: state.isLoading || !_canEnroll ? null : _enroll,
          child: state.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enroll'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _updateEnrollState,
          child: const Text('Refresh connection status'),
        ),
      ],
    );
  }
}
