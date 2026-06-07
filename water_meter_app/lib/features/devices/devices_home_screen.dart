import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_device.dart';
import '../../core/providers/device_providers.dart';
import 'device_tile.dart';

class DevicesHomeScreen extends ConsumerWidget {
  const DevicesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(userDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: devicesAsync.when(
        data: (devices) {
          if (devices.isEmpty) {
            return _EmptyDevicesState(
              onAdd: () => context.push('/devices/add'),
            );
          }
          return _DevicesGrid(
            devices: devices,
            onAddDevice: () => context.push('/devices/add'),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _EmptyDevicesState extends StatelessWidget {
  const _EmptyDevicesState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 72, color: scheme.outline),
            const SizedBox(height: 24),
            Text(
              'No devices yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first device to start monitoring.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first device'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesGrid extends StatelessWidget {
  const _DevicesGrid({
    required this.devices,
    required this.onAddDevice,
  });

  final List<UserDevice> devices;
  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 600 ? 2 : 1;

    return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 1 ? 2.2 : 1.35,
        ),
        itemCount: devices.length + 1,
        itemBuilder: (context, index) {
          if (index == devices.length) {
            return AddDeviceTile(onTap: onAddDevice);
          }
          return DeviceTile(device: devices[index]);
        },
    );
  }
}
