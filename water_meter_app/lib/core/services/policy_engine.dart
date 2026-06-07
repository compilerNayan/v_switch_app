import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/valve_actions.dart';
import '../models/audit_event.dart';
import '../providers/app_providers.dart';
import '../models/quota_config.dart';
import '../models/quota_template.dart';
import '../models/schedule_rule.dart';
import '../models/water_unit.dart';
import '../providers/app_providers.dart';
import '../providers/control_providers.dart';
import '../providers/device_tile_providers.dart';
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
    for (final unit in units) {
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
    var count = 0;
    for (final unit in units) {
      try {
        final client = ref.read(waterApiClientProvider);
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

  double? scheduleCapForNow(List<ScheduleRule> rules, DateTime now) {
    for (final rule in rules) {
      if (rule.isActiveAt(now)) return rule.pressureCapPercent;
    }
    return null;
  }
}
