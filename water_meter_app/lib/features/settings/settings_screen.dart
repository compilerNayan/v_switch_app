import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/units.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeUnit = ref.watch(volumeUnitProvider);
    final timezone = ref.watch(timezoneProvider);
    final authAsync = ref.watch(authStateProvider);
    final prefsAsync = ref.watch(preferencesStorageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  authAsync.when(
                    data: (creds) => Text(
                      creds?.deviceId ?? 'Not configured',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppConfig.useMockApi
                        ? 'Using mock API (demo data)'
                        : 'API: ${AppConfig.apiBaseUrl}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Volume unit'),
                  subtitle: Text(volumeUnit.label),
                  trailing: DropdownButton<VolumeUnit>(
                    value: volumeUnit,
                    underline: const SizedBox.shrink(),
                    items: VolumeUnit.values
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(u.label),
                          ),
                        )
                        .toList(),
                    onChanged: prefsAsync.hasValue
                        ? (unit) async {
                            if (unit == null) return;
                            ref.read(volumeUnitProvider.notifier).state = unit;
                            await prefsAsync.value!.setVolumeUnit(unit);
                          }
                        : null,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Timezone'),
                  subtitle: Text(timezone),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      final tz = DateTime.now().timeZoneName;
                      ref.read(timezoneProvider.notifier).state = tz;
                      prefsAsync.whenData((p) => p.setTimezone(tz));
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(credentialsStorageProvider).clear();
              ref.invalidate(authStateProvider);
              if (context.mounted) context.go('/onboarding');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
