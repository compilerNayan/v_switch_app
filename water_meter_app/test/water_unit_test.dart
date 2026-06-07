import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/alert_event.dart';
import 'package:water_meter_app/core/models/audit_event.dart';
import 'package:water_meter_app/core/models/device_health.dart';
import 'package:water_meter_app/core/models/schedule_rule.dart';
import 'package:water_meter_app/core/models/tariff_config.dart';
import 'package:water_meter_app/core/theme/app_theme.dart';

void main() {
  test('AppTheme builds all 5 themes', () {
    for (final id in AppThemeId.values) {
      final theme = AppTheme.themeFor(id);
      expect(theme.useMaterial3, isTrue);
    }
  });

  test('DeviceHealth offline after threshold', () {
    final old = DateTime.now().subtract(const Duration(minutes: 20));
    final health = DeviceHealth.fromReading(
      unitId: 'u1',
      readingTimestamp: old,
    );
    expect(health.isOnline, isFalse);
  });

  test('ScheduleRule night window', () {
    const rule = ScheduleRule.defaultNightRule;
    expect(rule.isActiveAt(DateTime(2026, 6, 6, 23, 30)), isTrue);
    expect(rule.isActiveAt(DateTime(2026, 6, 6, 14, 0)), isFalse);
  });

  test('TariffConfig calculates cost', () {
    const tariff = TariffConfig(costPerLiter: 0.1, currencySymbol: '₹');
    expect(tariff.costForLiters(100), 10);
  });

  test('AlertType critical flags', () {
    expect(AlertType.possibleLeak.isCritical, isTrue);
    expect(AlertType.quotaWarning.isCritical, isFalse);
  });

  test('AuditAction labels', () {
    expect(AuditAction.emergencyShutoff.label, isNotEmpty);
  });
}
