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
  });
}
