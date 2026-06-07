enum WaterDeviceStatus {
  flowing,
  idle,
  offline,
  leakSuspected;

  static WaterDeviceStatus fromJson(String value) {
    switch (value) {
      case 'flowing':
        return WaterDeviceStatus.flowing;
      case 'idle':
        return WaterDeviceStatus.idle;
      case 'offline':
        return WaterDeviceStatus.offline;
      case 'leak_suspected':
        return WaterDeviceStatus.leakSuspected;
      default:
        return WaterDeviceStatus.offline;
    }
  }

  String toJson() {
    switch (this) {
      case WaterDeviceStatus.flowing:
        return 'flowing';
      case WaterDeviceStatus.idle:
        return 'idle';
      case WaterDeviceStatus.offline:
        return 'offline';
      case WaterDeviceStatus.leakSuspected:
        return 'leak_suspected';
    }
  }

  String get label {
    switch (this) {
      case WaterDeviceStatus.flowing:
        return 'Flowing';
      case WaterDeviceStatus.idle:
        return 'Idle';
      case WaterDeviceStatus.offline:
        return 'Offline';
      case WaterDeviceStatus.leakSuspected:
        return 'Leak suspected';
    }
  }
}

class CurrentReading {
  const CurrentReading({
    required this.deviceId,
    required this.timestamp,
    required this.flowRateLpm,
    required this.cumulativeLiters,
    required this.status,
  });

  factory CurrentReading.fromJson(Map<String, dynamic> json) {
    return CurrentReading(
      deviceId: json['deviceId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      flowRateLpm: (json['flowRateLpm'] as num).toDouble(),
      cumulativeLiters: (json['cumulativeLiters'] as num).toDouble(),
      status: WaterDeviceStatus.fromJson(json['status'] as String),
    );
  }

  final String deviceId;
  final DateTime timestamp;
  final double flowRateLpm;
  final double cumulativeLiters;
  final WaterDeviceStatus status;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'flowRateLpm': flowRateLpm,
        'cumulativeLiters': cumulativeLiters,
        'status': status.toJson(),
      };
}
