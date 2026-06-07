import '../models/usage_response.dart';

/// Client-side granularity rules aligned with the API contract.
class GranularityRules {
  GranularityRules._();

  static const _maxRangeForGranularity = {
    Granularity.m1: Duration(hours: 24),
    Granularity.m5: Duration(days: 7),
    Granularity.m15: Duration(days: 30),
    Granularity.m30: Duration(days: 90),
    Granularity.h1: Duration(days: 365),
    Granularity.d1: Duration(days: 3650),
  };

  static Duration rangeDuration(DateTime from, DateTime to) {
    return to.difference(from);
  }

  static Granularity defaultForRange(DateTime from, DateTime to) {
    final range = rangeDuration(from, to);
    if (range <= const Duration(hours: 6)) return Granularity.m1;
    if (range <= const Duration(days: 1)) return Granularity.m5;
    if (range <= const Duration(days: 7)) return Granularity.m15;
    if (range <= const Duration(days: 30)) return Granularity.h1;
    return Granularity.d1;
  }

  static List<Granularity> allowedForRange(DateTime from, DateTime to) {
    final range = rangeDuration(from, to);
    return Granularity.values
        .where((g) => range <= (_maxRangeForGranularity[g] ?? Duration.zero))
        .toList();
  }

  static bool isAllowed(Granularity granularity, DateTime from, DateTime to) {
    final range = rangeDuration(from, to);
    final max = _maxRangeForGranularity[granularity];
    return max != null && range <= max;
  }

  /// Returns [preferred] if valid for the range, otherwise the default.
  static Granularity resolve(
    DateTime from,
    DateTime to,
    Granularity? preferred,
  ) {
    if (preferred != null && isAllowed(preferred, from, to)) {
      return preferred;
    }
    return defaultForRange(from, to);
  }
}

enum DateRangePreset {
  today,
  yesterday,
  last7Days,
  last30Days,
}

extension DateRangePresetX on DateRangePreset {
  String get label {
    switch (this) {
      case DateRangePreset.today:
        return 'Today';
      case DateRangePreset.yesterday:
        return 'Yesterday';
      case DateRangePreset.last7Days:
        return '7 days';
      case DateRangePreset.last30Days:
        return '30 days';
    }
  }

  ({DateTime from, DateTime to}) range(DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    switch (this) {
      case DateRangePreset.today:
        return (from: startOfToday, to: now);
      case DateRangePreset.yesterday:
        final yesterday = startOfToday.subtract(const Duration(days: 1));
        return (
          from: yesterday,
          to: startOfToday,
        );
      case DateRangePreset.last7Days:
        return (
          from: startOfToday.subtract(const Duration(days: 6)),
          to: now,
        );
      case DateRangePreset.last30Days:
        return (
          from: startOfToday.subtract(const Duration(days: 29)),
          to: now,
        );
    }
  }
}
