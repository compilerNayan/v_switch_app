import 'dart:math';

import '../api/tenant_api_client.dart';
import '../models/bulk_dummy_enroll_response.dart';
import '../models/tenant_config.dart';
import '../models/user_profile.dart';
import 'dummy_device_generator.dart';

class DummyOnboardingService {
  const DummyOnboardingService();

  Future<BulkDummyEnrollResponse> provisionDummyDevices({
    required TenantApiClient apiClient,
    required String tenantId,
    required UserProfile profile,
    required int deviceCount,
    Random? random,
  }) async {
    final rng = random ?? Random();
    final structure = DummyDeviceGenerator.generateStructure(rng);
    final buildingName = _defaultBuildingName(profile);
    final devices = DummyDeviceGenerator.generateDevices(
      count: deviceCount,
      structure: structure,
      random: rng,
    );

    await apiClient.createBuilding(
      tenantId: tenantId,
      name: buildingName,
      structure: structure,
    );

    return apiClient.bulkDummyEnroll(
      tenantId: tenantId,
      devices: devices.map((device) => device.toJson()).toList(),
    );
  }

  static String _defaultBuildingName(UserProfile profile) {
    final first = profile.firstName?.trim();
    if (first != null && first.isNotEmpty) {
      return '$first Residency';
    }
    final display = profile.displayName.trim();
    if (display.isNotEmpty) {
      return '$display Residency';
    }
    return 'Demo Residency';
  }
}
