import '../models/daily_summary.dart';
import '../models/minute_series.dart';
import '../models/usage_response.dart' show Granularity, PeakBucket, UsageDataPoint, UsageResponse, UsageSummary;

/// Client-side bucketing of per-minute liter arrays into chart responses.
class UsageAggregation {
  UsageAggregation._();

  static List<({DateTime timestamp, double liters})> flattenHistory(
    MinutesHistoryResponse history,
  ) {
    final points = <({DateTime timestamp, double liters})>[];
    for (final day in history.days) {
      final start = DateTime.parse(day.startAt).toLocal();
      for (var i = 0; i < day.v.length; i++) {
        points.add((
          timestamp: start.add(Duration(minutes: i)),
          liters: day.v[i],
        ));
      }
    }
    return points;
  }

  static List<({DateTime timestamp, double liters})> flattenToday(
    MinutesTodayResponse today,
  ) {
    final start = DateTime.parse(today.startAt).toLocal();
    return [
      for (var i = 0; i < today.v.length; i++)
        (
          timestamp: start.add(Duration(minutes: i)),
          liters: today.v[i],
        ),
    ];
  }

  static UsageResponse buildUsage({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required Granularity granularity,
    required List<({DateTime timestamp, double liters})> minutes,
    required List<({DateTime timestamp, double liters})> previousMinutes,
  }) {
    final filtered =
        minutes.where((m) => !m.timestamp.isBefore(from) && !m.timestamp.isAfter(to)).toList();
    final buckets = _bucket(filtered, granularity);
    final prevFiltered = previousMinutes
        .where((m) => !m.timestamp.isBefore(from.subtract(to.difference(from))) && m.timestamp.isBefore(from))
        .toList();
    final prevBuckets = _bucket(prevFiltered, granularity);

    final total = buckets.fold<double>(0, (s, b) => s + b.liters);
    final prevTotal = prevBuckets.fold<double>(0, (s, b) => s + b.liters);
    final avg = buckets.isEmpty ? 0.0 : total / buckets.length;
    final peak = buckets.isEmpty
        ? (timestamp: from, liters: 0.0)
        : buckets.reduce((a, b) => a.liters >= b.liters ? a : b);
    final delta = prevTotal <= 0 ? 0.0 : ((total - prevTotal) / prevTotal) * 100;

    return UsageResponse(
      deviceId: deviceId,
      from: from,
      to: to,
      granularity: granularity,
      unit: 'liters',
      dataPoints: buckets
          .map(
            (b) => UsageDataPoint(
              timestamp: b.timestamp,
              volumeLiters: b.liters,
              avgFlowRateLpm: b.liters,
            ),
          )
          .toList(),
      summary: UsageSummary(
        totalVolumeLiters: total,
        averagePerBucketLiters: avg,
        peakBucket: PeakBucket(timestamp: peak.timestamp, volumeLiters: peak.liters),
        previousPeriodTotalLiters: prevTotal,
        deltaPercent: delta,
      ),
    );
  }

  static DailySummaryResponse buildDailySummary(
    MinutesHistoryResponse history, {
    required DateTime from,
    required DateTime to,
  }) {
    final days = <DailySummaryDay>[];
    for (final day in history.days) {
      final date = DateTime.parse(day.date);
      if (date.isBefore(DateTime(from.year, from.month, from.day)) ||
          date.isAfter(DateTime(to.year, to.month, to.day))) {
        continue;
      }
      var peakHour = 0;
      var peakHourLiters = 0.0;
      final hourTotals = List<double>.filled(24, 0);
      for (var i = 0; i < day.v.length; i++) {
        final hour = i ~/ 60;
        hourTotals[hour] += day.v[i];
      }
      for (var h = 0; h < 24; h++) {
        if (hourTotals[h] > peakHourLiters) {
          peakHourLiters = hourTotals[h];
          peakHour = h;
        }
      }
      final total = day.v.fold<double>(0, (s, v) => s + v);
      days.add(
        DailySummaryDay(
          date: date,
          totalLiters: total,
          peakHour: peakHour,
          peakHourLiters: peakHourLiters,
        ),
      );
    }
    return DailySummaryResponse(unit: 'liters', days: days);
  }

  static HourlyPatternResponse buildHourlyPattern(MinutesHistoryResponse history) {
    final hourMinuteValues = List.generate(24, (_) => <double>[]);
    for (final day in history.days) {
      for (var i = 0; i < day.v.length; i++) {
        hourMinuteValues[i ~/ 60].add(day.v[i]);
      }
    }
    final hours = <HourlyPatternHour>[];
    for (var h = 0; h < 24; h++) {
      final values = hourMinuteValues[h];
      final avg = values.isEmpty
          ? 0.0
          : values.fold<double>(0, (s, v) => s + v) / values.length;
      hours.add(HourlyPatternHour(hour: h, avgLiters: avg));
    }
    return HourlyPatternResponse(unit: 'liters', hours: hours);
  }

  static List<({DateTime timestamp, double liters})> _bucket(
    List<({DateTime timestamp, double liters})> minutes,
    Granularity granularity,
  ) {
    if (minutes.isEmpty) return [];
    final bucketSeconds = granularity.bucketDuration.inSeconds;
    final map = <int, double>{};

    for (final minute in minutes) {
      final epoch = minute.timestamp.millisecondsSinceEpoch ~/ 1000;
      final bucketStart = (epoch ~/ bucketSeconds) * bucketSeconds;
      map[bucketStart] = (map[bucketStart] ?? 0) + minute.liters;
    }

    final keys = map.keys.toList()..sort();
    return keys
        .map(
          (k) => (
            timestamp: DateTime.fromMillisecondsSinceEpoch(k * 1000),
            liters: map[k]!,
          ),
        )
        .toList();
  }

  static int daysForRange(DateTime from, DateTime to) {
    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    return end.difference(start).inDays + 1;
  }
}
