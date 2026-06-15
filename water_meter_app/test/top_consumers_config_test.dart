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

  test('TopConsumersDashboardConfig defaults to top 3', () {
    const config = TopConsumersDashboardConfig();
    expect(config.topCount, 3);
    expect(TopConsumersDashboardConfig.fromJson({}).topCount, 3);
  });

  test('TopConsumersDashboardConfig JSON round-trip', () {
    const config = TopConsumersDashboardConfig(topCount: 10);
    final decoded = TopConsumersDashboardConfig.fromJson(config.toJson());
    expect(decoded.topCount, 10);
  });

  test('TopConsumersDashboardConfig ignores legacy JSON fields', () {
    final decoded = TopConsumersDashboardConfig.fromJson({
      'showOverall': true,
      'showByBlock': false,
      'showByWing': true,
      'topCount': 3,
      'wingViewBlock': 'A',
    });
    expect(decoded.topCount, 3);
  });

  test('PreferencesStorage persists top consumers config', () async {
    final prefs = await PreferencesStorage.create();
    const config = TopConsumersDashboardConfig(topCount: 3);
    await prefs.setTopConsumersConfig(config);
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
