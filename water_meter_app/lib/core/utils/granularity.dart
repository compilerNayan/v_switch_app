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

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return startOfDay(date).add(const Duration(days: 1));
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Bucket sizes offered for the single-day bar chart.
  static List<Granularity> barGranularitiesForDay(DateTime day, DateTime now) {
    final from = startOfDay(day);
    final to = isSameDay(day, now) ? now : endOfDay(day);
    const preferred = [
      Granularity.m15,
      Granularity.m30,
      Granularity.h1,
      Granularity.m5,
      Granularity.m1,
    ];
    return preferred.where((g) => isAllowed(g, from, to)).toList();
  }

  static Granularity defaultBarGranularityForDay(DateTime day, DateTime now) {
    final allowed = barGranularitiesForDay(day, now);
    if (allowed.contains(Granularity.m30)) return Granularity.m30;
    return allowed.isNotEmpty ? allowed.first : Granularity.h1;
  }
}

enum CumulativeRangePreset {
  oneDay,
  sevenDays,
  thirtyDays,
}

extension CumulativeRangePresetX on CumulativeRangePreset {
  String get label {
    switch (this) {
      case CumulativeRangePreset.oneDay:
        return '1 day';
      case CumulativeRangePreset.sevenDays:
        return '7 days';
      case CumulativeRangePreset.thirtyDays:
        return '30 days';
    }
  }

  ({DateTime from, DateTime to}) range(DateTime now) {
    final startOfToday = GranularityRules.startOfDay(now);
    switch (this) {
      case CumulativeRangePreset.oneDay:
        return (from: startOfToday, to: now);
      case CumulativeRangePreset.sevenDays:
        return (
          from: startOfToday.subtract(const Duration(days: 6)),
          to: now,
        );
      case CumulativeRangePreset.thirtyDays:
        return (
          from: startOfToday.subtract(const Duration(days: 29)),
          to: now,
        );
    }
  }

  Granularity defaultGranularity() {
    switch (this) {
      case CumulativeRangePreset.oneDay:
        return Granularity.m30;
      case CumulativeRangePreset.sevenDays:
        return Granularity.h1;
      case CumulativeRangePreset.thirtyDays:
        return Granularity.d1;
    }
  }
}

enum DateRangePreset {
  today,
  yesterday,
}

extension DateRangePresetX on DateRangePreset {
  String get label {
    switch (this) {
      case DateRangePreset.today:
        return 'Today';
      case DateRangePreset.yesterday:
        return 'Yesterday';
    }
  }

  ({DateTime from, DateTime to}) range(DateTime now) {
    final startOfToday = GranularityRules.startOfDay(now);
    switch (this) {
      case DateRangePreset.today:
        return (from: startOfToday, to: now);
      case DateRangePreset.yesterday:
        final yesterday = startOfToday.subtract(const Duration(days: 1));
        return (
          from: yesterday,
          to: startOfToday,
        );
    }
  }

  DateTime day(DateTime now) {
    switch (this) {
      case DateRangePreset.today:
        return GranularityRules.startOfDay(now);
      case DateRangePreset.yesterday:
        return GranularityRules.startOfDay(now).subtract(const Duration(days: 1));
    }
  }
}
