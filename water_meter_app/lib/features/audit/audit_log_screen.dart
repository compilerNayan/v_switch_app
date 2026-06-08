import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/audit_event.dart';
import '../../core/services/audit_logger.dart';

final auditActionFilterProvider =
    StateProvider<AuditAction?>((ref) => null);

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(auditEventsProvider);
    final actionFilter = ref.watch(auditActionFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit log'),
        actions: [
          eventsAsync.maybeWhen(
            data: (events) {
              final filtered = _applyFilter(events, actionFilter);
              return IconButton(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Export CSV',
                onPressed: filtered.isEmpty
                    ? null
                    : () => _exportCsv(filtered),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text(
                  'Action',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AuditAction?>(
                    value: actionFilter,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All actions'),
                      ),
                      ...AuditAction.values.map(
                        (action) => DropdownMenuItem(
                          value: action,
                          child: Text(action.label),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        ref.read(auditActionFilterProvider.notifier).state =
                            value,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: eventsAsync.when(
              data: (events) {
                final filtered = _applyFilter(events, actionFilter);
                if (filtered.isEmpty) {
                  return const Center(child: Text('No audit events'));
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(auditEventsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final event = filtered[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(_iconForAction(event.action)),
                          title: Text(event.action.label),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (event.unitName != null)
                                Text(event.unitName!),
                              Text(event.actorEmail),
                              if (event.details != null)
                                Text(
                                  event.details!,
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat.yMMMd()
                                    .add_jm()
                                    .format(event.timestamp),
                                style:
                                    Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        ),
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

  List<AuditEvent> _applyFilter(
    List<AuditEvent> events,
    AuditAction? action,
  ) {
    if (action == null) return events;
    return events.where((e) => e.action == action).toList();
  }

  void _exportCsv(List<AuditEvent> events) {
    final buffer = StringBuffer(
      'Timestamp,Actor,Action,Unit,Details\n',
    );
    for (final event in events) {
      buffer.writeln(
        '"${event.timestamp.toIso8601String()}",'
        '"${event.actorEmail}",'
        '"${event.action.label}",'
        '"${event.unitName ?? event.unitId}",'
        '"${event.details ?? ''}"',
      );
    }
    Share.share(buffer.toString(), subject: 'audit-log.csv');
  }

  IconData _iconForAction(AuditAction action) {
    switch (action) {
      case AuditAction.valveOff:
        return Icons.power_off;
      case AuditAction.valveOn:
        return Icons.power;
      case AuditAction.quotaUpdate:
        return Icons.speed;
      case AuditAction.templateApply:
        return Icons.library_books_outlined;
      case AuditAction.emergencyShutoff:
        return Icons.warning_amber;
      case AuditAction.emergencyRestore:
        return Icons.restore;
      case AuditAction.unitEdit:
        return Icons.edit_outlined;
      case AuditAction.maintenanceMode:
        return Icons.build_outlined;
      case AuditAction.scheduleUpdate:
        return Icons.schedule;
    }
  }
}
