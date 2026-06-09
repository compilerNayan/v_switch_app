enum WaterMeterSetupStep {
  devicePrep,
  connectHotspot,
  homeWifi,
  nameDevice,
  enrollment,
  success,
}

class ProvisioningState {
  const ProvisioningState({
    this.step = WaterMeterSetupStep.devicePrep,
    this.deviceSerial,
    this.deviceDisplayName,
    this.block,
    this.wing,
    this.floor,
    this.residentName,
    this.phoneNumber,
    this.notes,
    this.errorMessage,
    this.isLoading = false,
    this.wifiConfigured = false,
    this.tenantAssociated = false,
    this.metadataComplete = false,
    this.enrollStarted = false,
    this.enrollComplete = false,
  });

  final WaterMeterSetupStep step;
  final String? deviceSerial;
  final String? deviceDisplayName;
  final String? block;
  final String? wing;
  final String? floor;
  final String? residentName;
  final String? phoneNumber;
  final String? notes;
  final String? errorMessage;
  final bool isLoading;
  final bool wifiConfigured;
  final bool tenantAssociated;
  final bool metadataComplete;
  final bool enrollStarted;
  final bool enrollComplete;

  bool get canEnroll =>
      wifiConfigured && tenantAssociated && metadataComplete && !enrollStarted;

  bool get isEnrolling => enrollStarted && !enrollComplete;

  ProvisioningState copyWith({
    WaterMeterSetupStep? step,
    String? deviceSerial,
    String? deviceDisplayName,
    String? block,
    String? wing,
    String? floor,
    String? residentName,
    String? phoneNumber,
    String? notes,
    String? errorMessage,
    bool? isLoading,
    bool? wifiConfigured,
    bool? tenantAssociated,
    bool? metadataComplete,
    bool? enrollStarted,
    bool? enrollComplete,
    bool clearError = false,
    bool resetProvisioningFlags = false,
  }) {
    return ProvisioningState(
      step: step ?? this.step,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      deviceDisplayName: deviceDisplayName ?? this.deviceDisplayName,
      block: block ?? this.block,
      wing: wing ?? this.wing,
      floor: floor ?? this.floor,
      residentName: residentName ?? this.residentName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      notes: notes ?? this.notes,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
      wifiConfigured:
          resetProvisioningFlags ? false : (wifiConfigured ?? this.wifiConfigured),
      tenantAssociated: resetProvisioningFlags
          ? false
          : (tenantAssociated ?? this.tenantAssociated),
      metadataComplete: resetProvisioningFlags
          ? false
          : (metadataComplete ?? this.metadataComplete),
      enrollStarted:
          resetProvisioningFlags ? false : (enrollStarted ?? this.enrollStarted),
      enrollComplete: resetProvisioningFlags
          ? false
          : (enrollComplete ?? this.enrollComplete),
    );
  }
}
