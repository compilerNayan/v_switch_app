enum WaterMeterSetupStep {
  devicePrep,
  connectHotspot,
  homeWifi,
  enrollment,
  success,
}

class ProvisioningState {
  const ProvisioningState({
    this.step = WaterMeterSetupStep.devicePrep,
    this.deviceSerial,
    this.errorMessage,
    this.isLoading = false,
  });

  final WaterMeterSetupStep step;
  final String? deviceSerial;
  final String? errorMessage;
  final bool isLoading;

  ProvisioningState copyWith({
    WaterMeterSetupStep? step,
    String? deviceSerial,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
  }) {
    return ProvisioningState(
      step: step ?? this.step,
      deviceSerial: deviceSerial ?? this.deviceSerial,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
