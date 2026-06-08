import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../models/water_unit.dart';
import '../provisioning/enrollment_client.dart';
import '../provisioning/mock_enrollment_client.dart';
import '../provisioning/provisioning_state.dart';
import '../provisioning/wifi_credentials_client.dart';
import '../provisioning/wifi_ssid_service.dart';
import 'app_providers.dart';
import 'unit_providers.dart';

final wifiSsidServiceProvider = Provider<WifiSsidService>((ref) {
  return WifiSsidService();
});

final wifiCredentialsClientProvider = Provider<WifiCredentialsClient>((ref) {
  return WifiCredentialsClient();
});

final enrollmentClientProvider = Provider<EnrollmentClient>((ref) {
  return EnrollmentClient();
});

final mockEnrollmentClientProvider = Provider<MockEnrollmentClient>((ref) {
  return const MockEnrollmentClient();
});

String generateMockDeviceSerial() {
  final random = Random();
  final suffix = random.nextInt(900000) + 100000;
  return 'WM$suffix';
}

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

  void setBlock(String block) {
    state = state.copyWith(block: block.trim(), clearError: true);
  }

  void setWing(String wing) {
    state = state.copyWith(wing: wing.trim(), clearError: true);
  }

  void assignMockSerial() {
    setDeviceSerial(generateMockDeviceSerial());
  }

  /// Mock path: random serial + simulated enroll + register (no WiFi/device).
  Future<bool> mockEnrollAndRegister() async {
    final displayName = state.deviceDisplayName?.trim();
    if (displayName == null || displayName.isEmpty) {
      setError('Enter a device name first.');
      return false;
    }

    final serial = state.deviceSerial ?? generateMockDeviceSerial();
    if (state.deviceSerial == null) {
      state = state.copyWith(deviceSerial: serial);
    }

    setLoading(true);
    try {
      final client = ref.read(mockEnrollmentClientProvider);
      final result = await client.enroll(serial);

      switch (result) {
        case EnrollmentSuccess():
          await registerWaterMeter(serial: serial, displayName: displayName);
          state = state.copyWith(
            step: WaterMeterSetupStep.success,
            isLoading: false,
            clearError: true,
          );
          return true;
        case EnrollmentHttpError(:final code):
          setError('Mock enrollment failed (HTTP $code).');
          return false;
        case EnrollmentNetworkError(:final message):
          setError('Mock enrollment error: $message');
          return false;
      }
    } catch (error) {
      setError(error.toString());
      return false;
    }
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

  Future<WaterUnit> registerWaterMeter({
    required String serial,
    required String displayName,
    String? block,
    String? wing,
  }) async {
    final prefs = await ref.read(preferencesStorageProvider.future);
    final unit = WaterUnit(
      id: 'wm-$serial',
      name: displayName.trim(),
      deviceId: serial,
      flatNumber: displayName.trim(),
      block: block?.trim() ?? state.block?.trim() ?? '',
      wing: wing?.trim() ?? state.wing?.trim() ?? '',
    );
    final saved = await prefs.addWaterUnit(unit);
    ref.invalidate(waterUnitsProvider);
    return saved;
  }

  String? registeredDeviceRouteId(String serial) => 'wm-$serial';
}

final provisioningNotifierProvider =
    StateNotifierProvider<ProvisioningNotifier, ProvisioningState>((ref) {
  return ProvisioningNotifier(ref);
});
