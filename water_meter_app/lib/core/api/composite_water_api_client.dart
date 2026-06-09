import '../models/current_reading.dart';
import '../models/daily_summary.dart';
import '../models/quota_config.dart';
import '../models/usage_response.dart';
import '../models/valve_state.dart';
import 'water_api_client.dart';

/// Delegates live water reads to the remote API and quota to a mock delegate
/// until backend quota endpoints exist.
class CompositeWaterApiClient implements WaterApiClient {
  CompositeWaterApiClient({
    required WaterApiClient remote,
    required WaterApiClient quotaDelegate,
  })  : _remote = remote,
        _quotaDelegate = quotaDelegate;

  final WaterApiClient _remote;
  final WaterApiClient _quotaDelegate;

  @override
  Future<CurrentReading> getCurrentReading(String deviceId) =>
      _remote.getCurrentReading(deviceId);

  @override
  Future<DailySummaryResponse> getDailySummary({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) =>
      _remote.getDailySummary(
        deviceId: deviceId,
        from: from,
        to: to,
        timezone: timezone,
      );

  @override
  Future<HourlyPatternResponse> getHourlyPattern({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required String timezone,
  }) =>
      _remote.getHourlyPattern(
        deviceId: deviceId,
        from: from,
        to: to,
        timezone: timezone,
      );

  @override
  Future<QuotaResponse> getQuota(String deviceId) =>
      _quotaDelegate.getQuota(deviceId);

  @override
  Future<QuotaResponse> updateQuota(
    String deviceId,
    QuotaUpdateRequest request,
  ) =>
      _quotaDelegate.updateQuota(deviceId, request);

  @override
  Future<UsageResponse> getUsage({
    required String deviceId,
    required DateTime from,
    required DateTime to,
    required Granularity granularity,
    required String timezone,
  }) =>
      _remote.getUsage(
        deviceId: deviceId,
        from: from,
        to: to,
        granularity: granularity,
        timezone: timezone,
      );

  @override
  Future<ValveState> getValveState(String deviceId) =>
      _remote.getValveState(deviceId);

  @override
  Future<ValveState> setValvePressure(
    String deviceId,
    ValveUpdateRequest request,
  ) =>
      _remote.setValvePressure(deviceId, request);
}
