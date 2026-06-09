import 'tenant_metadata.dart';

class DashboardTelemetryDevice {
  const DashboardTelemetryDevice({
    required this.unitId,
    required this.deviceId,
    required this.todayLiters,
    required this.monthLiters,
    required this.isOnline,
    this.lastSeenAt,
    required this.status,
    required this.flowRateLpm,
    required this.quotaEnabled,
    required this.dailyLimitLiters,
    required this.quotaUsedLiters,
    this.quotaPercent,
    required this.valveOpenPercent,
    required this.valveIsOff,
    required this.hasAlert,
  });

  factory DashboardTelemetryDevice.fromJson(Map<String, dynamic> json) {
    return DashboardTelemetryDevice(
      unitId: json['unitId'] as String,
      deviceId: json['deviceId'] as String,
      todayLiters: (json['todayLiters'] as num).toDouble(),
      monthLiters: (json['monthLiters'] as num).toDouble(),
      isOnline: json['isOnline'] as bool? ?? false,
      lastSeenAt: json['lastSeenAt'] as String?,
      status: json['status'] as String? ?? 'offline',
      flowRateLpm: (json['flowRateLpm'] as num?)?.toDouble() ?? 0,
      quotaEnabled: json['quotaEnabled'] as bool? ?? false,
      dailyLimitLiters: (json['dailyLimitLiters'] as num?)?.toDouble() ?? 0,
      quotaUsedLiters: (json['quotaUsedLiters'] as num?)?.toDouble() ?? 0,
      quotaPercent: json['quotaPercent'] == null
          ? null
          : (json['quotaPercent'] as num).toDouble(),
      valveOpenPercent: (json['valveOpenPercent'] as num?)?.toDouble() ?? 0,
      valveIsOff: json['valveIsOff'] as bool? ?? false,
      hasAlert: json['hasAlert'] as bool? ?? false,
    );
  }

  final String unitId;
  final String deviceId;
  final double todayLiters;
  final double monthLiters;
  final bool isOnline;
  final String? lastSeenAt;
  final String status;
  final double flowRateLpm;
  final bool quotaEnabled;
  final double dailyLimitLiters;
  final double quotaUsedLiters;
  final double? quotaPercent;
  final double valveOpenPercent;
  final bool valveIsOff;
  final bool hasAlert;

  bool get isFlowing => flowRateLpm > 0.2 || status == 'flowing';

  Map<String, dynamic> toJson() => {
        'unitId': unitId,
        'deviceId': deviceId,
        'todayLiters': todayLiters,
        'monthLiters': monthLiters,
        'isOnline': isOnline,
        if (lastSeenAt != null) 'lastSeenAt': lastSeenAt,
        'status': status,
        'flowRateLpm': flowRateLpm,
        'quotaEnabled': quotaEnabled,
        'dailyLimitLiters': dailyLimitLiters,
        'quotaUsedLiters': quotaUsedLiters,
        if (quotaPercent != null) 'quotaPercent': quotaPercent,
        'valveOpenPercent': valveOpenPercent,
        'valveIsOff': valveIsOff,
        'hasAlert': hasAlert,
      };
}

class HomeDashboardResponse {
  const HomeDashboardResponse({
    required this.metadataHash,
    required this.generatedAt,
    required this.devices,
  });

  factory HomeDashboardResponse.fromJson(Map<String, dynamic> json) {
    final devicesJson = json['devices'] as List<dynamic>? ?? [];
    return HomeDashboardResponse(
      metadataHash: json['metadataHash'] as String,
      generatedAt: json['generatedAt'] as String? ?? '',
      devices: devicesJson
          .map(
            (e) => DashboardTelemetryDevice.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final String metadataHash;
  final String generatedAt;
  final List<DashboardTelemetryDevice> devices;

  Map<String, DashboardTelemetryDevice> get byDeviceId => {
        for (final device in devices) device.deviceId: device,
      };

  Map<String, dynamic> toJson() => {
        'metadataHash': metadataHash,
        'generatedAt': generatedAt,
        'devices': devices.map((d) => d.toJson()).toList(),
      };
}

class HomeSnapshot {
  const HomeSnapshot({
    required this.metadata,
    required this.dashboard,
  });

  final TenantMetadataResponse metadata;
  final HomeDashboardResponse dashboard;

  Map<String, DashboardTelemetryDevice> get telemetryByDeviceId =>
      dashboard.byDeviceId;
}
