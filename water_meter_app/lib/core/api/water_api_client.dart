import 'dart:typed_data';

import '../models/current_reading.dart';
import '../models/daily_summary.dart';
import '../models/presence_activity.dart';
import '../models/quota_config.dart';
import '../models/usage_response.dart';
import '../models/valve_state.dart';

abstract class WaterApiClient {
  Future<CurrentReading> getCurrentReading(String deviceId);

  Future<ValveState> getValveState(String deviceId);

  Future<ValveState> setValvePressure(
    String deviceId,
    ValveUpdateRequest request,
  );

  Future<QuotaResponse> getQuota(String deviceId);

  Future<QuotaResponse> updateQuota(
    String deviceId,
    QuotaUpdateRequest request,
  );

  Future<UsageResponse> getUsage({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required Granularity granularity,
    required String timezone,
  });

  Future<DailySummaryResponse> getDailySummary({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required String timezone,
  });

  Future<HourlyPatternResponse> getHourlyPattern({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required String timezone,
  });

  Future<Uint8List> downloadDeviceLogs(String deviceId);

  Future<PresenceActivityResponse> getPresenceActivity({
    required String deviceId,
    String? date,
    String? from,
    String? to,
    int? days,
    String? timezone,
  });
}
