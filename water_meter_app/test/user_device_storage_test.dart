import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/models/user_device.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addUserDevice persists and dedupes by deviceId', () async {
    final storage = await PreferencesStorage.create();
    const device = UserDevice(
      id: 'wm-001',
      typeId: 'water_meter',
      name: 'Water Meter 001',
      deviceId: '001',
    );

    await storage.addUserDevice(device);
    await storage.addUserDevice(device);

    final devices = storage.getUserDevices();
    expect(devices, hasLength(1));
    expect(devices.first.deviceId, '001');
  });

  test('migrates legacy enrolled serial to user device list', () async {
    SharedPreferences.setMockInitialValues({
      'enrolled_device_serial': 'LEGACY01',
    });
    final storage = await PreferencesStorage.create();

    final devices = storage.getUserDevices();
    expect(devices, hasLength(1));
    expect(devices.first.deviceId, 'LEGACY01');
    expect(devices.first.typeId, 'water_meter');
  });
}
