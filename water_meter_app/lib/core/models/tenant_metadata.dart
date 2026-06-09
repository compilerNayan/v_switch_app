import 'tenant_config.dart';
import 'water_unit.dart';

class TenantMetadataOwner {
  const TenantMetadataOwner({
    required this.userId,
    this.displayName,
    this.email,
    this.phone,
    this.firstName,
    this.lastName,
  });

  factory TenantMetadataOwner.fromJson(Map<String, dynamic> json) {
    return TenantMetadataOwner(
      userId: json['userId'] as String,
      displayName: json['displayName'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
    );
  }

  final String userId;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? firstName;
  final String? lastName;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        if (displayName != null) 'displayName': displayName,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (firstName != null) 'firstName': firstName,
        if (lastName != null) 'lastName': lastName,
      };
}

class TenantMetadataDevice {
  const TenantMetadataDevice({
    required this.unitId,
    required this.name,
    required this.deviceId,
    this.flatNumber,
    this.floor,
    this.block,
    this.wing,
    this.residentName,
    this.phoneNumber,
    this.notes,
    required this.enrollmentStatus,
    this.maintenanceMode = false,
    this.maintenanceStartedAt,
    this.unitInviteCode,
  });

  factory TenantMetadataDevice.fromJson(Map<String, dynamic> json) {
    return TenantMetadataDevice(
      unitId: json['unitId'] as String,
      name: json['name'] as String,
      deviceId: json['deviceId'] as String,
      flatNumber: json['flatNumber'] as String?,
      floor: json['floor'] as String?,
      block: json['block'] as String?,
      wing: json['wing'] as String?,
      residentName: json['residentName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      notes: json['notes'] as String?,
      enrollmentStatus: json['enrollmentStatus'] as String? ?? 'enrolled',
      maintenanceMode: json['maintenanceMode'] as bool? ?? false,
      maintenanceStartedAt: json['maintenanceStartedAt'] as String?,
      unitInviteCode: json['unitInviteCode'] as String?,
    );
  }

  final String unitId;
  final String name;
  final String deviceId;
  final String? flatNumber;
  final String? floor;
  final String? block;
  final String? wing;
  final String? residentName;
  final String? phoneNumber;
  final String? notes;
  final String enrollmentStatus;
  final bool maintenanceMode;
  final String? maintenanceStartedAt;
  final String? unitInviteCode;

  WaterUnit toWaterUnit() {
    return WaterUnit(
      id: unitId,
      name: name,
      deviceId: deviceId,
      flatNumber: flatNumber ?? '',
      floor: floor ?? '',
      block: block ?? '',
      wing: wing ?? '',
      residentName: residentName,
      phoneNumber: phoneNumber,
      notes: notes,
      maintenanceMode: maintenanceMode,
      unitInviteCode: unitInviteCode,
      enrollmentStatus: UnitEnrollmentStatus.fromJson(enrollmentStatus),
    );
  }

  Map<String, dynamic> toJson() => {
        'unitId': unitId,
        'name': name,
        'deviceId': deviceId,
        if (flatNumber != null) 'flatNumber': flatNumber,
        if (floor != null) 'floor': floor,
        if (block != null) 'block': block,
        if (wing != null) 'wing': wing,
        if (residentName != null) 'residentName': residentName,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (notes != null) 'notes': notes,
        'enrollmentStatus': enrollmentStatus,
        'maintenanceMode': maintenanceMode,
        if (maintenanceStartedAt != null)
          'maintenanceStartedAt': maintenanceStartedAt,
        if (unitInviteCode != null) 'unitInviteCode': unitInviteCode,
      };
}

class TenantMetadataResponse {
  const TenantMetadataResponse({
    required this.metadataHash,
    required this.tenantId,
    required this.buildingName,
    required this.structure,
    this.owner,
    required this.devices,
  });

  factory TenantMetadataResponse.fromJson(Map<String, dynamic> json) {
    final structureJson = json['structure'] as Map<String, dynamic>? ?? {};
    final devicesJson = json['devices'] as List<dynamic>? ?? [];
    return TenantMetadataResponse(
      metadataHash: json['metadataHash'] as String,
      tenantId: json['tenantId'] as String,
      buildingName: json['buildingName'] as String? ?? '',
      structure: TenantStructure.fromJson(structureJson),
      owner: json['owner'] == null
          ? null
          : TenantMetadataOwner.fromJson(
              json['owner'] as Map<String, dynamic>,
            ),
      devices: devicesJson
          .map((e) => TenantMetadataDevice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String metadataHash;
  final String tenantId;
  final String buildingName;
  final TenantStructure structure;
  final TenantMetadataOwner? owner;
  final List<TenantMetadataDevice> devices;

  TenantConfig toTenantConfig() {
    return TenantConfig(
      tenantId: tenantId,
      name: buildingName,
      structure: structure,
    );
  }

  Map<String, dynamic> toJson() => {
        'metadataHash': metadataHash,
        'tenantId': tenantId,
        'buildingName': buildingName,
        'structure': structure.toJson(),
        if (owner != null) 'owner': owner!.toJson(),
        'devices': devices.map((d) => d.toJson()).toList(),
      };
}
