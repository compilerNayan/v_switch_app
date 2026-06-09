import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/api/building_api_client.dart';
import 'package:water_meter_app/core/api/mock_water_api_client.dart';
import 'package:water_meter_app/core/models/current_reading.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/building_providers.dart';
import 'package:water_meter_app/core/providers/device_tile_providers.dart';
import 'package:water_meter_app/core/providers/unit_providers.dart';

WaterUnit _unit({
  required String id,
  required String deviceId,
  String block = '',
  String wing = '',
}) {
  return WaterUnit(
    id: id,
    name: id,
    deviceId: deviceId,
    block: block,
    wing: wing,
  );
}

CurrentReading _reading(String deviceId) {
  return CurrentReading(
    deviceId: deviceId,
    timestamp: DateTime.now().toUtc(),
    flowRateLpm: 1,
    cumulativeLiters: 100,
    status: WaterDeviceStatus.flowing,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('filteredBuildingOverviewProvider uses API summary when no filter', () async {
    const summary = BuildingSummary(
      totalTodayLiters: 500,
      totalMonthLiters: 5000,
      activeAlerts: 2,
      unitsOnline: 4,
      unitsOffline: 1,
      unitsTotal: 5,
      topConsumers: [],
    );

    final container = ProviderContainer(
      overrides: [
        buildingSummaryProvider.overrideWith((ref) async => summary),
      ],
    );
    addTearDown(container.dispose);

    final result =
        await container.read(filteredBuildingOverviewProvider.future);
    expect(result.totalTodayLiters, 500);
    expect(result.unitsTotal, 5);
    expect(result.activeAlerts, 2);
  });

  test('filteredBuildingOverviewProvider aggregates filtered units', () async {
    final units = [
      _unit(id: 'a1', deviceId: 'd1', block: 'A', wing: 'East'),
      _unit(id: 'a2', deviceId: 'd2', block: 'A', wing: 'West'),
      _unit(id: 'b1', deviceId: 'd3', block: 'B', wing: 'East'),
    ];

    final container = ProviderContainer(
      overrides: [
        waterUnitsProvider.overrideWith((ref) async => units),
        selectedBlocksProvider.overrideWith((ref) => {'A'}),
        waterApiClientProvider.overrideWithValue(MockWaterApiClient(seed: 1)),
        timezoneProvider.overrideWith((ref) => 'UTC'),
        deviceTodayUsageProvider('d1').overrideWith((ref) async => 10),
        deviceTodayUsageProvider('d2').overrideWith((ref) async => 20),
        deviceTodayUsageProvider('d3').overrideWith((ref) async => 30),
        deviceCurrentReadingProvider('d1')
            .overrideWith((ref) async => _reading('d1')),
        deviceCurrentReadingProvider('d2')
            .overrideWith((ref) async => _reading('d2')),
        deviceCurrentReadingProvider('d3')
            .overrideWith((ref) async => _reading('d3')),
      ],
    );
    addTearDown(container.dispose);

    await container.read(waterUnitsProvider.future);
    final result =
        await container.read(filteredBuildingOverviewProvider.future);
    expect(result.totalTodayLiters, 30);
    expect(result.unitsTotal, 2);
    expect(result.unitsOnline, 2);
    expect(result.unitsOffline, 0);
  });
}
