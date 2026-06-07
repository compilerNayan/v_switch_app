import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/provisioning_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('registerWaterMeter stores custom display name', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final device = await container
        .read(provisioningNotifierProvider.notifier)
        .registerWaterMeter(serial: 'ABC123', displayName: 'D205');

    expect(device.name, 'D205');
    expect(device.deviceId, 'ABC123');
    expect(device.id, 'wm-ABC123');

    final prefs = await container.read(preferencesStorageProvider.future);
    final devices = prefs.getWaterUnits();
    expect(devices.single.name, 'D205');
  });
}
