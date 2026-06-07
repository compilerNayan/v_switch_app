import 'package:flutter/material.dart';

class DevicePrepStep extends StatefulWidget {
  const DevicePrepStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<DevicePrepStep> createState() => _DevicePrepStepState();
}

class _DevicePrepStepState extends State<DevicePrepStep> {
  bool? _greenLightVisible;
  bool _poweredOn = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Prepare your water meter',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Make sure the device is ready before connecting.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        Text(
          'Do you see a green light on the device?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _greenLightVisible = true),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _greenLightVisible == true
                      ? scheme.primaryContainer
                      : null,
                ),
                child: const Text('Yes'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _greenLightVisible = false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _greenLightVisible == false
                      ? scheme.errorContainer
                      : null,
                ),
                child: const Text('No'),
              ),
            ),
          ],
        ),
        if (_greenLightVisible == false) ...[
          const SizedBox(height: 16),
          Card(
            color: scheme.errorContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset the device',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Press and hold the reset button for 5 seconds until the '
                    'light blinks green, then try again.',
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _greenLightVisible = null),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        CheckboxListTile(
          value: _poweredOn,
          onChanged: (v) => setState(() => _poweredOn = v ?? false),
          title: const Text('Device is powered on and within range'),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _greenLightVisible == true && _poweredOn
              ? widget.onContinue
              : null,
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
