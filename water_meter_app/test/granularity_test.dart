import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/usage_response.dart';
import 'package:water_meter_app/core/utils/granularity.dart';

void main() {
  group('GranularityRules', () {
    test('defaultForRange picks finest sensible granularity', () {
      final now = DateTime(2026, 6, 6, 14, 0);
      final from6h = now.subtract(const Duration(hours: 5));
      expect(
        GranularityRules.defaultForRange(from6h, now),
        Granularity.m1,
      );

      final from1d = now.subtract(const Duration(hours: 20));
      expect(
        GranularityRules.defaultForRange(from1d, now),
        Granularity.m5,
      );

      final from7d = now.subtract(const Duration(days: 6));
      expect(
        GranularityRules.defaultForRange(from7d, now),
        Granularity.m15,
      );

      final from30d = now.subtract(const Duration(days: 25));
      expect(
        GranularityRules.defaultForRange(from30d, now),
        Granularity.h1,
      );

      final fromYear = now.subtract(const Duration(days: 60));
      expect(
        GranularityRules.defaultForRange(fromYear, now),
        Granularity.d1,
      );
    });

    test('allowedForRange excludes granularities beyond max range', () {
      final now = DateTime(2026, 6, 6);
      final from = now.subtract(const Duration(hours: 30));
      final allowed = GranularityRules.allowedForRange(from, now);

      expect(allowed, contains(Granularity.m5));
      expect(allowed, isNot(contains(Granularity.m1)));
    });

    test('resolve falls back when preferred granularity is invalid', () {
      final now = DateTime(2026, 6, 6);
      final from = now.subtract(const Duration(days: 14));

      final resolved = GranularityRules.resolve(from, now, Granularity.m1);
      expect(resolved, isNot(Granularity.m1));
      expect(GranularityRules.isAllowed(resolved, from, now), isTrue);
    });

    test('isAllowed respects per-granularity max range', () {
      final now = DateTime(2026, 6, 6);
      final from = now.subtract(const Duration(hours: 30));

      expect(GranularityRules.isAllowed(Granularity.m1, from, now), isFalse);
      expect(GranularityRules.isAllowed(Granularity.m5, from, now), isTrue);
    });
  });

  group('DateRangePreset', () {
    test('today range starts at midnight', () {
      final now = DateTime(2026, 6, 6, 15, 30);
      final range = DateRangePreset.today.range(now);

      expect(range.from, DateTime(2026, 6, 6));
      expect(range.to, now);
    });
  });
}
