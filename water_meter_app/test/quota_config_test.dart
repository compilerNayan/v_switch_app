import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/quota_config.dart';

void main() {
  const steps = [
    QuotaStep(atLitersUsed: 300, action: QuotaStepAction.reducePressure, value: 20),
    QuotaStep(atLitersUsed: 400, action: QuotaStepAction.reducePressure, value: 20),
    QuotaStep(atLitersUsed: 500, action: QuotaStepAction.turnOff),
  ];

  group('QuotaCalculator', () {
    test('no steps triggered keeps 100% cap', () {
      final result = QuotaCalculator.computeCap(
        steps: steps,
        usedLiters: 200,
        dailyLimitLiters: 500,
      );

      expect(result.capPercent, 100);
      expect(result.activeStepIndex, -1);
      expect(result.nextStepAtLiters, 300);
    });

    test('first step triggered reduces cap to 80%', () {
      final result = QuotaCalculator.computeCap(
        steps: steps,
        usedLiters: 320,
        dailyLimitLiters: 500,
      );

      expect(result.capPercent, 80);
      expect(result.activeStepIndex, 0);
      expect(result.nextStepAtLiters, 400);
    });

    test('two steps triggered reduces cap to 60%', () {
      final result = QuotaCalculator.computeCap(
        steps: steps,
        usedLiters: 420,
        dailyLimitLiters: 500,
      );

      expect(result.capPercent, 60);
      expect(result.activeStepIndex, 1);
      expect(result.nextStepAtLiters, 500);
    });

    test('turn_off step sets cap to 0%', () {
      final result = QuotaCalculator.computeCap(
        steps: steps,
        usedLiters: 500,
        dailyLimitLiters: 500,
      );

      expect(result.capPercent, 0);
      expect(result.activeStepIndex, 2);
    });
  });

  group('QuotaResponse', () {
    test('fromJson parses config and status', () {
      final response = QuotaResponse.fromJson({
        'deviceId': 'WM-TEST',
        'enabled': true,
        'dailyLimitLiters': 500,
        'timezone': 'UTC',
        'steps': [
          {
            'atLitersUsed': 300,
            'action': 'reduce_pressure',
            'value': 20,
          },
        ],
        'status': {
          'date': '2026-06-06',
          'usedLiters': 320,
          'activeStepIndex': 0,
          'quotaCapPercent': 80,
          'remainingLiters': 180,
          'nextStepAtLiters': 400,
        },
      });

      expect(response.enabled, isTrue);
      expect(response.steps, hasLength(1));
      expect(response.status.usedLiters, 320);
      expect(response.status.quotaCapPercent, 80);
    });
  });
}
