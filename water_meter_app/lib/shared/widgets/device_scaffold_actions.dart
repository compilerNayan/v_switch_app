import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/device_providers.dart';

class DeviceBackButton extends StatelessWidget {
  const DeviceBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.go('/'),
      tooltip: 'My Devices',
    );
  }
}

class DeviceScreenTitle extends ConsumerWidget {
  const DeviceScreenTitle({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(activeUserDeviceProvider);
    return Text(device?.name ?? fallback);
  }
}
