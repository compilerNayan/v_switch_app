import 'package:flutter_test/flutter_test.dart';
import 'package:water_meter_app/core/models/minute_series.dart';
import 'package:water_meter_app/core/models/usage_response.dart';
import 'package:water_meter_app/core/utils/usage_aggregation.dart';

void main() {
  final now = DateTime(2026, 6, 15, 14, 30);

  group('historyDaysToFetch', () {
    test('single day today requests one day', () {
      final from = DateTime(2026, 6, 15, 0, 0);
      final to = now;
      expect(UsageAggregation.historyDaysToFetch(from, to, now), 1);
    });

    test('three days back requests four days of history', () {
      final from = DateTime(2026, 6, 12, 0, 0);
      final to = DateTime(2026, 6, 13, 0, 0);
      expect(UsageAggregation.historyDaysToFetch(from, to, now), 4);
    });

    test('thirty day cumulative range requests thirty days', () {
      final from = DateTime(2026, 5, 17, 0, 0);
      final to = now;
      expect(UsageAggregation.historyDaysToFetch(from, to, now), 30);
    });
  });

  group('buildUsage', () {
    test('includes buckets for a historical day in fetched history', () {
      final history = MinutesHistoryResponse(
        deviceId: 'WM001',
        timezone: 'UTC',
        slotMinutes: 1,
        days: [
          MinutesDaySeries(
            date: '2026-06-12',
            startAt: '2026-06-12T00:00:00Z',
            v: List<double>.filled(1440, 0.5),
          ),
          MinutesDaySeries(
            date: '2026-06-15',
            startAt: '2026-06-15T00:00:00Z',
            v: List<double>.filled(870, 0.1),
          ),
        ],
      );

      final from = DateTime(2026, 6, 12);
      final to = DateTime(2026, 6, 13);
      final usage = UsageAggregation.buildUsage(
        deviceId: 'WM001',
        from: from,
        to: to,
        granularity: Granularity.h1,
        minutes: UsageAggregation.flattenHistory(history),
        previousMinutes: const [],
      );

      expect(usage.dataPoints, isNotEmpty);
      expect(usage.summary.totalVolumeLiters, greaterThan(0));
    });
  });
}
