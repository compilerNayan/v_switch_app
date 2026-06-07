import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/current_reading.dart';
import 'package:water_meter_app/core/models/daily_summary.dart';
import 'package:water_meter_app/core/models/usage_response.dart';

void main() {
  group('CurrentReading', () {
    test('fromJson parses all fields', () {
      final reading = CurrentReading.fromJson({
        'deviceId': 'WM-TEST',
        'timestamp': '2026-06-06T14:30:00Z',
        'flowRateLpm': 2.3,
        'cumulativeLiters': 125430.5,
        'status': 'flowing',
      });

      expect(reading.deviceId, 'WM-TEST');
      expect(reading.flowRateLpm, 2.3);
      expect(reading.status, WaterDeviceStatus.flowing);
    });
  });

  group('UsageResponse', () {
    test('fromJson parses nested summary and data points', () {
      final response = UsageResponse.fromJson({
        'deviceId': 'WM-TEST',
        'from': '2026-06-01T00:00:00Z',
        'to': '2026-06-02T00:00:00Z',
        'granularity': '1h',
        'unit': 'liters',
        'dataPoints': [
          {
            'timestamp': '2026-06-01T00:00:00Z',
            'volumeLiters': 12.5,
            'avgFlowRateLpm': 0.21,
          },
        ],
        'summary': {
          'totalVolumeLiters': 12.5,
          'averagePerBucketLiters': 12.5,
          'peakBucket': {
            'timestamp': '2026-06-01T00:00:00Z',
            'volumeLiters': 12.5,
          },
          'previousPeriodTotalLiters': 10.0,
          'deltaPercent': 25.0,
        },
      });

      expect(response.granularity, Granularity.h1);
      expect(response.dataPoints, hasLength(1));
      expect(response.summary.deltaPercent, 25.0);
    });
  });

  group('DailySummaryResponse', () {
    test('fromJson parses days', () {
      final response = DailySummaryResponse.fromJson({
        'unit': 'liters',
        'days': [
          {
            'date': '2026-06-06',
            'totalLiters': 142.3,
            'peakHour': 18,
            'peakHourLiters': 22.1,
          },
        ],
      });

      expect(response.days.first.totalLiters, 142.3);
      expect(response.days.first.peakHour, 18);
    });
  });
}
