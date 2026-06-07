import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/provisioning_providers.dart';

class EnrollmentSuccessStep extends ConsumerWidget {
  const EnrollmentSuccessStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provisioningNotifierProvider);
    final serial = state.deviceSerial;
    final displayName = state.deviceDisplayName;
    final notifier = ref.read(provisioningNotifierProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Water meter enrolled successfully',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            displayName != null
                ? '$displayName is ready. You can now view water usage.'
                : serial != null
                    ? 'Device $serial is ready. You can now view water usage.'
                    : 'Your device is ready. You can now view water usage.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: serial == null
                ? null
                : () {
                    final routeId = notifier.registeredDeviceRouteId(serial!);
                    context.go('/devices/$routeId/dashboard');
                  },
            child: const Text('View water usage'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Back to My Devices'),
          ),
        ],
      ),
    );
  }
}
