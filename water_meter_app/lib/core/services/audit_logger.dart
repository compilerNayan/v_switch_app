import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audit_event.dart';
import '../providers/app_providers.dart';

final auditLoggerProvider = Provider<AuditLogger>((ref) => AuditLogger(ref));

class AuditLogger {
  AuditLogger(this.ref);

  final Ref ref;

  Future<void> log({
    required String actorEmail,
    required AuditAction action,
    required String unitId,
    String? unitName,
    String? details,
  }) async {
    final prefs = await ref.read(preferencesStorageProvider.future);
    final event = AuditEvent(
      id: '${DateTime.now().millisecondsSinceEpoch}-$unitId',
      timestamp: DateTime.now(),
      actorEmail: actorEmail,
      action: action,
      unitId: unitId,
      unitName: unitName,
      details: details,
    );
    await prefs.appendAuditEvent(event);
    ref.invalidate(auditEventsProvider);
  }
}

final auditEventsProvider = FutureProvider<List<AuditEvent>>((ref) async {
  final prefs = await ref.watch(preferencesStorageProvider.future);
  return prefs.getAuditEvents().reversed.toList();
});
