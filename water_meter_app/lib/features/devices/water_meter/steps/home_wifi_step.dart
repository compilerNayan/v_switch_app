import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/provisioning_providers.dart';

class HomeWifiStep extends ConsumerStatefulWidget {
  const HomeWifiStep({super.key});

  @override
  ConsumerState<HomeWifiStep> createState() => _HomeWifiStepState();
}

class _HomeWifiStepState extends ConsumerState<HomeWifiStep> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _configure() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(provisioningNotifierProvider.notifier).configureHomeWifi(
          homeSsid: _ssidController.text.trim(),
          homePassword: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provisioningNotifierProvider);
    final serial = state.deviceSerial ?? '—';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            Text(
              'Configure home WiFi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your home WiFi credentials while connected to the device '
              'hotspot. After configuration, reconnect your phone to home WiFi '
              'so the app can register the meter with your building.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Text('Device serial: $serial'),
            const SizedBox(height: 24),
            TextFormField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'Home WiFi name',
                prefixIcon: Icon(Icons.wifi),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Home WiFi password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
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
              onPressed: state.isLoading ? null : _configure,
              child: state.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Configure WiFi'),
            ),
            ],
          ),
        ),
      ],
    );
  }
}
