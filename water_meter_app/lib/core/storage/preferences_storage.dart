import 'package:shared_preferences/shared_preferences.dart';

import '../utils/units.dart';

class PreferencesStorage {
  PreferencesStorage(this._prefs);

  static const _volumeUnitKey = 'volume_unit';
  static const _timezoneKey = 'timezone';
  static const _deviceOnboardingKey = 'device_onboarding_complete';

  final SharedPreferences _prefs;

  static Future<PreferencesStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesStorage(prefs);
  }

  VolumeUnit get volumeUnit =>
      VolumeUnit.fromStorage(_prefs.getString(_volumeUnitKey));

  Future<void> setVolumeUnit(VolumeUnit unit) =>
      _prefs.setString(_volumeUnitKey, unit.toStorage());

  String get timezone =>
      _prefs.getString(_timezoneKey) ?? DateTime.now().timeZoneName;

  Future<void> setTimezone(String timezone) =>
      _prefs.setString(_timezoneKey, timezone);

  bool get deviceOnboardingComplete =>
      _prefs.getBool(_deviceOnboardingKey) ?? false;

  Future<void> setDeviceOnboardingComplete(bool value) =>
      _prefs.setBool(_deviceOnboardingKey, value);
}
