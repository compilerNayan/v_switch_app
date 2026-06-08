import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/valve_actions.dart';
import '../models/audit_event.dart';
import '../models/bulk_valve_snapshot.dart';
import '../models/quota_config.dart';
import '../models/quota_template.dart';
import '../models/schedule_rule.dart';
import '../models/water_unit.dart';
import '../providers/app_providers.dart';
import '../providers/building_providers.dart';
import '../providers/control_providers.dart';
import '../providers/device_tile_providers.dart';
import '../providers/unit_providers.dart';
import 'audit_logger.dart';

final policyEngineProvider = Provider<PolicyEngine>((ref) => PolicyEngine(ref));

class PolicyEngine {
  PolicyEngine(this.ref);

  final Ref ref;

  Future<int> applyTemplate({
    required QuotaTemplate template,
    required List<WaterUnit> units,
    required String actorEmail,
  }) async {
    final client = ref.read(waterApiClientProvider);
    var count = 0;
    for (final unit in units.where((u) => !u.maintenanceMode)) {
      try {
        await client.updateQuota(
          unit.deviceId,
          QuotaUpdateRequest(
            enabled: true,
            dailyLimitLiters: template.dailyLimitLiters,
            steps: template.steps,
          ),
        );
        await ref.read(auditLoggerProvider).log(
              actorEmail: actorEmail,
              action: AuditAction.templateApply,
              unitId: unit.id,
              unitName: unit.name,
              details: template.name,
            );
        ref.invalidate(deviceQuotaProvider(unit.deviceId));
        count++;
      } catch (_) {}
    }
    return count;
  }

  Future<int> emergencyShutoff({
    required List<WaterUnit> units,
    required String actorEmail,
  }) async {
    final eligible = units.where((u) => !u.maintenanceMode).toList();
    final client = ref.read(waterApiClientProvider);
    final entries = <BulkValveSnapshotEntry>[];

    for (final unit in eligible) {
      try {
        final valve = await ref.read(deviceValveProvider(unit.deviceId).future);
        entries.add(
          BulkValveSnapshotEntry(
            deviceId: unit.deviceId,
            unitId: unit.id,
            wasOn: !valve.isOff,
            pressurePercent: valve.isOff
                ? valve.lastUserPressurePercent
                : valve.targetPressurePercent,
          ),
        );
      } catch (_) {}
    }

    final snapshot = BulkValveSnapshot(
      snapshotId: 'snap-${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      entries: entries,
    );
    final prefs = await ref.read(preferencesStorageProvider.future);
    await prefs.setBulkValveSnapshot(snapshot);
    ref.invalidate(bulkValveSnapshotProvider);

    var count = 0;
    for (final unit in eligible) {
      try {
        await setDeviceValvePressure(client, unit.deviceId, 0);
        ref.invalidate(deviceValveProvider(unit.deviceId));
        await ref.read(auditLoggerProvider).log(
              actorEmail: actorEmail,
              action: AuditAction.emergencyShutoff,
              unitId: unit.id,
              unitName: unit.name,
            );
        count++;
      } catch (_) {}
    }
    return count;
  }

  Future<int> emergencyRestore({required String actorEmail}) async {
    final prefs = await ref.read(preferencesStorageProvider.future);
    final snapshot = prefs.getBulkValveSnapshot();
    if (snapshot == null) return 0;

    final units = await ref.read(waterUnitsProvider.future);
    final maintenanceIds =
        units.where((u) => u.maintenanceMode).map((u) => u.id).toSet();

    final client = ref.read(waterApiClientProvider);
    var count = 0;
    for (final entry in snapshot.entries) {
      if (!entry.wasOn || maintenanceIds.contains(entry.unitId)) continue;
      try {
        await setDeviceValvePressure(
          client,
          entry.deviceId,
          entry.pressurePercent,
        );
        ref.invalidate(deviceValveProvider(entry.deviceId));
        count++;
      } catch (_) {}
    }

    await prefs.setBulkValveSnapshot(null);
    ref.invalidate(bulkValveSnapshotProvider);
    await ref.read(auditLoggerProvider).log(
          actorEmail: actorEmail,
          action: AuditAction.emergencyRestore,
          unitId: 'building',
          unitName: 'All units',
          details: 'Restored $count unit(s)',
        );
    return count;
  }

  double? scheduleCapForNow(List<ScheduleRule> rules, DateTime now) {
    for (final rule in rules) {
      if (rule.isActiveAt(now)) return rule.pressureCapPercent;
    }
    return null;
  }
}
