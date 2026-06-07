import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/provisioning/provisioning_state.dart';
import '../../../../core/provisioning/wifi_ssid_service.dart';
import '../../../../core/providers/provisioning_providers.dart';

class ConnectHotspotStep extends ConsumerStatefulWidget {
  const ConnectHotspotStep({super.key});

  @override
  ConsumerState<ConnectHotspotStep> createState() =>
      _ConnectHotspotStepState();
}

class _ConnectHotspotStepState extends ConsumerState<ConnectHotspotStep>
    with WidgetsBindingObserver {
  bool _checking = false;
  String? _detectedSsid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkHotspot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkHotspot(showWrongNetworkMessage: true);
    }
  }

  Future<void> _openWifiSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.wifi);
  }

  Future<void> _checkHotspot({bool showWrongNetworkMessage = false}) async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final ssidService = ref.read(wifiSsidServiceProvider);
      if (!await ssidService.hasLocationPermission()) {
        final granted = await ssidService.requestLocationPermission();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to read WiFi name.'),
            ),
          );
          return;
        }
      }

      final ssid = await ssidService.getCurrentSsid();
      if (!mounted) return;

      setState(() => _detectedSsid = ssid.isEmpty ? null : ssid);

      if (WifiSsidService.isOnIotHotspot(ssid)) {
        final serial = WifiSsidService.extractSerialFromSsid(ssid);
        if (serial != null) {
          ref.read(provisioningNotifierProvider.notifier).setDeviceSerial(serial);
          ref
              .read(provisioningNotifierProvider.notifier)
              .goToStep(WaterMeterSetupStep.homeWifi);
          return;
        }
      }

      if (showWrongNetworkMessage && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Connect to the IoT_ device WiFi and return to this app.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Connect to device WiFi',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Your device WiFi hotspot starts with IoT_ followed by the serial '
          'number (for example, IoT_ABC123).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('1. Open WiFi settings on your phone'),
                const SizedBox(height: 8),
                const Text('2. Connect to the network starting with IoT_'),
                const SizedBox(height: 8),
                const Text('3. Return to this app'),
              ],
            ),
          ),
        ),
        if (_detectedSsid != null) ...[
          const SizedBox(height: 16),
          Text(
            'Detected network: $_detectedSsid',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _checking ? null : _openWifiSettings,
          icon: const Icon(Icons.wifi),
          label: const Text('Open WiFi Settings'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _checking ? null : () => _checkHotspot(showWrongNetworkMessage: true),
          child: _checking
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("I've connected"),
        ),
      ],
    );
  }
}
