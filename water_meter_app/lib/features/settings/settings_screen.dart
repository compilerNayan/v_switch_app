import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/units.dart';
import 'theme_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeUnit = ref.watch(volumeUnitProvider);
    final timezone = ref.watch(timezoneProvider);
    final themeId = ref.watch(appThemeIdProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final prefsAsync = ref.watch(preferencesStorageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: profileAsync.when(
                data: (profile) {
                  if (profile == null) {
                    return const Text('Not signed in');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(profile.displayName, style: Theme.of(context).textTheme.bodyLarge),
                      Text(profile.email, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      _InfoRow(label: 'Role', value: profile.role?.label ?? '—'),
                      _InfoRow(label: 'Tenant ID', value: profile.tenantId ?? '—'),
                      if (profile.role == UserRole.admin &&
                          profile.inviteCode != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _InfoRow(
                                label: 'Invite code',
                                value: profile.inviteCode!,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: profile.inviteCode!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invite code copied')),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('App', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    AppConfig.useMockAuth
                        ? 'Mock auth (demo Google sign-in)'
                        : 'AWS Cognito auth',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    AppConfig.useMockApi
                        ? 'Mock water API (demo data)'
                        : 'API: ${AppConfig.apiBaseUrl}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    themeId.description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  const ThemePicker(),
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
              await ref.read(authServiceProvider).signOut();
              ref.invalidate(userProfileProvider);
              if (context.mounted) context.go('/auth');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
