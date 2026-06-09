enum UnitEnrollmentStatus {
  pending,
  enrolled,
  failed;

  static UnitEnrollmentStatus fromJson(String? value) {
    switch (value) {
      case 'pending':
        return UnitEnrollmentStatus.pending;
      case 'failed':
        return UnitEnrollmentStatus.failed;
      case 'enrolled':
      default:
        return UnitEnrollmentStatus.enrolled;
    }
  }

  String toJson() => name;
}

class WaterUnit {
  const WaterUnit({
    required this.id,
    required this.name,
    required this.deviceId,
    this.flatNumber = '',
    this.floor = '',
    this.wing = '',
    this.block = '',
    this.residentName,
    this.phoneNumber,
    this.notes,
    this.maintenanceMode = false,
    this.assignedUserIds = const [],
    this.unitInviteCode,
    this.enrollmentStatus = UnitEnrollmentStatus.enrolled,
  });

  factory WaterUnit.fromJson(Map<String, dynamic> json) {
    return WaterUnit(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceId: json['deviceId'] as String,
      flatNumber: json['flatNumber'] as String? ?? '',
      floor: json['floor'] as String? ?? '',
      wing: json['wing'] as String? ?? '',
      block: json['block'] as String? ?? '',
      residentName: json['residentName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      notes: json['notes'] as String?,
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      assignedUserIds: (json['assignedUserIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      unitInviteCode: json['unitInviteCode'] as String?,
      enrollmentStatus: UnitEnrollmentStatus.fromJson(
        json['enrollmentStatus'] as String?,
      ),
    );
  }

  /// Migrates legacy UserDevice JSON (with typeId).
  factory WaterUnit.fromLegacyJson(Map<String, dynamic> json) {
    return WaterUnit(
      id: json['id'] as String,
      name: json['name'] as String,
      deviceId: json['deviceId'] as String,
    );
  }

  final String id;
  final String name;
  final String deviceId;
  final String flatNumber;
  final String floor;
  final String wing;
  final String block;
  final String? residentName;
  final String? phoneNumber;
  final String? notes;
  final bool maintenanceMode;
  final List<String> assignedUserIds;
  final String? unitInviteCode;
  final UnitEnrollmentStatus enrollmentStatus;

  bool get isEnrollmentPending => enrollmentStatus == UnitEnrollmentStatus.pending;
  bool get isActive => enrollmentStatus == UnitEnrollmentStatus.enrolled;

  String get displaySubtitle {
    final parts = <String>[
      if (flatNumber.isNotEmpty) 'Flat $flatNumber',
      if (floor.isNotEmpty) 'Floor $floor',
      if (wing.isNotEmpty) wing,
    ];
    if (parts.isEmpty) return deviceId;
    return '${parts.join(' · ')} · $deviceId';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'deviceId': deviceId,
        'flatNumber': flatNumber,
        'floor': floor,
        'wing': wing,
        'block': block,
        if (residentName != null) 'residentName': residentName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (notes != null) 'notes': notes,
        'maintenanceMode': maintenanceMode,
        'assignedUserIds': assignedUserIds,
        if (unitInviteCode != null) 'unitInviteCode': unitInviteCode,
        'enrollmentStatus': enrollmentStatus.toJson(),
      };

  WaterUnit copyWith({
    String? id,
    String? name,
    String? deviceId,
    String? flatNumber,
    String? floor,
    String? wing,
    String? block,
    String? residentName,
    String? phoneNumber,
    String? notes,
    bool? maintenanceMode,
    List<String>? assignedUserIds,
    String? unitInviteCode,
    UnitEnrollmentStatus? enrollmentStatus,
    bool clearResidentName = false,
    bool clearPhoneNumber = false,
    bool clearNotes = false,
  }) {
    return WaterUnit(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      flatNumber: flatNumber ?? this.flatNumber,
      floor: floor ?? this.floor,
      wing: wing ?? this.wing,
      block: block ?? this.block,
      residentName:
          clearResidentName ? null : (residentName ?? this.residentName),
      phoneNumber:
          clearPhoneNumber ? null : (phoneNumber ?? this.phoneNumber),
      notes: clearNotes ? null : (notes ?? this.notes),
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      assignedUserIds: assignedUserIds ?? this.assignedUserIds,
      unitInviteCode: unitInviteCode ?? this.unitInviteCode,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
    );
  }
}
