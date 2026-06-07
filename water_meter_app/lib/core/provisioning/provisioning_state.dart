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
    this.errorMessage,
    this.isLoading = false,
  });

  final WaterMeterSetupStep step;
  final String? deviceSerial;
  final String? deviceDisplayName;
  final String? errorMessage;
  final bool isLoading;

  ProvisioningState copyWith({
    WaterMeterSetupStep? step,
    String? deviceSerial,
    String? deviceDisplayName,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
  }) {
    return ProvisioningState(
      step: step ?? this.step,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      deviceDisplayName: deviceDisplayName ?? this.deviceDisplayName,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
