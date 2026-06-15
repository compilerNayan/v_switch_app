import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/water_unit.dart';

void main() {
  test('locationLabel includes block wing floor and flat', () {
    const unit = WaterUnit(
      id: 'u1',
      name: 'D205',
      deviceId: 'WM000001',
      block: 'A',
      wing: 'East',
      floor: '2',
      flatNumber: '205',
    );

    expect(
      unit.locationLabel,
      'Block A · Wing East · Floor 2 · Flat 205',
    );
  });

  test('displaySubtitle uses location without meter serial', () {
    const unit = WaterUnit(
      id: 'u1',
      name: 'D205',
      deviceId: 'WM000001',
      block: 'A',
      wing: 'East',
    );

    expect(unit.displaySubtitle, 'Block A · Wing East');
    expect(unit.displaySubtitle, isNot(contains('WM000001')));
  });

  test('ownerLabel returns trimmed resident name', () {
    const unit = WaterUnit(
      id: 'u1',
      name: 'D205',
      deviceId: 'WM000001',
      residentName: '  Ravi Kumar  ',
    );

    expect(unit.ownerLabel, 'Ravi Kumar');
  });
}
