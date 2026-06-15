import 'dart:math';

import '../models/tenant_config.dart';
import 'dummy_device_enrollment_draft.dart';
import 'indian_names.dart';

class BuildingSlot {
  const BuildingSlot({
    required this.blockId,
    required this.blockLabel,
    required this.wing,
    required this.floor,
  });

  final String blockId;
  final String blockLabel;
  final String wing;
  final int floor;
}

class DummyDeviceGenerator {
  DummyDeviceGenerator._();

  static const _wingNames = ['North', 'South', 'East', 'West', 'Central'];
  static const _base36 = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  static TenantStructure generateStructure(Random random) {
    final blockCount = 3 + random.nextInt(3);
    final blocks = <TenantBlock>[];

    for (var blockIndex = 0; blockIndex < blockCount; blockIndex++) {
      final blockId = String.fromCharCode(65 + blockIndex);
      final wingCount = 2 + random.nextInt(2);
      final wings = <TenantWing>[];

      for (var wingIndex = 0; wingIndex < wingCount; wingIndex++) {
        final floorCount = 10 + random.nextInt(6);
        wings.add(
          TenantWing(
            name: _wingNames[wingIndex],
            floorCount: floorCount,
          ),
        );
      }

      blocks.add(
        TenantBlock(
          id: blockId,
          label: 'Block $blockId',
          wings: wings,
        ),
      );
    }

    return TenantStructure(blocks: blocks);
  }

  static List<BuildingSlot> allSlots(TenantStructure structure) {
    final slots = <BuildingSlot>[];
    for (final block in structure.blocks) {
      for (final wing in block.wings) {
        for (var floor = 1; floor <= wing.floorCount; floor++) {
          slots.add(
            BuildingSlot(
              blockId: block.id,
              blockLabel: block.label,
              wing: wing.name,
              floor: floor,
            ),
          );
        }
      }
    }
    return slots;
  }

  static List<DummyDeviceEnrollmentDraft> generateDevices({
    required int count,
    required TenantStructure structure,
    required Random random,
  }) {
    if (count <= 0) return const [];

    final slots = allSlots(structure);
    if (slots.isEmpty) {
      throw StateError('Generated building structure has no floor slots');
    }

    final serials = <String>{};
    final devices = <DummyDeviceEnrollmentDraft>[];

    for (var index = 0; index < count; index++) {
      final slot = slots[random.nextInt(slots.length)];
      late final String serial;
      do {
        serial = randomSerial(random);
      } while (!serials.add(serial));

      final firstName = kIndianFirstNames[random.nextInt(kIndianFirstNames.length)];
      final lastName = kIndianLastNames[random.nextInt(kIndianLastNames.length)];
      final residentName = '$firstName $lastName';
      final flatNumber =
          '${slot.blockId}${slot.wing[0]}${slot.floor}${(index % 90) + 10}';

      devices.add(
        DummyDeviceEnrollmentDraft(
          serialNumber: serial,
          name: 'Flat $flatNumber',
          flatNumber: flatNumber,
          floor: slot.floor.toString(),
          block: slot.blockId,
          wing: slot.wing,
          residentName: residentName,
          phoneNumber: randomIndianPhone(random),
        ),
      );
    }

    return devices;
  }

  static String randomSerial(Random random) {
    return List.generate(
      9,
      (_) => _base36[random.nextInt(_base36.length)],
    ).join();
  }

  static String randomIndianPhone(Random random) {
    final firstDigit = 6 + random.nextInt(4);
    final rest = List.generate(9, (_) => random.nextInt(10)).join();
    return '+91$firstDigit$rest';
  }
}
