import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/api/mock_water_api_client.dart';
import 'package:water_meter_app/core/models/quota_config.dart';
import 'package:water_meter_app/core/models/valve_state.dart';

void main() {
  group('MockWaterApiClient valve', () {
    late MockWaterApiClient client;

    setUp(() {
      client = MockWaterApiClient(seed: 1);
    });

    test('defaults to 100% pressure', () async {
      final state = await client.getValveState('WM-1');
      expect(state.targetPressurePercent, 100);
      expect(state.isOff, isFalse);
    });

    test('turn off stores last pressure and restore brings it back', () async {
      await client.setValvePressure(
        'WM-1',
        const ValveUpdateRequest(pressurePercent: 75),
      );
      final off = await client.setValvePressure(
        'WM-1',
        const ValveUpdateRequest(pressurePercent: 0),
      );
      expect(off.isOff, isTrue);
      expect(off.lastUserPressurePercent, 75);

      final restored = await client.setValvePressure(
        'WM-1',
        const ValveUpdateRequest(action: 'restore'),
      );
      expect(restored.targetPressurePercent, 75);
      expect(restored.isOff, isFalse);
    });

    test('quota update requires admin in mock', () async {
      final clientReadonly = MockWaterApiClient(
        seed: 1,
        canManageQuota: () async => false,
      );

      expect(
        () => clientReadonly.updateQuota(
          'WM-1',
          const QuotaUpdateRequest(
            enabled: true,
            dailyLimitLiters: 500,
            steps: [],
          ),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
