import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/quota_template.dart';
import '../../core/models/schedule_rule.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/control_providers.dart';
import '../../core/providers/unit_providers.dart';
import '../../core/services/policy_engine.dart';

final quotaTemplatesProvider = FutureProvider<List<QuotaTemplate>>((ref) async {
  final prefs = await ref.watch(preferencesStorageProvider.future);
  final saved = prefs.getQuotaTemplates();
  final defaultIds = QuotaTemplate.defaults.map((t) => t.id).toSet();
  final custom = saved.where((t) => !defaultIds.contains(t.id)).toList();
  return [...QuotaTemplate.defaults, ...custom];
});

final scheduleRulesProvider = FutureProvider<List<ScheduleRule>>((ref) async {
  final prefs = await ref.watch(preferencesStorageProvider.future);
  final rules = prefs.getScheduleRules();
  if (rules.isEmpty) return [ScheduleRule.defaultNightRule];
  return rules;
});

class PoliciesScreen extends ConsumerWidget {
  const PoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isDeviceAdminProvider);
    final templatesAsync = ref.watch(quotaTemplatesProvider);
    final rulesAsync = ref.watch(scheduleRulesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Policies')),
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
                    'Quota templates',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Apply a preset daily quota and step rules to all units',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  templatesAsync.when(
                    data: (templates) => Column(
                      children: templates.map((template) {
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(template.name),
                          subtitle: Text(
                            '${template.dailyLimitLiters.toStringAsFixed(0)} L/day · '
                            '${template.steps.length} steps',
                          ),
                          trailing: isAdmin
                              ? FilledButton.tonal(
                                  onPressed: () => _applyTemplate(
                                    context,
                                    ref,
                                    template,
                                  ),
                                  child: const Text('Apply'),
                                )
                              : null,
                        );
                      }).toList(),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
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
                  Text(
                    'Schedule rules',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Automatic pressure caps during scheduled windows',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  rulesAsync.when(
                    data: (rules) => Column(
                      children: rules.map((rule) {
                        return SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(rule.name),
                          subtitle: Text(
                            '${rule.startHour}:00–${rule.endHour}:00 · '
                            '${rule.pressureCapPercent.toStringAsFixed(0)}% cap',
                          ),
                          value: rule.enabled,
                          onChanged: isAdmin
                              ? (enabled) => _toggleScheduleRule(
                                    ref,
                                    rules,
                                    rule,
                                    enabled,
                                  )
                              : null,
                        );
                      }).toList(),
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isAdmin)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.power_settings_new,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                title: Text(
                  'Emergency shutoff',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                subtitle: Text(
                  'Turn off all unit valves immediately',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onErrorContainer
                        .withValues(alpha: 0.8),
                  ),
                ),
                trailing: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: () => _confirmEmergencyShutoff(context, ref),
                  child: const Text('Shut off'),
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Emergency shutoff requires admin access',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _applyTemplate(
    BuildContext context,
    WidgetRef ref,
    QuotaTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Apply "${template.name}"?'),
        content: Text(
          'This will update quota settings for all ${template.dailyLimitLiters.toStringAsFixed(0)} L units.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final units = await ref.read(waterUnitsProvider.future);
    final profile = await ref.read(userProfileProvider.future);
    final count = await ref.read(policyEngineProvider).applyTemplate(
          template: template,
          units: units,
          actorEmail: profile?.email ?? 'unknown',
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Applied to $count unit(s)')),
      );
    }
  }

  Future<void> _toggleScheduleRule(
    WidgetRef ref,
    List<ScheduleRule> rules,
    ScheduleRule rule,
    bool enabled,
  ) async {
    final updated = rules
        .map((r) => r.id == rule.id ? r.copyWith(enabled: enabled) : r)
        .toList();
    final prefs = await ref.read(preferencesStorageProvider.future);
    await prefs.saveScheduleRules(updated);
    ref.invalidate(scheduleRulesProvider);
  }

  Future<void> _confirmEmergencyShutoff(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency shutoff'),
        content: const Text(
          'This will turn off water to all units immediately. '
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Shut off all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final units = await ref.read(waterUnitsProvider.future);
    final profile = await ref.read(userProfileProvider.future);
    final count = await ref.read(policyEngineProvider).emergencyShutoff(
          units: units,
          actorEmail: profile?.email ?? 'unknown',
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shut off $count unit(s)')),
      );
    }
  }
}
