import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_device.dart';
import '../provisioning/enrollment_client.dart';
import '../provisioning/provisioning_state.dart';
import '../provisioning/wifi_credentials_client.dart';
import '../provisioning/wifi_ssid_service.dart';
import 'app_providers.dart';
import 'device_providers.dart';

final wifiSsidServiceProvider = Provider<WifiSsidService>((ref) {
  return WifiSsidService();
});

final wifiCredentialsClientProvider = Provider<WifiCredentialsClient>((ref) {
  return WifiCredentialsClient();
});

final enrollmentClientProvider = Provider<EnrollmentClient>((ref) {
  return EnrollmentClient();
});

class ProvisioningNotifier extends StateNotifier<ProvisioningState> {
  ProvisioningNotifier(this.ref) : super(const ProvisioningState());

  final Ref ref;

  void goToStep(WaterMeterSetupStep step) {
    state = state.copyWith(step: step, clearError: true);
  }

  void setDeviceSerial(String serial) {
    state = state.copyWith(deviceSerial: serial, clearError: true);
  }

  void setDeviceDisplayName(String name) {
    state = state.copyWith(deviceDisplayName: name.trim(), clearError: true);
  }

  void setError(String message) {
    state = state.copyWith(errorMessage: message, isLoading: false);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading, clearError: true);
  }

  Future<bool> configureHomeWifi({
    required String homeSsid,
    required String homePassword,
  }) async {
    final serial = state.deviceSerial;
    if (serial == null || serial.isEmpty) {
      setError('Device serial not detected. Connect to the IoT_ hotspot first.');
      return false;
    }

    setLoading(true);
    try {
      final ssidService = ref.read(wifiSsidServiceProvider);
      if (!await ssidService.isConnectedToWifi()) {
        setError('Connect to WiFi first.');
        return false;
      }

      final currentSsid = await ssidService.getCurrentSsid();
      if (!WifiSsidService.isOnIotHotspot(currentSsid)) {
        setError('Connect to the IoT_ device hotspot first.');
        return false;
      }

      final client = ref.read(wifiCredentialsClientProvider);
      final result = await client.configureWifi(
        homeWifiSsid: homeSsid,
        homeWifiPassword: homePassword,
        deviceSerialNumber: serial,
      );

      switch (result) {
        case WifiConfigureSuccess():
          state = state.copyWith(
            step: WaterMeterSetupStep.nameDevice,
            isLoading: false,
            clearError: true,
          );
          return true;
        case WifiConfigureHttpError(:final code):
          setError('WiFi configuration failed (HTTP $code).');
          return false;
        case WifiConfigureNetworkError(:final message):
          setError('Network error: $message');
          return false;
      }
    } catch (error) {
      setError(error.toString());
      return false;
    }
  }

  Future<bool> enrollDevice() async {
    final serial = state.deviceSerial;
    if (serial == null || serial.isEmpty) {
      setError('No device serial saved.');
      return false;
    }

    setLoading(true);
    try {
      final ssidService = ref.read(wifiSsidServiceProvider);
      final currentSsid = await ssidService.getCurrentSsid();
      final onWifi = await ssidService.isConnectedToWifi();
      if (!WifiSsidService.canEnroll(
        savedSerial: serial,
        currentSsid: currentSsid,
        isOnWifi: onWifi,
      )) {
        setError('Reconnect to your home WiFi, then try again.');
        return false;
      }

      final client = ref.read(enrollmentClientProvider);
      final result = await client.enroll(serial);

      switch (result) {
        case EnrollmentSuccess():
          final displayName = state.deviceDisplayName?.trim();
          await registerWaterMeter(
            serial: serial,
            displayName: displayName != null && displayName.isNotEmpty
                ? displayName
                : serial,
          );
          state = state.copyWith(
            step: WaterMeterSetupStep.success,
            isLoading: false,
            clearError: true,
          );
          return true;
        case EnrollmentHttpError(:final code):
          setError('Enrollment failed (HTTP $code).');
          return false;
        case EnrollmentNetworkError(:final message):
          setError('Network error: $message');
          return false;
      }
    } catch (error) {
      setError(error.toString());
      return false;
    }
  }

  Future<UserDevice> registerWaterMeter({
    required String serial,
    required String displayName,
  }) async {
    final prefs = await ref.read(preferencesStorageProvider.future);
    final device = UserDevice(
      id: 'wm-$serial',
      typeId: 'water_meter',
      name: displayName.trim(),
      deviceId: serial,
    );
    final saved = await prefs.addUserDevice(device);
    ref.invalidate(userDevicesProvider);
    return saved;
  }

  String? registeredDeviceRouteId(String serial) => 'wm-$serial';
}

final provisioningNotifierProvider =
    StateNotifierProvider<ProvisioningNotifier, ProvisioningState>((ref) {
  return ProvisioningNotifier(ref);
});
