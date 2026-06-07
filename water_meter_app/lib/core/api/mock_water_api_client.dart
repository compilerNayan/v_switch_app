import 'dart:math';

import '../models/current_reading.dart';
import '../models/daily_summary.dart';
import '../models/usage_response.dart';
import 'water_api_client.dart';

/// Generates realistic water consumption data for UI development.
class MockWaterApiClient implements WaterApiClient {
  MockWaterApiClient({int? seed}) : _random = Random(seed ?? 42);

  final Random _random;

  static const _baseDailyLiters = 140.0;

  @override
  Future<CurrentReading> getCurrentReading(String deviceId) async {
    await _delay();
    final now = DateTime.now().toUtc();
    final hour = now.hour + now.minute / 60.0;
    final flow = _flowRateForHour(hour);

    return CurrentReading(
      deviceId: deviceId,
      timestamp: now,
      flowRateLpm: flow,
      cumulativeLiters: 125430.5 + _random.nextDouble() * 10,
      status: flow > 0.5
          ? WaterDeviceStatus.flowing
          : WaterDeviceStatus.idle,
    );
  }

  @override
  Future<UsageResponse> getUsage({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required Granularity granularity,
    required String timezone,
  }) async {
    await _delay();
    final points = _generateBuckets(from, to, granularity);
    final total = points.fold<double>(0, (sum, p) => sum + p.volumeLiters);
    final avg = points.isEmpty ? 0.0 : total / points.length;
    final peak = points.isEmpty
        ? PeakBucket(timestamp: from, volumeLiters: 0)
        : points.reduce(
            (a, b) => a.volumeLiters >= b.volumeLiters ? a : b,
          );

    final range = to.difference(from);
    final prevFrom = from.subtract(range);
    final prevPoints = _generateBuckets(prevFrom, from, granularity);
    final prevTotal =
        prevPoints.fold<double>(0, (sum, p) => sum + p.volumeLiters);
    final delta = prevTotal == 0
        ? 0.0
        : ((total - prevTotal) / prevTotal) * 100;

    return UsageResponse(
      deviceId: deviceId,
      from: from.toUtc(),
      to: to.toUtc(),
      granularity: granularity,
      unit: 'liters',
      dataPoints: points,
      summary: UsageSummary(
        totalVolumeLiters: total,
        averagePerBucketLiters: avg,
        peakBucket: PeakBucket(
          timestamp: peak.timestamp,
          volumeLiters: peak.volumeLiters,
        ),
        previousPeriodTotalLiters: prevTotal,
        deltaPercent: delta,
      ),
    );
  }

  @override
  Future<DailySummaryResponse> getDailySummary({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) async {
    await _delay();
    final days = <DailySummaryDay>[];
    var cursor = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);

    while (!cursor.isAfter(end)) {
      final weekday = cursor.weekday;
      final weekendFactor = (weekday == DateTime.saturday ||
              weekday == DateTime.sunday)
          ? 1.15
          : 1.0;
      final noise = 0.85 + _random.nextDouble() * 0.3;
      final total = _baseDailyLiters * weekendFactor * noise;
      final peakHour = 7 + _random.nextInt(12);
      days.add(
        DailySummaryDay(
          date: cursor,
          totalLiters: total,
          peakHour: peakHour,
          peakHourLiters: total * 0.12 + _random.nextDouble() * 5,
        ),
      );
      cursor = cursor.add(const Duration(days: 1));
    }

    return DailySummaryResponse(unit: 'liters', days: days);
  }

  @override
  Future<HourlyPatternResponse> getHourlyPattern({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) async {
    await _delay();
    final hours = List.generate(24, (hour) {
      final base = _hourlyPatternLiters(hour);
      final noise = 0.9 + _random.nextDouble() * 0.2;
      return HourlyPatternHour(hour: hour, avgLiters: base * noise);
    });
    return HourlyPatternResponse(unit: 'liters', hours: hours);
  }

  List<UsageDataPoint> _generateBuckets(
    DateTime from,
    DateTime to,
    Granularity granularity,
  ) {
    final points = <UsageDataPoint>[];
    var cursor = from;
    final step = granularity.bucketDuration;

    while (cursor.isBefore(to)) {
      final localHour = cursor.hour + cursor.minute / 60.0;
      final weekday = cursor.weekday;
      final weekendFactor = (weekday == DateTime.saturday ||
              weekday == DateTime.sunday)
          ? 1.1
          : 1.0;

      final minutesInBucket = step.inMinutes.clamp(1, 1440);
      final hourlyLiters = _hourlyPatternLiters(localHour) * weekendFactor;
      final bucketVolume =
          (hourlyLiters / 60.0) * minutesInBucket * (0.85 + _random.nextDouble() * 0.3);
      final avgFlow = bucketVolume / minutesInBucket;

      points.add(
        UsageDataPoint(
          timestamp: cursor.toUtc(),
          volumeLiters: bucketVolume,
          avgFlowRateLpm: avgFlow,
        ),
      );
      cursor = cursor.add(step);
    }

    return points;
  }

  double _hourlyPatternLiters(double hour) {
    // Morning peak ~7am, evening peak ~7pm, low overnight.
    final morning = exp(-pow(hour - 7, 2) / 8) * 8;
    final evening = exp(-pow(hour - 19, 2) / 10) * 10;
    final baseline = 0.8;
    return baseline + morning + evening;
  }

  double _flowRateForHour(double hour) {
    final pattern = _hourlyPatternLiters(hour);
    return pattern > 2 ? pattern / 3 + _random.nextDouble() * 0.5 : 0;
  }

  Future<void> _delay() => Future<void>.delayed(
        Duration(milliseconds: 200 + _random.nextInt(300)),
      );
}
