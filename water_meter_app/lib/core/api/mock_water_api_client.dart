import 'dart:math';

import '../models/current_reading.dart';
import '../models/daily_summary.dart';
import '../models/quota_config.dart';
import '../models/usage_response.dart';
import '../models/valve_state.dart';
import 'api_exceptions.dart';
import 'water_api_client.dart';

class _MockValveState {
  double targetPressurePercent = 100;
  double lastUserPressurePercent = 100;
}

class _MockQuotaConfig {
  bool enabled = false;
  double dailyLimitLiters = 500;
  List<QuotaStep> steps = const [
    QuotaStep(atLitersUsed: 300, action: QuotaStepAction.reducePressure, value: 20),
    QuotaStep(atLitersUsed: 400, action: QuotaStepAction.reducePressure, value: 20),
    QuotaStep(atLitersUsed: 500, action: QuotaStepAction.turnOff),
  ];
}

/// Generates realistic water consumption data for UI development.
class MockWaterApiClient implements WaterApiClient {
  MockWaterApiClient({
    int? seed,
    Future<bool> Function()? canManageQuota,
  })  : _random = Random(seed ?? 42),
        _canManageQuota = canManageQuota ?? (() async => true);

  final Random _random;
  final Future<bool> Function() _canManageQuota;

  final Map<String, _MockValveState> _valveStates = {};
  final Map<String, _MockQuotaConfig> _quotaConfigs = {};

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
    final peakPoint = points.isEmpty
        ? UsageDataPoint(timestamp: from, volumeLiters: 0, avgFlowRateLpm: 0)
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
          timestamp: peakPoint.timestamp,
          volumeLiters: peakPoint.volumeLiters,
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
  Future<ValveState> getValveState(String deviceId) async {
    await _delay();
    return _buildValveState(deviceId);
  }

  @override
  Future<ValveState> setValvePressure(
    String deviceId,
    ValveUpdateRequest request,
  ) async {
    await _delay();
    final valve = _valveFor(deviceId);

    if (request.action == 'restore') {
      valve.targetPressurePercent = valve.lastUserPressurePercent;
    } else if (request.pressurePercent != null) {
      final value = request.pressurePercent!.clamp(0, 100).toDouble();
      if (value == 0) {
        if (valve.targetPressurePercent > 0) {
          valve.lastUserPressurePercent = valve.targetPressurePercent;
        }
        valve.targetPressurePercent = 0;
      } else {
        valve.targetPressurePercent = value;
        valve.lastUserPressurePercent = value;
      }
    }

    return _buildValveState(deviceId);
  }

  @override
  Future<QuotaResponse> getQuota(String deviceId) async {
    await _delay();
    return _buildQuotaResponse(deviceId);
  }

  @override
  Future<QuotaResponse> updateQuota(
    String deviceId,
    QuotaUpdateRequest request,
  ) async {
    await _delay();
    if (!await _canManageQuota()) {
      throw const ApiException(
        statusCode: 403,
        error: ApiError(
          code: 'FORBIDDEN',
          message: 'Only admins can update quota settings',
        ),
      );
    }

    final config = _quotaFor(deviceId);
    config.enabled = request.enabled;
    config.dailyLimitLiters = request.dailyLimitLiters;
    config.steps = List<QuotaStep>.from(request.steps);

    return _buildQuotaResponse(deviceId);
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
      final base = _hourlyPatternLiters(hour.toDouble());
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

  _MockValveState _valveFor(String deviceId) {
    return _valveStates.putIfAbsent(deviceId, _MockValveState.new);
  }

  _MockQuotaConfig _quotaFor(String deviceId) {
    return _quotaConfigs.putIfAbsent(deviceId, _MockQuotaConfig.new);
  }

  double _todayUsedLiters() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final points = _generateBuckets(startOfToday, now, Granularity.h1);
    return points.fold<double>(0, (sum, p) => sum + p.volumeLiters);
  }

  ValveState _buildValveState(String deviceId) {
    final valve = _valveFor(deviceId);
    final quota = _quotaFor(deviceId);
    final usedLiters = _todayUsedLiters();
    final now = DateTime.now().toUtc();

    double? quotaCap;
    var controlMode = ValveControlMode.manual;
    var effective = valve.targetPressurePercent;

    if (quota.enabled) {
      final capResult = QuotaCalculator.computeCap(
        steps: quota.steps,
        usedLiters: usedLiters,
        dailyLimitLiters: quota.dailyLimitLiters,
      );
      quotaCap = capResult.capPercent;
      effective = min(valve.targetPressurePercent, quotaCap);
      if (quotaCap < valve.targetPressurePercent) {
        controlMode = ValveControlMode.quota;
      }
    }

    final actual =
        (effective - 1 + _random.nextDouble() * 2).clamp(0, 100).toDouble();

    return ValveState(
      deviceId: deviceId,
      timestamp: now,
      targetPressurePercent: valve.targetPressurePercent,
      actualPressurePercent: actual,
      lastUserPressurePercent: valve.lastUserPressurePercent,
      isOff: valve.targetPressurePercent == 0,
      controlMode: controlMode,
      quotaCapPercent: quotaCap,
      effectivePressurePercent: effective,
    );
  }

  QuotaResponse _buildQuotaResponse(String deviceId) {
    final quota = _quotaFor(deviceId);
    final usedLiters = _todayUsedLiters();
    final today = DateTime.now();
    final capResult = QuotaCalculator.computeCap(
      steps: quota.steps,
      usedLiters: usedLiters,
      dailyLimitLiters: quota.dailyLimitLiters,
    );

    return QuotaResponse(
      deviceId: deviceId,
      enabled: quota.enabled,
      dailyLimitLiters: quota.dailyLimitLiters,
      timezone: today.timeZoneName,
      steps: List<QuotaStep>.from(quota.steps),
      status: QuotaStatus(
        date: DateTime(today.year, today.month, today.day),
        usedLiters: usedLiters,
        activeStepIndex: capResult.activeStepIndex,
        quotaCapPercent: quota.enabled ? capResult.capPercent : null,
        remainingLiters: capResult.remainingLiters,
        nextStepAtLiters: capResult.nextStepAtLiters,
      ),
    );
  }

  Future<void> _delay() => Future<void>.delayed(
        Duration(milliseconds: 200 + _random.nextInt(300)),
      );
}
