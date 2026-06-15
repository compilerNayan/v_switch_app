import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/valve_state.dart';
import 'package:water_meter_app/core/utils/valve_pressure.dart';

void main() {
  group('valve_pressure', () {
    test('restore uses cached pressure when telemetry shows off at 0%', () {
      final percent = resolveRestorePressurePercent(
        cachedPressure: 75,
        current: ValveState(
          deviceId: 'WM1',
          timestamp: DateTime.utc(2026, 6, 14),
          targetPressurePercent: 0,
          actualPressurePercent: 0,
          lastUserPressurePercent: 0,
          isOff: true,
          controlMode: ValveControlMode.manual,
          effectivePressurePercent: 0,
        ),
        telemetryOpenPercent: 0,
        telemetryIsOff: true,
      );

      expect(percent, 75);
    });

    test('turning off stores last known open pressure', () {
      final percent = pressureBeforeTurningOff(
        cachedPressure: 100,
        telemetryOpenPercent: 60,
        telemetryIsOff: false,
      );

      expect(percent, 60);
    });
  });
}
