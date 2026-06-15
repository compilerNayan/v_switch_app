import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:water_meter_app/core/dummy/dummy_device_generator.dart';
import 'package:water_meter_app/core/dummy/indian_names.dart';

void main() {
  group('DummyDeviceGenerator', () {
    test('generates structure within configured bounds', () {
      final random = Random(7);
      final structure = DummyDeviceGenerator.generateStructure(random);

      expect(structure.blocks.length, inInclusiveRange(3, 5));
      for (final block in structure.blocks) {
        expect(block.wings.length, inInclusiveRange(2, 3));
        for (final wing in block.wings) {
          expect(wing.floorCount, inInclusiveRange(10, 15));
        }
      }
    });

    test('generates unique serials and resident details', () {
      final random = Random(3);
      final structure = DummyDeviceGenerator.generateStructure(random);
      final devices = DummyDeviceGenerator.generateDevices(
        count: 50,
        structure: structure,
        random: random,
      );

      expect(devices.length, 50);
      expect(devices.map((d) => d.serialNumber).toSet().length, 50);
      final digitInName = RegExp(r'\d');
      for (final device in devices) {
        expect(device.serialNumber.length, 9);
        expect(device.residentName.trim().isNotEmpty, isTrue);
        expect(digitInName.hasMatch(device.residentName), isFalse);
        expect(device.phoneNumber.startsWith('+91'), isTrue);
        expect(device.block.isNotEmpty, isTrue);
        expect(device.wing.isNotEmpty, isTrue);
        expect(device.floor.isNotEmpty, isTrue);
      }
    });

    test('name pool supports many combinations without digit suffixes', () {
      expect(kIndianFirstNames.length, greaterThanOrEqualTo(40));
      expect(kIndianLastNames.length, greaterThanOrEqualTo(40));
      expect(
        kIndianFirstNames.length * kIndianLastNames.length,
        greaterThanOrEqualTo(1000),
      );
      final digit = RegExp(r'\d');
      for (final name in [...kIndianFirstNames, ...kIndianLastNames]) {
        expect(digit.hasMatch(name), isFalse, reason: 'name "$name" has digits');
      }
    });
  });
}
