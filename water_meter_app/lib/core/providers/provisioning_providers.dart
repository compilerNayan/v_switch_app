import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exceptions.dart';
import '../models/water_unit.dart';
import '../provisioning/enrollment_client.dart';
import '../provisioning/internet_reachability_service.dart';
import '../provisioning/mock_enrollment_client.dart';
import '../provisioning/provisioning_state.dart';
import '../provisioning/wifi_credentials_client.dart';
import '../provisioning/wifi_ssid_service.dart';
import 'app_providers.dart';
import 'unit_providers.dart';

final wifiSsidServiceProvider = Provider<WifiSsidService>((ref) {
  return WifiSsidService();
});

final internetReachabilityServiceProvider =
    Provider<InternetReachabilityService>((ref) {
  return InternetReachabilityService();
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
    state = state.copyWith(
      deviceSerial: serial,
      clearError: true,
      resetProvisioningFlags: true,
    );
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

  void setFloor(String floor) {
    state = state.copyWith(floor: floor.trim(), clearError: true);
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

      final wifiClient = ref.read(wifiCredentialsClientProvider);
      final wifiResult = await wifiClient.configureWifi(
        homeWifiSsid: homeSsid,
        homeWifiPassword: homePassword,
        deviceSerialNumber: serial,
      );

      if (wifiResult is! WifiConfigureSuccess) {
        setError(_wifiErrorMessage(wifiResult));
        return false;
      }

      state = state.copyWith(
        step: WaterMeterSetupStep.nameDevice,
        wifiConfigured: true,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      setError(error.toString());
      return false;
    }
  }

  String _wifiErrorMessage(WifiConfigureResult? result) {
    return switch (result) {
      WifiConfigureHttpError(:final code) =>
        'WiFi configuration failed (HTTP $code).',
      WifiConfigureNetworkError(:final message) => 'Network error: $message',
      _ => 'WiFi configuration failed.',
    };
  }

  String _preEnrollErrorMessage(Object? error) {
    if (error is ApiException) {
      return error.error.message;
    }
    if (error is NetworkException) {
      return error.message;
    }
    return error?.toString() ?? 'Failed to register device with your building.';
  }

  /// Registers the device serial with the tenant once regular WiFi + internet are available.
  ///
  /// Returns `false` without setting an error when the phone is still offline or on the
  /// IoT hotspot — callers may retry after the user reconnects to home WiFi.
  Future<bool> associateDeviceWithTenant() async {
    if (state.tenantAssociated) {
      return true;
    }

    final serial = state.deviceSerial;
    if (serial == null || serial.isEmpty) {
      setError('Device serial not detected.');
      return false;
    }
    if (!state.wifiConfigured) {
      setError('Configure device WiFi first.');
      return false;
    }

    final reachability = ref.read(internetReachabilityServiceProvider);
    if (!await reachability.canReachCloud()) {
      return false;
    }

    final profile = await ref.read(userProfileProvider.future);
    final tenantId = profile?.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setError('No tenant found. Sign in and complete registration first.');
      return false;
    }

    try {
      final tenantApi = ref.read(tenantApiClientProvider);
      await tenantApi.preEnrollDevice(tenantId: tenantId, serialNumber: serial);
      state = state.copyWith(tenantAssociated: true, clearError: true);
      return true;
    } catch (error) {
      setError(_preEnrollErrorMessage(error));
      return false;
    }
  }

  /// Dummy enroll — prerequisites must be met; no device or cloud enroll yet.
  Future<bool> enrollDevice() async {
    if (!state.canEnroll) {
      setError('Configure device WiFi and register with your building first.');
      return false;
    }
    return true;
  }

  Future<WaterUnit> registerWaterMeter({
    required String serial,
    required String displayName,
    String? block,
    String? wing,
    String? floor,
  }) async {
    final prefs = await ref.read(preferencesStorageProvider.future);
    final unit = WaterUnit(
      id: 'wm-$serial',
      name: displayName.trim(),
      deviceId: serial,
      flatNumber: displayName.trim(),
      block: block?.trim() ?? state.block?.trim() ?? '',
      wing: wing?.trim() ?? state.wing?.trim() ?? '',
      floor: floor?.trim() ?? state.floor?.trim() ?? '',
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
