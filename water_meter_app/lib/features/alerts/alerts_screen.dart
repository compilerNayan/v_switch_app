import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/alert_event.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/alert_evaluator.dart';

enum AlertFilter { all, unread, critical }

final alertFilterProvider = StateProvider<AlertFilter>((ref) => AlertFilter.all);

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(alertsProvider);
    final filter = ref.watch(alertFilterProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              children: AlertFilter.values.map((f) {
                return FilterChip(
                  label: Text(_filterLabel(f)),
                  selected: filter == f,
                  onSelected: (_) =>
                      ref.read(alertFilterProvider.notifier).state = f,
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: alertsAsync.when(
              data: (alerts) {
                final filtered = _applyFilter(alerts, filter);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: scheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No alerts',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(alertsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final alert = filtered[index];
                      return _AlertCard(
                        alert: alert,
                        onTap: () => _onAlertTap(context, ref, alert),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  String _filterLabel(AlertFilter filter) {
    switch (filter) {
      case AlertFilter.all:
        return 'All';
      case AlertFilter.unread:
        return 'Unread';
      case AlertFilter.critical:
        return 'Critical';
    }
  }

  List<AlertEvent> _applyFilter(List<AlertEvent> alerts, AlertFilter filter) {
    switch (filter) {
      case AlertFilter.all:
        return alerts;
      case AlertFilter.unread:
        return alerts.where((a) => !a.isRead && !a.isResolved).toList();
      case AlertFilter.critical:
        return alerts.where((a) => a.type.isCritical).toList();
    }
  }

  Future<void> _onAlertTap(
    BuildContext context,
    WidgetRef ref,
    AlertEvent alert,
  ) async {
    if (!alert.isRead) {
      final prefs = await ref.read(preferencesStorageProvider.future);
      await prefs.markAlertRead(alert.id);
      ref.invalidate(alertsProvider);
      ref.invalidate(unreadAlertsCountProvider);
    }
    if (context.mounted) {
      context.push('/devices/${alert.unitId}/dashboard');
    }
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final AlertEvent alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isCritical = alert.type.isCritical;
    final isUnread = !alert.isRead && !alert.isResolved;

    return Card(
      color: isUnread ? scheme.primaryContainer.withValues(alpha: 0.3) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _iconForType(alert.type),
                color: isCritical ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.type.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.unitName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(alert.message),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat.yMMMd().add_jm().format(alert.timestamp),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
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

  IconData _iconForType(AlertType type) {
    switch (type) {
      case AlertType.quotaWarning:
        return Icons.speed_outlined;
      case AlertType.quotaExceeded:
        return Icons.warning_amber_outlined;
      case AlertType.possibleLeak:
        return Icons.water_damage_outlined;
      case AlertType.unusualSpike:
        return Icons.trending_up;
      case AlertType.deviceOffline:
        return Icons.cloud_off_outlined;
      case AlertType.valveMismatch:
        return Icons.sync_problem_outlined;
    }
  }
}
