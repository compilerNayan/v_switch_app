import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/iot_device_type.dart';

void main() {
  test('catalog includes standard device types', () {
    final ids = IoTDeviceType.catalog.map((d) => d.id).toSet();
    expect(ids, containsAll([
      'switch',
      'smart_plug',
      'robot',
      'water_meter',
      'light',
      'thermostat',
      'camera',
      'door_lock',
      'sensor',
      'hub',
    ]));
    expect(IoTDeviceType.catalog.every((d) => !d.isSupported), isFalse);
    final waterMeter = IoTDeviceType.catalog.firstWhere((d) => d.id == 'water_meter');
    expect(waterMeter.isSupported, isTrue);
  });
}
