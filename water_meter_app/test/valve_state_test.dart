import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/valve_state.dart';

void main() {
  group('ValveState', () {
    test('fromJson parses pressure fields', () {
      final state = ValveState.fromJson({
        'deviceId': 'WM-TEST',
        'timestamp': '2026-06-06T14:30:00Z',
        'targetPressurePercent': 80,
        'actualPressurePercent': 78,
        'lastUserPressurePercent': 80,
        'isOff': false,
        'controlMode': 'manual',
        'quotaCapPercent': null,
        'effectivePressurePercent': 78,
      });

      expect(state.targetPressurePercent, 80);
      expect(state.actualPressurePercent, 78);
      expect(state.isOff, isFalse);
      expect(state.controlMode, ValveControlMode.manual);
    });

    test('fromStreamApiJson maps injection service response', () {
      final state = ValveState.fromStreamApiJson(
        {
          'targetPressurePercent': 50,
          'actualPressurePercent': 48,
        },
        deviceId: 'QJPDXN094',
      );

      expect(state.deviceId, 'QJPDXN094');
      expect(state.targetPressurePercent, 50);
      expect(state.actualPressurePercent, 48);
      expect(state.isOff, isFalse);
      expect(state.controlMode, ValveControlMode.manual);
    });

    test('ValveUpdateRequest serializes restore action', () {
      const request = ValveUpdateRequest(action: 'restore');
      expect(request.toJson(), {'action': 'restore'});
    });
  });
}
