enum AlertType {
  quotaWarning,
  quotaExceeded,
  possibleLeak,
  unusualSpike,
  deviceOffline,
  valveMismatch;

  String get label {
    switch (this) {
      case AlertType.quotaWarning:
        return 'Quota warning';
      case AlertType.quotaExceeded:
        return 'Quota exceeded';
      case AlertType.possibleLeak:
        return 'Possible leak';
      case AlertType.unusualSpike:
        return 'Unusual spike';
      case AlertType.deviceOffline:
        return 'Device offline';
      case AlertType.valveMismatch:
        return 'Valve mismatch';
    }
  }

  bool get isCritical =>
      this == AlertType.possibleLeak ||
      this == AlertType.quotaExceeded ||
      this == AlertType.valveMismatch;

  static AlertType fromStorage(String value) {
    return AlertType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => AlertType.quotaWarning,
    );
  }
}

class AlertPreferences {
  const AlertPreferences({
    this.enabledTypes = const {
      AlertType.quotaWarning,
      AlertType.quotaExceeded,
      AlertType.possibleLeak,
      AlertType.unusualSpike,
      AlertType.deviceOffline,
      AlertType.valveMismatch,
    },
    this.quietHoursEnabled = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
    this.pushEnabled = true,
  });

  factory AlertPreferences.fromJson(Map<String, dynamic> json) {
    final types = (json['enabledTypes'] as List<dynamic>?)
            ?.map((e) => AlertType.fromStorage(e as String))
            .toSet() ??
        const {};
    return AlertPreferences(
      enabledTypes: types.isEmpty ? const {AlertType.quotaWarning} : types,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietStartHour: json['quietStartHour'] as int? ?? 22,
      quietEndHour: json['quietEndHour'] as int? ?? 7,
      pushEnabled: json['pushEnabled'] as bool? ?? true,
    );
  }

  final Set<AlertType> enabledTypes;
  final bool quietHoursEnabled;
  final int quietStartHour;
  final int quietEndHour;
  final bool pushEnabled;

  bool isTypeEnabled(AlertType type) => enabledTypes.contains(type);

  bool isQuietHour(DateTime now) {
    if (!quietHoursEnabled) return false;
    final hour = now.hour;
    if (quietStartHour < quietEndHour) {
      return hour >= quietStartHour && hour < quietEndHour;
    }
    return hour >= quietStartHour || hour < quietEndHour;
  }

  Map<String, dynamic> toJson() => {
        'enabledTypes': enabledTypes.map((t) => t.name).toList(),
        'quietHoursEnabled': quietHoursEnabled,
        'quietStartHour': quietStartHour,
        'quietEndHour': quietEndHour,
        'pushEnabled': pushEnabled,
      };

  AlertPreferences copyWith({
    Set<AlertType>? enabledTypes,
    bool? quietHoursEnabled,
    int? quietStartHour,
    int? quietEndHour,
    bool? pushEnabled,
  }) {
    return AlertPreferences(
      enabledTypes: enabledTypes ?? this.enabledTypes,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}

class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.unitId,
    required this.unitName,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.isResolved = false,
  });

  factory AlertEvent.fromJson(Map<String, dynamic> json) {
    return AlertEvent(
      id: json['id'] as String,
      unitId: json['unitId'] as String,
      unitName: json['unitName'] as String,
      type: AlertType.fromStorage(json['type'] as String),
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
      isResolved: json['isResolved'] as bool? ?? false,
    );
  }

  final String id;
  final String unitId;
  final String unitName;
  final AlertType type;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final bool isResolved;

  Map<String, dynamic> toJson() => {
        'id': id,
        'unitId': unitId,
        'unitName': unitName,
        'type': type.name,
        'message': message,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'isRead': isRead,
        'isResolved': isResolved,
      };

  AlertEvent copyWith({
    bool? isRead,
    bool? isResolved,
  }) {
    return AlertEvent(
      id: id,
      unitId: unitId,
      unitName: unitName,
      type: type,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      isResolved: isResolved ?? this.isResolved,
    );
  }
}
