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

  void setResidentName(String name) {
    state = state.copyWith(residentName: name.trim(), clearError: true);
  }

  void setPhoneNumber(String phone) {
    state = state.copyWith(phoneNumber: phone.trim(), clearError: true);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes.trim(), clearError: true);
  }

  void markMetadataComplete() {
    state = state.copyWith(metadataComplete: true, clearError: true);
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

  /// Starts device LAN enroll + cloud unit creation in parallel.
  Future<bool> enrollDevice() async {
    if (!state.canEnroll) {
      setError(
        'Complete WiFi setup, unit details, and building registration first.',
      );
      return false;
    }

    final serial = state.deviceSerial;
    final displayName = state.deviceDisplayName?.trim();
    if (serial == null || serial.isEmpty || displayName == null || displayName.isEmpty) {
      setError('Device details are incomplete.');
      return false;
    }

    final profile = await ref.read(userProfileProvider.future);
    final tenantId = profile?.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      setError('No tenant found.');
      return false;
    }

    setLoading(true);
    try {
      final enrollmentClient = ref.read(enrollmentClientProvider);
      final tenantApi = ref.read(tenantApiClientProvider);

      Object? deviceError;
      Object? cloudError;

      await Future.wait([
        enrollmentClient.enroll(serial).then((result) {
          if (result is! EnrollmentSuccess) {
            deviceError = result;
          }
        }),
        tenantApi
            .createUnit(
              tenantId: tenantId,
              deviceId: serial,
              name: displayName,
              flatNumber: displayName,
              floor: state.floor ?? '',
              block: state.block ?? '',
              wing: state.wing ?? '',
              residentName: state.residentName ?? '',
              phoneNumber: state.phoneNumber ?? '',
              notes: state.notes,
            )
            .catchError((Object error) => cloudError = error),
      ]);

      if (deviceError != null && cloudError != null) {
        setError(_enrollErrorMessage(deviceError) +
            ' Also failed to register unit in cloud.');
        return false;
      }
      if (cloudError != null) {
        setError(_cloudErrorMessage(cloudError));
        return false;
      }
      if (deviceError != null) {
        setError(_enrollErrorMessage(deviceError));
        return false;
      }

      await registerWaterMeter(
        serial: serial,
        displayName: displayName,
        enrollmentStatus: UnitEnrollmentStatus.pending,
      );

      state = state.copyWith(
        enrollStarted: true,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      setError(error.toString());
      return false;
    }
  }

  /// Polls cloud enrollment status; marks unit enrolled and completes flow.
  Future<bool> pollEnrollmentStatus() async {
    if (!state.enrollStarted || state.enrollComplete) {
      return state.enrollComplete;
    }

    final serial = state.deviceSerial;
    if (serial == null || serial.isEmpty) {
      return false;
    }

    final profile = await ref.read(userProfileProvider.future);
    final tenantId = profile?.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return false;
    }

    try {
      final tenantApi = ref.read(tenantApiClientProvider);
      final status = await tenantApi.getEnrollmentStatus(
        tenantId: tenantId,
        deviceId: serial,
      );

      if (!status.enrolled) {
        return false;
      }

      await _markUnitEnrolled(serial);
      state = state.copyWith(
        enrollComplete: true,
        step: WaterMeterSetupStep.success,
        clearError: true,
      );
      return true;
    } catch (error) {
      setError(_cloudErrorMessage(error));
      return false;
    }
  }

  Future<void> _markUnitEnrolled(String serial) async {
    final prefs = await ref.read(preferencesStorageProvider.future);
    final units = prefs.getWaterUnits();
    final index = units.indexWhere((u) => u.deviceId == serial);
    if (index >= 0) {
      await prefs.updateWaterUnit(
        units[index].copyWith(enrollmentStatus: UnitEnrollmentStatus.enrolled),
      );
      ref.invalidate(waterUnitsProvider);
    }
  }

  String _enrollErrorMessage(Object? result) {
    return switch (result) {
      EnrollmentHttpError(:final code) => 'Device enrollment failed (HTTP $code).',
      EnrollmentNetworkError(:final message) => 'Device enrollment error: $message',
      _ => 'Device enrollment failed.',
    };
  }

  String _cloudErrorMessage(Object? error) {
    if (error is ApiException) {
      return error.error.message;
    }
    if (error is NetworkException) {
      return error.message;
    }
    return error?.toString() ?? 'Cloud registration failed.';
  }

  Future<WaterUnit> registerWaterMeter({
    required String serial,
    required String displayName,
    String? block,
    String? wing,
    String? floor,
    String? residentName,
    String? phoneNumber,
    String? notes,
    UnitEnrollmentStatus enrollmentStatus = UnitEnrollmentStatus.enrolled,
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
      residentName: residentName?.trim() ?? state.residentName?.trim(),
      phoneNumber: phoneNumber?.trim() ?? state.phoneNumber?.trim(),
      notes: notes?.trim() ?? state.notes?.trim(),
      enrollmentStatus: enrollmentStatus,
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
