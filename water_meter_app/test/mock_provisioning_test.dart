import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/provisioning/enrollment_client.dart';
import 'package:water_meter_app/core/provisioning/mock_enrollment_client.dart';
import 'package:water_meter_app/core/provisioning/provisioning_state.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/provisioning_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('MockEnrollmentClient succeeds without network', () async {
    const client = MockEnrollmentClient(delayMs: 0);
    final result = await client.enroll('WM123456');
    expect(result, isA<EnrollmentSuccess>());
  });

  test('mockEnrollAndRegister creates device with display name', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(provisioningNotifierProvider.notifier);
    notifier.assignMockSerial();
    notifier.setDeviceDisplayName('D205');

    final ok = await notifier.mockEnrollAndRegister();
    expect(ok, isTrue);

    final state = container.read(provisioningNotifierProvider);
    expect(state.step, WaterMeterSetupStep.success);
    expect(state.deviceDisplayName, 'D205');
    expect(state.deviceSerial, isNotNull);

    final prefs = await container.read(preferencesStorageProvider.future);
    final devices = await prefs.getUserDevices();
    expect(devices.single.name, 'D205');
  });
}
