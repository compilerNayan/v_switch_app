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
          status: json['status'] as String? ?? 'flowing',
        );
      case 'bucket_30m':
        return LiveUpdateBucket30m(
          tenantId: json['tenantId'] as String? ?? '',
          deviceId: json['deviceId'] as String? ?? '',
          unitId: json['unitId'] as String? ?? '',
          periodStart: json['periodStart'] as String? ?? '',
          action: json['action'] as String? ?? 'refresh',
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

class LiveUpdateWaterFlow extends LiveUpdateMessage {
  const LiveUpdateWaterFlow({
    required this.tenantId,
    required this.deviceId,
    required this.unitId,
    required this.ts,
    required this.ml,
    required this.flowRateLpm,
    this.cumulativeLiters,
    required this.status,
  });

  final String tenantId;
  final String deviceId;
  final String unitId;
  final String ts;
  final double ml;
  final double flowRateLpm;
  final double? cumulativeLiters;
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

class LiveUpdateError extends LiveUpdateMessage {
  const LiveUpdateError({required this.code, required this.message});

  final String code;
  final String message;
}
