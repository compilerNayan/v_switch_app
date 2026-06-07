import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_device.dart';
import '../utils/units.dart';

class PreferencesStorage {
  PreferencesStorage(this._prefs);

  static const _volumeUnitKey = 'volume_unit';
  static const _timezoneKey = 'timezone';
  static const _userDevicesKey = 'user_devices';
  static const _enrolledDeviceSerialKey = 'enrolled_device_serial';

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

  List<UserDevice> getUserDevices() {
    final raw = _prefs.getString(_userDevicesKey);
    if (raw == null || raw.isEmpty) {
      return _migrateLegacyDevice();
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => UserDevice.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return _migrateLegacyDevice();
    }
  }

  List<UserDevice> _migrateLegacyDevice() {
    final legacy = _prefs.getString(_enrolledDeviceSerialKey);
    if (legacy == null || legacy.isEmpty) return [];
    return [
      UserDevice(
        id: 'legacy-$legacy',
        typeId: 'water_meter',
        name: 'Water Meter $legacy',
        deviceId: legacy,
      ),
    ];
  }

  Future<void> saveUserDevices(List<UserDevice> devices) async {
    final encoded = jsonEncode(devices.map((d) => d.toJson()).toList());
    await _prefs.setString(_userDevicesKey, encoded);
  }

  Future<UserDevice> addUserDevice(UserDevice device) async {
    final devices = getUserDevices();
    final exists = devices.any((d) => d.deviceId == device.deviceId);
    if (exists) {
      return devices.firstWhere((d) => d.deviceId == device.deviceId);
    }
    final updated = [...devices, device];
    await saveUserDevices(updated);
    await _prefs.remove(_enrolledDeviceSerialKey);
    return device;
  }
}
