import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_event.dart';
import '../models/audit_event.dart';
import '../models/quota_template.dart';
import '../models/schedule_rule.dart';
import '../models/tariff_config.dart';
import '../models/bulk_valve_snapshot.dart';
import '../models/tenant_config.dart';
import '../models/tenant_metadata.dart';
import '../models/top_consumers_config.dart';
import '../models/water_unit.dart';
import '../theme/app_theme.dart';
import '../utils/units.dart';

class PreferencesStorage {
  PreferencesStorage(this._prefs);

  static const _volumeUnitKey = 'volume_unit';
  static const _timezoneKey = 'timezone';
  static const _appThemeKey = 'app_theme';
  static const _waterUnitsKey = 'water_units';
  static const _userDevicesKey = 'user_devices';
  static const _enrolledDeviceSerialKey = 'enrolled_device_serial';
  static const _tariffKey = 'tariff_config';
  static const _alertPrefsKey = 'alert_preferences';
  static const _alertsKey = 'alert_events';
  static const _auditKey = 'audit_events';
  static const _quotaTemplatesKey = 'quota_templates';
  static const _scheduleRulesKey = 'schedule_rules';
  static const _tenantAdminsKey = 'tenant_admins';
  static const _topConsumersConfigKey = 'top_consumers_config';
  static const _tenantConfigKey = 'tenant_config';
  static const _tenantMetadataV2Prefix = 'tenant_metadata_v2_';
  static const _adminInviteCodeKey = 'admin_invite_code';
  static const _bulkValveSnapshotKey = 'bulk_valve_snapshot';

  static const maxAuditEntries = 500;
  static const maxAlertEntries = 200;

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

  AppThemeId get appThemeId =>
      AppThemeId.fromStorage(_prefs.getString(_appThemeKey));

  Future<void> setAppThemeId(AppThemeId id) =>
      _prefs.setString(_appThemeKey, id.toStorage());

  TariffConfig get tariffConfig {
    final raw = _prefs.getString(_tariffKey);
    if (raw == null) return const TariffConfig();
    try {
      return TariffConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const TariffConfig();
    }
  }

  Future<void> setTariffConfig(TariffConfig config) =>
      _prefs.setString(_tariffKey, jsonEncode(config.toJson()));

  AlertPreferences get alertPreferences {
    final raw = _prefs.getString(_alertPrefsKey);
    if (raw == null) return const AlertPreferences();
    try {
      return AlertPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AlertPreferences();
    }
  }

  Future<void> setAlertPreferences(AlertPreferences prefs) =>
      _prefs.setString(_alertPrefsKey, jsonEncode(prefs.toJson()));

  TopConsumersDashboardConfig get topConsumersConfig {
    final raw = _prefs.getString(_topConsumersConfigKey);
    if (raw == null) return const TopConsumersDashboardConfig();
    try {
      return TopConsumersDashboardConfig.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const TopConsumersDashboardConfig();
    }
  }

  Future<void> setTopConsumersConfig(TopConsumersDashboardConfig config) =>
      _prefs.setString(_topConsumersConfigKey, jsonEncode(config.toJson()));

  List<WaterUnit> getWaterUnits() {
    final raw = _prefs.getString(_waterUnitsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) => WaterUnit.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return _migrateFromLegacyDevices();
  }

