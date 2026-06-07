import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/alert_event.dart';
import '../models/device_health.dart';
import '../models/quota_config.dart';
import '../models/water_unit.dart';
import '../notifications/notification_service.dart';
import '../providers/app_providers.dart';
import '../providers/device_tile_providers.dart';
import '../providers/unit_providers.dart';
import 'audit_logger.dart';

final alertsProvider = FutureProvider<List<AlertEvent>>((ref) async {
  final prefs = await ref.watch(preferencesStorageProvider.future);
  return prefs.getAlerts().reversed.toList();
});

final unreadAlertsCountProvider = Provider<int>((ref) {
  final alerts = ref.watch(alertsProvider);
  return alerts.maybeWhen(
    data: (list) => list.where((a) => !a.isRead && !a.isResolved).length,
    orElse: () => 0,
  );
});

final alertEvaluatorProvider = Provider<AlertEvaluator>((ref) {
  final evaluator = AlertEvaluator(ref);
  ref.onDispose(evaluator.dispose);
  return evaluator;
});

class AlertEvaluator {
  AlertEvaluator(this.ref);

  final Ref ref;
  final _rng = Random();

  void dispose() {}

  Future<void> evaluateAll() async {
    final units = await ref.read(waterUnitsProvider.future);
    final prefs = await ref.read(preferencesStorageProvider.future);
    final alertPrefs = prefs.alertPreferences;
    final now = DateTime.now();

    for (final unit in units) {
      if (unit.maintenanceMode) continue;

      try {
        final reading =
            await ref.read(deviceCurrentReadingProvider(unit.deviceId).future);
        final quota =
            await ref.read(deviceQuotaProvider(unit.deviceId).future);
        final valve =
            await ref.read(deviceValveProvider(unit.deviceId).future);
        final todayUsage =
            await ref.read(deviceTodayUsageProvider(unit.deviceId).future);

        final health = DeviceHealth.fromReading(
          unitId: unit.id,
          readingTimestamp: reading.timestamp.toLocal(),
          now: now,
        );

        final candidates = <AlertEvent>[];

        if (!health.isOnline) {
          candidates.add(_alert(
            unit: unit,
            type: AlertType.deviceOffline,
            message: '${unit.name} offline — last seen ${health.lastSeenLabel(now)}',
          ));
        }

        if (quota.enabled) {
          final pct = quota.dailyLimitLiters == 0
              ? 0.0
              : todayUsage / quota.dailyLimitLiters;
          final turnOffActive = quota.status.activeStepIndex >= 0 &&
              quota.steps.isNotEmpty &&
              quota.steps[quota.status.activeStepIndex
                      .clamp(0, quota.steps.length - 1)]
                  .action ==
              QuotaStepAction.turnOff;
          if (pct >= 1.0 || turnOffActive) {
            candidates.add(_alert(
              unit: unit,
              type: AlertType.quotaExceeded,
              message: '${unit.name} exceeded daily quota (${todayUsage.toStringAsFixed(0)} L)',
            ));
          } else if (pct >= 0.8) {
            candidates.add(_alert(
              unit: unit,
              type: AlertType.quotaWarning,
              message: '${unit.name} at ${(pct * 100).toStringAsFixed(0)}% of daily quota',
            ));
          }
        }

        if (valve.isOff && reading.flowRateLpm > 0.2) {
          candidates.add(_alert(
            unit: unit,
            type: AlertType.valveMismatch,
            message: '${unit.name} valve is off but flow detected',
          ));
        }

        if (reading.flowRateLpm > 0.2 && !valve.isOff) {
          final isNight = now.hour >= 23 || now.hour < 6;
          if (isNight || (_rng.nextDouble() < 0.02 && reading.flowRateLpm > 0.5)) {
            candidates.add(_alert(
              unit: unit,
              type: AlertType.possibleLeak,
              message: '${unit.name} sustained flow — possible leak',
            ));
          }
        }

        if (todayUsage > 50 && _rng.nextDouble() < 0.05) {
          candidates.add(_alert(
            unit: unit,
            type: AlertType.unusualSpike,
            message: '${unit.name} usage spike — ${todayUsage.toStringAsFixed(0)} L today',
          ));
        }

        for (final alert in candidates) {
          if (!alertPrefs.isTypeEnabled(alert.type)) continue;
          if (alertPrefs.isQuietHour(now) &&
              alert.type == AlertType.possibleLeak) {
            continue;
          }
          await prefs.addAlert(alert);
          if (alertPrefs.pushEnabled) {
            await ref.read(notificationServiceProvider).showAlert(alert);
          }
        }
      } catch (_) {
        // Skip unit on fetch failure
      }
    }
    ref.invalidate(alertsProvider);
    ref.invalidate(unreadAlertsCountProvider);
  }

  AlertEvent _alert({
    required WaterUnit unit,
    required AlertType type,
    required String message,
  }) {
    return AlertEvent(
      id: '${DateTime.now().millisecondsSinceEpoch}-${unit.id}-${type.name}',
      unitId: unit.id,
      unitName: unit.name,
      type: type,
      message: message,
      timestamp: DateTime.now(),
    );
  }
}
