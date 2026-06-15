class TenantDeletionResponse {
  const TenantDeletionResponse({
    required this.tenantId,
    required this.unitsDeleted,
    required this.deviceDataSetsDeleted,
    required this.preEnrollmentsDeleted,
    required this.dummyDevicesDeleted,
    required this.usersDeleted,
    required this.cognitoUsersDeleted,
    required this.tenantDeleted,
  });

  factory TenantDeletionResponse.fromJson(Map<String, dynamic> json) {
    return TenantDeletionResponse(
      tenantId: json['tenantId'] as String? ?? '',
      unitsDeleted: json['unitsDeleted'] as int? ?? 0,
      deviceDataSetsDeleted: json['deviceDataSetsDeleted'] as int? ?? 0,
      preEnrollmentsDeleted: json['preEnrollmentsDeleted'] as int? ?? 0,
      dummyDevicesDeleted: json['dummyDevicesDeleted'] as int? ?? 0,
      usersDeleted: json['usersDeleted'] as int? ?? 0,
      cognitoUsersDeleted: json['cognitoUsersDeleted'] as int? ?? 0,
      tenantDeleted: json['tenantDeleted'] as bool? ?? false,
    );
  }

  final String tenantId;
  final int unitsDeleted;
  final int deviceDataSetsDeleted;
  final int preEnrollmentsDeleted;
  final int dummyDevicesDeleted;
  final int usersDeleted;
  final int cognitoUsersDeleted;
  final bool tenantDeleted;
}
