import '../models/current_reading.dart';
import '../models/daily_summary.dart';
import '../models/usage_response.dart';

abstract class WaterApiClient {
  Future<CurrentReading> getCurrentReading(String deviceId);

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
}
