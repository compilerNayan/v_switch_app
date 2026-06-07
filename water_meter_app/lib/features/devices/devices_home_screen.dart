import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/user_device.dart';
import '../../core/providers/device_providers.dart';

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
          return _DevicesList(
            devices: devices,
            onDeviceTap: (device) => context.go('/devices/${device.id}'),
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

class _DevicesList extends StatelessWidget {
  const _DevicesList({
    required this.devices,
    required this.onDeviceTap,
    required this.onAddDevice,
  });

  final List<UserDevice> devices;
  final void Function(UserDevice device) onDeviceTap;
  final VoidCallback onAddDevice;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${devices.length} device${devices.length == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        ...devices.map(
          (device) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DeviceListCard(
              device: device,
              onTap: () => onDeviceTap(device),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAddDevice,
          icon: const Icon(Icons.add),
          label: const Text('Add another device'),
        ),
      ],
    );
  }
}

class _DeviceListCard extends StatelessWidget {
  const _DeviceListCard({
    required this.device,
    required this.onTap,
  });

  final UserDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = iconForDeviceType(device.typeId);
    final icon = type?.icon ?? Icons.device_hub;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      device.deviceId,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
