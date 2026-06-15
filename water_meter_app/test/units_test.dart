import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/utils/units.dart';

void main() {
  group('VolumeFormatter', () {
    test('converts liters to US gallons', () {
      final gallons = VolumeFormatter.fromLiters(3.785411784, VolumeUnit.usGallons);
      expect(gallons, closeTo(1.0, 0.001));
    });

    test('format includes unit symbol', () {
      expect(
        VolumeFormatter.format(10, VolumeUnit.liters),
        '10.0 L',
      );
    });

    test('formatDashboard shows full precision with compact k subtitle', () {
      final display = VolumeFormatter.formatDashboard(1420.11, VolumeUnit.liters);
      expect(display.amount, '1,420.11');
      expect(display.unit, 'L');
      expect(display.primary, '1,420.11 L');
      expect(display.compact, '1.4k L');

      final small = VolumeFormatter.formatDashboard(45.2, VolumeUnit.liters);
      expect(small.amount, '45.20');
      expect(small.compact, isNull);
    });

    test('formatDashboard keeps two decimals at very high usage', () {
      final display =
          VolumeFormatter.formatDashboard(45000000, VolumeUnit.liters);
      expect(display.amount, '45,000,000.00');
      expect(display.primary, '45,000,000.00 L');
      expect(display.compact, '45,000.0k L');
    });
  });
}
