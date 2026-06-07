enum AuditAction {
  valveOff,
  valveOn,
  quotaUpdate,
  templateApply,
  emergencyShutoff,
  unitEdit,
  maintenanceMode,
  scheduleUpdate;

  String get label {
    switch (this) {
      case AuditAction.valveOff:
        return 'Valve turned off';
      case AuditAction.valveOn:
        return 'Valve turned on';
      case AuditAction.quotaUpdate:
        return 'Quota updated';
      case AuditAction.templateApply:
        return 'Template applied';
      case AuditAction.emergencyShutoff:
        return 'Emergency shutoff';
      case AuditAction.unitEdit:
        return 'Unit edited';
      case AuditAction.maintenanceMode:
        return 'Maintenance mode';
      case AuditAction.scheduleUpdate:
        return 'Schedule updated';
    }
  }

  static AuditAction fromStorage(String value) {
    return AuditAction.values.firstWhere(
      (a) => a.name == value,
      orElse: () => AuditAction.unitEdit,
    );
  }
}

class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.timestamp,
    required this.actorEmail,
    required this.action,
    required this.unitId,
    this.unitName,
    this.details,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> json) {
    return AuditEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      actorEmail: json['actorEmail'] as String,
      action: AuditAction.fromStorage(json['action'] as String),
      unitId: json['unitId'] as String,
      unitName: json['unitName'] as String?,
      details: json['details'] as String?,
    );
  }

  final String id;
  final DateTime timestamp;
  final String actorEmail;
  final AuditAction action;
  final String unitId;
  final String? unitName;
  final String? details;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'actorEmail': actorEmail,
        'action': action.name,
        'unitId': unitId,
        if (unitName != null) 'unitName': unitName,
        if (details != null) 'details': details,
      };
}