  List<WaterUnit> _migrateFromLegacyDevices() {
    final raw = _prefs.getString(_userDevicesKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((e) {
          final map = e as Map<String, dynamic>;
          if (map.containsKey('typeId')) {
            return WaterUnit.fromLegacyJson(map);
          }
          return WaterUnit.fromJson(map);
        }).toList();
      } catch (_) {}
    }
    final legacy = _prefs.getString(_enrolledDeviceSerialKey);
    if (legacy == null || legacy.isEmpty) return [];
    return [
      WaterUnit(
        id: 'wm-$legacy',
        name: 'Water Meter $legacy',
        deviceId: legacy,
      ),
    ];
  }

  Future<void> saveWaterUnits(List<WaterUnit> units) async {
    final encoded = jsonEncode(units.map((u) => u.toJson()).toList());
    await _prefs.setString(_waterUnitsKey, encoded);
    await _prefs.remove(_userDevicesKey);
  }

  Future<WaterUnit> addWaterUnit(WaterUnit unit) async {
    final units = getWaterUnits();
    final exists = units.any((u) => u.deviceId == unit.deviceId);
    if (exists) {
      return units.firstWhere((u) => u.deviceId == unit.deviceId);
    }
    final inviteCode = unit.unitInviteCode ?? _generateUnitInviteCode(unit);
    final withCode = unit.copyWith(unitInviteCode: inviteCode);
    await saveWaterUnits([...units, withCode]);
    await _prefs.remove(_enrolledDeviceSerialKey);
    return withCode;
  }

  Future<WaterUnit> updateWaterUnit(WaterUnit unit) async {
    final units = getWaterUnits();
    final updated = units
        .map((u) => u.id == unit.id ? unit : u)
        .toList();
    await saveWaterUnits(updated);
    return unit;
  }

  String _generateUnitInviteCode(WaterUnit unit) {
    final base = unit.flatNumber.isNotEmpty
        ? unit.flatNumber.replaceAll(' ', '')
        : unit.name.replaceAll(' ', '').toUpperCase();
    final suffix = unit.deviceId.length >= 4
        ? unit.deviceId.substring(unit.deviceId.length - 4)
        : unit.deviceId;
    return '$base-$suffix';
  }

  WaterUnit? findUnitByInviteCode(String code) {
    final normalized = code.trim().toUpperCase();
    for (final unit in getWaterUnits()) {
      if (unit.unitInviteCode?.toUpperCase() == normalized) return unit;
    }
    return null;
  }

  List<AlertEvent> getAlerts() {
    final raw = _prefs.getString(_alertsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AlertEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAlerts(List<AlertEvent> alerts) async {
    final trimmed = alerts.length > maxAlertEntries
        ? alerts.sublist(alerts.length - maxAlertEntries)
        : alerts;
    await _prefs.setString(
      _alertsKey,
      jsonEncode(trimmed.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> addAlert(AlertEvent alert) async {
    final alerts = getAlerts();
    final exists = alerts.any((a) =>
        a.unitId == alert.unitId &&
        a.type == alert.type &&
        !a.isResolved &&
        a.timestamp.difference(alert.timestamp).inHours.abs() < 6);
    if (exists) return;
    await saveAlerts([...alerts, alert]);
  }

  Future<void> markAlertRead(String alertId) async {
    final alerts = getAlerts();
    await saveAlerts(alerts
        .map((a) => a.id == alertId ? a.copyWith(isRead: true) : a)
        .toList());
  }

  List<AuditEvent> getAuditEvents() {
    final raw = _prefs.getString(_auditKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AuditEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendAuditEvent(AuditEvent event) async {
    final events = [...getAuditEvents(), event];
    final trimmed = events.length > maxAuditEntries
        ? events.sublist(events.length - maxAuditEntries)
        : events;
    await _prefs.setString(
      _auditKey,
      jsonEncode(trimmed.map((e) => e.toJson()).toList()),
    );
  }

  List<QuotaTemplate> getQuotaTemplates() {
    final raw = _prefs.getString(_quotaTemplatesKey);
    if (raw == null) return QuotaTemplate.defaults;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => QuotaTemplate.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return QuotaTemplate.defaults;
    }
  }

  Future<void> saveQuotaTemplates(List<QuotaTemplate> templates) async {
    await _prefs.setString(
      _quotaTemplatesKey,
      jsonEncode(templates.map((t) => t.toJson()).toList()),
    );
  }

  List<ScheduleRule> getScheduleRules() {
    final raw = _prefs.getString(_scheduleRulesKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ScheduleRule.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveScheduleRules(List<ScheduleRule> rules) async {
    await _prefs.setString(
      _scheduleRulesKey,
      jsonEncode(rules.map((r) => r.toJson()).toList()),
    );
  }

  List<String> getTenantAdmins() {
    final raw = _prefs.getStringList(_tenantAdminsKey);
    return raw ?? [];
  }

  Future<void> setTenantAdmins(List<String> emails) =>
      _prefs.setStringList(_tenantAdminsKey, emails);

  TenantConfig? getTenantConfig() {
    final raw = _prefs.getString(_tenantConfigKey);
    if (raw == null) return null;
    try {
      return TenantConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool get tenantExists => getTenantConfig() != null;

  Future<void> setTenantConfig(TenantConfig config) =>
      _prefs.setString(_tenantConfigKey, jsonEncode(config.toJson()));

  TenantMetadataResponse? getTenantMetadataV2(String tenantId) {
    final raw = _prefs.getString('$_tenantMetadataV2Prefix$tenantId');
    if (raw == null) return null;
    try {
      return TenantMetadataResponse.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> setTenantMetadataV2(
    String tenantId,
    TenantMetadataResponse metadata,
  ) async {
    await _prefs.setString(
      '$_tenantMetadataV2Prefix$tenantId',
      jsonEncode(metadata.toJson()),
    );
    await setTenantConfig(metadata.toTenantConfig());
  }

  String? getAdminInviteCode() => _prefs.getString(_adminInviteCodeKey);

  Future<void> setAdminInviteCode(String code) =>
      _prefs.setString(_adminInviteCodeKey, code);

  BulkValveSnapshot? getBulkValveSnapshot() {
    final raw = _prefs.getString(_bulkValveSnapshotKey);
    if (raw == null) return null;
    try {
      return BulkValveSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> setBulkValveSnapshot(BulkValveSnapshot? snapshot) async {
    if (snapshot == null) {
      await _prefs.remove(_bulkValveSnapshotKey);
      return;
    }
    await _prefs.setString(
      _bulkValveSnapshotKey,
      jsonEncode(snapshot.toJson()),
    );
  }

  // Legacy aliases for gradual migration
  List<WaterUnit> getUserDevices() => getWaterUnits();
  Future<void> saveUserDevices(List<WaterUnit> devices) => saveWaterUnits(devices);
  Future<WaterUnit> addUserDevice(WaterUnit device) => addWaterUnit(device);
}
