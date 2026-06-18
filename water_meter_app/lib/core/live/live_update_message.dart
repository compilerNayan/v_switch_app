sealed class LiveUpdateMessage {
  const LiveUpdateMessage();

  factory LiveUpdateMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    switch (type) {
      case 'subscribed':
        return LiveUpdateSubscribed(
          tenantId: json['tenantId'] as String? ?? '',
        );
      case 'water_flow':
        return LiveUpdateWaterFlow(
          tenantId: json['tenantId'] as String? ?? '',
          deviceId: json['deviceId'] as String? ?? '',
          unitId: json['unitId'] as String? ?? '',
          ts: json['ts'] as String? ?? '',
          ml: (json['ml'] as num?)?.toDouble() ?? 0,
          flowRateLpm: (json['flowRateLpm'] as num?)?.toDouble() ?? 0,
          cumulativeLiters: (json['cumulativeLiters'] as num?)?.toDouble(),
          todayLiters: (json['todayLiters'] as num?)?.toDouble(),
          monthLiters: (json['monthLiters'] as num?)?.toDouble(),
          status: json['status'] as String? ?? 'flowing',
        );
      case 'water_flow_tick':
        final rawDevices = json['devices'];
        final devices = <WaterFlowTickDevice>[];
        if (rawDevices is List) {
          for (final item in rawDevices) {
            if (item is Map<String, dynamic>) {
              devices.add(WaterFlowTickDevice.fromJson(item));
            } else if (item is Map) {
              devices.add(
                WaterFlowTickDevice.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
        return LiveUpdateWaterFlowTick(
          tenantId: json['tenantId'] as String? ?? '',
          ts: json['ts'] as String? ?? '',
          devices: devices,
        );
      case 'bucket_30m':
        return LiveUpdateBucket30m(
          tenantId: json['tenantId'] as String? ?? '',
          deviceId: json['deviceId'] as String? ?? '',
          unitId: json['unitId'] as String? ?? '',
          periodStart: json['periodStart'] as String? ?? '',
          action: json['action'] as String? ?? 'refresh',
        );
      case 'device_presence':
        return LiveUpdateDevicePresence(
          tenantId: json['tenantId'] as String? ?? '',
          deviceId: json['deviceId'] as String? ?? '',
          unitId: json['unitId'] as String? ?? '',
          ts: json['ts'] as String? ?? '',
          isOnline: (json['status'] as String? ?? 'offline') == 'online',
        );
      case 'device_log':
        return LiveUpdateDeviceLog(
          tenantId: json['tenantId'] as String? ?? '',
          deviceId: json['deviceId'] as String? ?? '',
          seq: (json['seq'] as num?)?.toInt() ?? 0,
          ts: json['ts'] as String? ?? '',
          message: json['message'] as String? ?? '',
          receivedAt: json['receivedAt'] as String?,
          serialNumber: json['serialNumber'] as String?,
        );
      case 'device_log_batch':
        final rawEntries = json['entries'];
        final entries = <DeviceLogEntryMessage>[];
        if (rawEntries is List) {
          for (final item in rawEntries) {
            if (item is Map<String, dynamic>) {
              entries.add(DeviceLogEntryMessage.fromJson(item));
            } else if (item is Map) {
              entries.add(
                DeviceLogEntryMessage.fromJson(Map<String, dynamic>.from(item)),
              );
            }
          }
        }
        return LiveUpdateDeviceLogBatch(
          tenantId: json['tenantId'] as String? ?? '',
          deviceId: json['deviceId'] as String? ?? '',
          fromSeq: (json['fromSeq'] as num?)?.toInt(),
          toSeq: (json['toSeq'] as num?)?.toInt(),
          entries: entries,
        );
      case 'device_log_reset':
        return LiveUpdateDeviceLogReset(
          tenantId: json['tenantId'] as String? ?? '',
          deviceId: json['deviceId'] as String? ?? '',
          nextSeq: (json['nextSeq'] as num?)?.toInt() ?? 1,
          reason: json['reason'] as String? ?? 'size_limit',
        );
      case 'error':
        return LiveUpdateError(
          code: json['code'] as String? ?? 'error',
          message: json['message'] as String? ?? 'Unknown error',
        );
      default:
        throw FormatException('Unknown live update type: $type');
    }
  }
}

class LiveUpdateSubscribed extends LiveUpdateMessage {
  const LiveUpdateSubscribed({required this.tenantId});

  final String tenantId;
}

class WaterFlowTickDevice {
  const WaterFlowTickDevice({
    required this.deviceId,
    required this.unitId,
    required this.ts,
    required this.ml,
    required this.flowRateLpm,
    this.cumulativeLiters,
    this.todayLiters,
    this.monthLiters,
    required this.status,
  });

  factory WaterFlowTickDevice.fromJson(Map<String, dynamic> json) {
    return WaterFlowTickDevice(
      deviceId: json['deviceId'] as String? ?? '',
      unitId: json['unitId'] as String? ?? '',
      ts: json['ts'] as String? ?? '',
      ml: (json['ml'] as num?)?.toDouble() ?? 0,
      flowRateLpm: (json['flowRateLpm'] as num?)?.toDouble() ?? 0,
      cumulativeLiters: (json['cumulativeLiters'] as num?)?.toDouble(),
      todayLiters: (json['todayLiters'] as num?)?.toDouble(),
      monthLiters: (json['monthLiters'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'flowing',
    );
  }

  final String deviceId;
  final String unitId;
  final String ts;
  final double ml;
  final double flowRateLpm;
  final double? cumulativeLiters;
  final double? todayLiters;
  final double? monthLiters;
  final String status;
}

class LiveUpdateWaterFlowTick extends LiveUpdateMessage {
  const LiveUpdateWaterFlowTick({
    required this.tenantId,
    required this.ts,
    required this.devices,
  });

  final String tenantId;
  final String ts;
  final List<WaterFlowTickDevice> devices;
}

class LiveUpdateWaterFlow extends LiveUpdateMessage {
  const LiveUpdateWaterFlow({
    required this.tenantId,
    required this.deviceId,
    required this.unitId,
    required this.ts,
    required this.ml,
    required this.flowRateLpm,
    this.cumulativeLiters,
    this.todayLiters,
    this.monthLiters,
    required this.status,
  });

  final String tenantId;
  final String deviceId;
  final String unitId;
  final String ts;
  final double ml;
  final double flowRateLpm;
  final double? cumulativeLiters;
  final double? todayLiters;
  final double? monthLiters;
  final String status;
}

class LiveUpdateBucket30m extends LiveUpdateMessage {
  const LiveUpdateBucket30m({
    required this.tenantId,
    required this.deviceId,
    required this.unitId,
    required this.periodStart,
    required this.action,
  });

  final String tenantId;
  final String deviceId;
  final String unitId;
  final String periodStart;
  final String action;
}

class LiveUpdateDevicePresence extends LiveUpdateMessage {
  const LiveUpdateDevicePresence({
    required this.tenantId,
    required this.deviceId,
    required this.unitId,
    required this.ts,
    required this.isOnline,
  });

  final String tenantId;
  final String deviceId;
  final String unitId;
  final String ts;
  final bool isOnline;
}

class LiveUpdateError extends LiveUpdateMessage {
  const LiveUpdateError({required this.code, required this.message});

  final String code;
  final String message;
}

class DeviceLogEntryMessage {
  const DeviceLogEntryMessage({
    required this.seq,
    required this.ts,
    required this.message,
    this.receivedAt,
    this.serialNumber,
  });

  factory DeviceLogEntryMessage.fromJson(Map<String, dynamic> json) {
    return DeviceLogEntryMessage(
      seq: (json['seq'] as num?)?.toInt() ?? 0,
      ts: json['ts'] as String? ?? '',
      message: json['message'] as String? ?? '',
      receivedAt: json['receivedAt'] as String?,
      serialNumber: json['serialNumber'] as String?,
    );
  }

  final int seq;
  final String ts;
  final String message;
  final String? receivedAt;
  final String? serialNumber;
}

class LiveUpdateDeviceLog extends LiveUpdateMessage {
  const LiveUpdateDeviceLog({
    required this.tenantId,
    required this.deviceId,
    required this.seq,
    required this.ts,
    required this.message,
    this.receivedAt,
    this.serialNumber,
  });

  final String tenantId;
  final String deviceId;
  final int seq;
  final String ts;
  final String message;
  final String? receivedAt;
  final String? serialNumber;
}

class LiveUpdateDeviceLogBatch extends LiveUpdateMessage {
  const LiveUpdateDeviceLogBatch({
    required this.tenantId,
    required this.deviceId,
    this.fromSeq,
    this.toSeq,
    required this.entries,
  });

  final String tenantId;
  final String deviceId;
  final int? fromSeq;
  final int? toSeq;
  final List<DeviceLogEntryMessage> entries;
}

class LiveUpdateDeviceLogReset extends LiveUpdateMessage {
  const LiveUpdateDeviceLogReset({
    required this.tenantId,
    required this.deviceId,
    required this.nextSeq,
    required this.reason,
  });

  final String tenantId;
  final String deviceId;
  final int nextSeq;
  final String reason;
}
