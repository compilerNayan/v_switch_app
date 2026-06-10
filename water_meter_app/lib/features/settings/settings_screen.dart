import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/models/alert_event.dart';
import '../../core/models/tenant_config.dart';
import '../../core/providers/tenant_providers.dart';
import '../../core/models/tariff_config.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/building_providers.dart';
import '../../core/providers/dashboard_providers.dart';
import '../auth/building_structure_fields.dart';
import '../../core/providers/control_providers.dart';
import '../../core/utils/units.dart';
import 'theme_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeUnit = ref.watch(volumeUnitProvider);
    final timezone = ref.watch(timezoneProvider);
    final themeId = ref.watch(appThemeIdProvider);
    final tariff = ref.watch(tariffConfigProvider);
    final isAdmin = ref.watch(isDeviceAdminProvider);
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
                      _InfoRow(
                        label: 'Access',
                        value: profile.isTenantOwner
                            ? 'Building owner'
                            : 'Co-admin',
                      ),
                      _InfoRow(label: 'Tenant ID', value: profile.tenantId ?? '—'),
                      if (profile.tenantId != null) ...[
                        const SizedBox(height: 8),
                        _AdminInviteSection(tenantId: profile.tenantId!),
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
                  if (!AppConfig.useMockApi)
                    ref.watch(homeSnapshotProvider).when(
                          data: (snapshot) => Text(
                            snapshot == null
                                ? 'Home data: no tenant'
                                : 'Home data: ${snapshot.metadata.devices.length} units, '
                                    '${snapshot.dashboard.devices.length} telemetry',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          loading: () => Text(
                            'Home data: loading…',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          error: (e, _) => Text(
                            'Home data error: $e',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
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
          if (isAdmin) ...[
            const SizedBox(height: 12),
            const _BuildingStructureCard(),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Billing tariff'),
                    subtitle: Text(
                      '${tariff.currencySymbol}${tariff.costPerLiter.toStringAsFixed(3)} per liter',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: prefsAsync.hasValue
                          ? () => _editTariff(context, ref, tariff, prefsAsync.value!)
                          : null,
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Alert preferences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _editAlertPrefs(context, ref, prefsAsync),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Audit log'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/audit'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Policies'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/policies'),
                  ),
                ],
              ),
            ),
          ],
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

Future<void> _editTariff(
  BuildContext context,
  WidgetRef ref,
  TariffConfig current,
  dynamic prefs,
) async {
  final costController =
      TextEditingController(text: current.costPerLiter.toString());
  final symbolController =
      TextEditingController(text: current.currencySymbol);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Billing tariff'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: symbolController,
            decoration: const InputDecoration(labelText: 'Currency symbol'),
          ),
          TextField(
            controller: costController,
            decoration: const InputDecoration(labelText: 'Cost per liter'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok == true) {
    final updated = current.copyWith(
      currencySymbol: symbolController.text.trim(),
      costPerLiter: double.tryParse(costController.text) ?? current.costPerLiter,
    );
    await prefs.setTariffConfig(updated);
    ref.read(tariffConfigProvider.notifier).state = updated;
  }
}

Future<void> _editAlertPrefs(
  BuildContext context,
  WidgetRef ref,
  AsyncValue prefsAsync,
) async {
  if (!prefsAsync.hasValue) return;
  var prefs = prefsAsync.value!.alertPreferences;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Alert preferences'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AlertType.values.map((type) {
              return CheckboxListTile(
                title: Text(type.label),
                value: prefs.enabledTypes.contains(type),
                onChanged: (v) {
                  setState(() {
                    final types = Set<AlertType>.from(prefs.enabledTypes);
                    if (v == true) {
                      types.add(type);
                    } else {
                      types.remove(type);
                    }
                    prefs = prefs.copyWith(enabledTypes: types);
                  });
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await prefsAsync.value!.setAlertPreferences(prefs);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

class _AdminInviteSection extends ConsumerStatefulWidget {
  const _AdminInviteSection({required this.tenantId});

  final String tenantId;

  @override
  ConsumerState<_AdminInviteSection> createState() =>
      _AdminInviteSectionState();
}

class _AdminInviteSectionState extends ConsumerState<_AdminInviteSection> {
  String? _inviteCode;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final client = ref.read(tenantApiClientProvider);
      final code = await client.createAdminInvite(widget.tenantId);
      setState(() => _inviteCode = code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Co-admin invite', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'Share this code so another admin can join the building.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (_inviteCode != null)
          Row(
            children: [
              Expanded(child: _InfoRow(label: 'Code', value: _inviteCode!)),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _inviteCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied')),
                  );
                },
              ),
            ],
          ),
        FilledButton.tonal(
          onPressed: _loading ? null : _generate,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_inviteCode == null ? 'Generate invite' : 'New code'),
        ),
      ],
    );
  }
}

class _BuildingStructureCard extends ConsumerWidget {
  const _BuildingStructureCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(tenantConfigProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: configAsync.when(
          data: (config) {
            if (config == null) {
              return const Text('No building configuration');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Building', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(config.name, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 8),
                if (config.hasBlocks)
                  Text(
                    'Blocks: ${config.structure.blocks.map((b) => b.label).join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  Text(
                    'No block/wing structure configured',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _editStructure(context, ref, config),
                  child: const Text('Edit structure'),
                ),
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
    );
  }

  Future<void> _editStructure(
    BuildContext context,
    WidgetRef ref,
    TenantConfig config,
  ) async {
    final draft = BuildingStructureDraft.fromStructure(config.structure);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Building structure'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: BuildingStructureFields(
                draft: draft,
                onChanged: () => setState(() {}),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      draft.dispose();
      return;
    }

    final validationError = draft.validate();
    if (validationError != null) {
      draft.dispose();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(validationError)),
        );
      }
      return;
    }

    final structure = draft.toStructure();
    draft.dispose();

    final client = ref.read(tenantApiClientProvider);
    await client.updateStructure(
      tenantId: config.tenantId,
      structure: structure,
    );
    ref.invalidate(tenantConfigProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Structure updated')),
      );
    }
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
