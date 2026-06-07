import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/current_reading.dart';
import '../../core/models/daily_summary.dart';
import '../../core/models/usage_response.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/unit_providers.dart';
import '../../core/utils/granularity.dart';

final currentReadingProvider =
    FutureProvider.autoDispose<CurrentReading>((ref) async {
  final client = ref.watch(waterApiClientProvider);
  final deviceId = ref.watch(activeDeviceApiIdProvider);
  return client.getCurrentReading(deviceId);
});

class UsageQuery {
  const UsageQuery({
    required this.from,
    required this.to,
    required this.granularity,
  });

  final DateTime from;
  final DateTime to;
  final Granularity granularity;

  @override
  bool operator ==(Object other) {
    return other is UsageQuery &&
        other.from == from &&
        other.to == to &&
        other.granularity == granularity;
  }

  @override
  int get hashCode => Object.hash(from, to, granularity);
}

final usageQueryProvider = StateProvider<UsageQuery?>((ref) => null);

final usageResponseProvider =
    FutureProvider.autoDispose<UsageResponse>((ref) async {
  final query = ref.watch(usageQueryProvider);
  if (query == null) {
    final now = DateTime.now();
    final preset = DateRangePreset.today.range(now);
    final granularity = GranularityRules.defaultForRange(
      preset.from,
      preset.to,
    );
    final client = ref.watch(waterApiClientProvider);
    final deviceId = ref.watch(activeDeviceApiIdProvider);
    final timezone = ref.watch(timezoneProvider);
    return client.getUsage(
      deviceId: deviceId,
      from: preset.from,
      to: preset.to,
      granularity: granularity,
      timezone: timezone,
    );
  }

  final client = ref.watch(waterApiClientProvider);
  final deviceId = ref.watch(activeDeviceApiIdProvider);
  final timezone = ref.watch(timezoneProvider);
  return client.getUsage(
    deviceId: deviceId,
    from: query.from,
    to: query.to,
    granularity: query.granularity,
    timezone: timezone,
  );
});

final todayHourlyUsageProvider =
    FutureProvider.autoDispose<UsageResponse>((ref) async {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final client = ref.watch(waterApiClientProvider);
  final deviceId = ref.watch(activeDeviceApiIdProvider);
  final timezone = ref.watch(timezoneProvider);
  return client.getUsage(
    deviceId: deviceId,
    from: startOfToday,
    to: now,
    granularity: Granularity.h1,
    timezone: timezone,
  );
});

final dailySummaryProvider =
    FutureProvider.autoDispose<DailySummaryResponse>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 6));
  final client = ref.watch(waterApiClientProvider);
  final deviceId = ref.watch(activeDeviceApiIdProvider);
  final timezone = ref.watch(timezoneProvider);
  return client.getDailySummary(
    deviceId: deviceId,
    from: from,
    to: now,
    timezone: timezone,
  );
});

final hourlyPatternProvider =
    FutureProvider.autoDispose<HourlyPatternResponse>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day)
      .subtract(const Duration(days: 30));
  final client = ref.watch(waterApiClientProvider);
  final deviceId = ref.watch(activeDeviceApiIdProvider);
  final timezone = ref.watch(timezoneProvider);
  return client.getHourlyPattern(
    deviceId: deviceId,
    from: from,
    to: now,
    timezone: timezone,
  );
});
