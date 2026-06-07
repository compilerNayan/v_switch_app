enum ValveControlMode {
  manual,
  quota;

  static ValveControlMode fromJson(String value) {
    switch (value) {
      case 'quota':
        return ValveControlMode.quota;
      case 'manual':
      default:
        return ValveControlMode.manual;
    }
  }

  String toJson() {
    switch (this) {
      case ValveControlMode.manual:
        return 'manual';
      case ValveControlMode.quota:
        return 'quota';
    }
  }
}

class ValveState {
  const ValveState({
    required this.deviceId,
    required this.timestamp,
    required this.targetPressurePercent,
    required this.actualPressurePercent,
    required this.lastUserPressurePercent,
    required this.isOff,
    required this.controlMode,
    this.quotaCapPercent,
    required this.effectivePressurePercent,
  });

  factory ValveState.fromJson(Map<String, dynamic> json) {
    return ValveState(
      deviceId: json['deviceId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      targetPressurePercent: (json['targetPressurePercent'] as num).toDouble(),
      actualPressurePercent: (json['actualPressurePercent'] as num).toDouble(),
      lastUserPressurePercent:
          (json['lastUserPressurePercent'] as num).toDouble(),
      isOff: json['isOff'] as bool,
      controlMode: ValveControlMode.fromJson(json['controlMode'] as String),
      quotaCapPercent: json['quotaCapPercent'] == null
          ? null
          : (json['quotaCapPercent'] as num).toDouble(),
      effectivePressurePercent:
          (json['effectivePressurePercent'] as num).toDouble(),
    );
  }

  final String deviceId;
  final DateTime timestamp;
  final double targetPressurePercent;
  final double actualPressurePercent;
  final double lastUserPressurePercent;
  final bool isOff;
  final ValveControlMode controlMode;
  final double? quotaCapPercent;
  final double effectivePressurePercent;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'targetPressurePercent': targetPressurePercent,
        'actualPressurePercent': actualPressurePercent,
        'lastUserPressurePercent': lastUserPressurePercent,
        'isOff': isOff,
        'controlMode': controlMode.toJson(),
        'quotaCapPercent': quotaCapPercent,
        'effectivePressurePercent': effectivePressurePercent,
      };
}

class ValveUpdateRequest {
  const ValveUpdateRequest({
    this.pressurePercent,
    this.action,
  });

  final double? pressurePercent;
  final String? action;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (pressurePercent != null) {
      map['pressurePercent'] = pressurePercent;
    }
    if (action != null) {
      map['action'] = action;
    }
    return map;
  }
}
