import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('addWaterUnit persists and dedupes by deviceId', () async {
    final storage = await PreferencesStorage.create();
    const unit = WaterUnit(
      id: 'wm-ABC',
      name: 'D205',
      deviceId: 'ABC123',
    );

    await storage.addWaterUnit(unit);
    await storage.addWaterUnit(unit);

    final units = storage.getWaterUnits();
    expect(units, hasLength(1));
    expect(units.first.name, 'D205');
    expect(units.first.unitInviteCode, isNotNull);
  });

  test('migrates legacy enrolled serial', () async {
    SharedPreferences.setMockInitialValues({
      'enrolled_device_serial': 'OLD99',
    });
    final storage = await PreferencesStorage.create();
    final units = storage.getWaterUnits();
    expect(units, hasLength(1));
    expect(units.first.deviceId, 'OLD99');
  });

  test('migrates legacy user_devices JSON with typeId', () async {
    SharedPreferences.setMockInitialValues({
      'user_devices':
          '[{"id":"wm-X","typeId":"water_meter","name":"Kitchen","deviceId":"X"}]',
    });
    final storage = await PreferencesStorage.create();
    final units = storage.getWaterUnits();
    expect(units.single.name, 'Kitchen');
  });
}
