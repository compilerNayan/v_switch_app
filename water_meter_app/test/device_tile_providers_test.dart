import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/api/mock_water_api_client.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/device_tile_providers.dart';

void main() {
  test('deviceValveProvider fetches state for given deviceId', () async {
    final container = ProviderContainer(
      overrides: [
        waterApiClientProvider.overrideWithValue(MockWaterApiClient(seed: 1)),
        timezoneProvider.overrideWith((ref) => 'UTC'),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(deviceValveProvider('WM-TEST').future);
    expect(state.deviceId, 'WM-TEST');
    expect(state.isOff, isFalse);
  });

  test('deviceCurrentReadingProvider fetches reading for given deviceId', () async {
    final container = ProviderContainer(
      overrides: [
        waterApiClientProvider.overrideWithValue(MockWaterApiClient(seed: 1)),
        timezoneProvider.overrideWith((ref) => 'UTC'),
      ],
    );
    addTearDown(container.dispose);

    final reading =
        await container.read(deviceCurrentReadingProvider('WM-TEST').future);
    expect(reading.deviceId, 'WM-TEST');
  });
}
