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
    this.errorMessage,
    this.isLoading = false,
    this.wifiConfigured = false,
    this.tenantAssociated = false,
  });

  final WaterMeterSetupStep step;
  final String? deviceSerial;
  final String? deviceDisplayName;
  final String? block;
  final String? wing;
  final String? floor;
  final String? errorMessage;
  final bool isLoading;
  final bool wifiConfigured;
  final bool tenantAssociated;

  bool get canEnroll => wifiConfigured && tenantAssociated;

  ProvisioningState copyWith({
    WaterMeterSetupStep? step,
    String? deviceSerial,
    String? deviceDisplayName,
    String? block,
    String? wing,
    String? floor,
    String? errorMessage,
    bool? isLoading,
    bool? wifiConfigured,
    bool? tenantAssociated,
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
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
      wifiConfigured:
          resetProvisioningFlags ? false : (wifiConfigured ?? this.wifiConfigured),
      tenantAssociated: resetProvisioningFlags
          ? false
          : (tenantAssociated ?? this.tenantAssociated),
    );
  }
}
