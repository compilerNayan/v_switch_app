import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_meter_app/core/models/top_consumers_config.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('TopConsumersDashboardConfig JSON round-trip', () {
    const config = TopConsumersDashboardConfig(
      showOverall: true,
      showByBlock: false,
      showByWing: true,
      topCount: 10,
      wingViewBlock: 'A',
    );
    final decoded = TopConsumersDashboardConfig.fromJson(config.toJson());
    expect(decoded.showByBlock, isFalse);
    expect(decoded.topCount, 10);
    expect(decoded.wingViewBlock, 'A');
    expect(decoded.enabledPages.length, 2);
  });

  test('PreferencesStorage persists top consumers config', () async {
    final prefs = await PreferencesStorage.create();
    const config = TopConsumersDashboardConfig(
      showOverall: false,
      showByBlock: true,
      showByWing: false,
      topCount: 3,
    );
    await prefs.setTopConsumersConfig(config);
    expect(prefs.topConsumersConfig.showByBlock, isTrue);
    expect(prefs.topConsumersConfig.topCount, 3);
  });

  test('WaterUnit phoneNumber JSON round-trip', () async {
    final prefs = await PreferencesStorage.create();
    final unit = WaterUnit(
      id: 'wm-1',
      name: 'Unit 1',
      deviceId: 'WM1',
      block: 'A',
      wing: 'East',
      phoneNumber: '+919876543210',
    );
    await prefs.addWaterUnit(unit);
    final loaded = prefs.getWaterUnits().first;
    expect(loaded.phoneNumber, '+919876543210');
    final json = jsonDecode(jsonEncode(unit.toJson())) as Map<String, dynamic>;
    expect(WaterUnit.fromJson(json).phoneNumber, '+919876543210');
  });
}
