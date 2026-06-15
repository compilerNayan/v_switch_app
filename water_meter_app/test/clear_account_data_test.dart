import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/models/home_dashboard.dart';
import 'package:water_meter_app/core/models/tenant_config.dart';
import 'package:water_meter_app/core/models/tenant_metadata.dart';
import 'package:water_meter_app/core/models/user_profile.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearAccountData removes tenant-linked local state', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesStorage.create();
    const tenantId = 'tenant-abc';

    await prefs.setTenantConfig(
      const TenantConfig(
        tenantId: tenantId,
        name: 'Sunrise',
        structure: TenantStructure(),
      ),
    );
    await prefs.setCachedUserProfile(
      const UserProfile(
        userId: 'user-1',
        email: 'owner@example.com',
        displayName: 'Owner',
        tenantId: tenantId,
        onboardingComplete: true,
        isTenantOwner: true,
      ),
    );
    await prefs.addWaterUnit(
      const WaterUnit(
        id: 'wm-WM001',
        name: 'Unit 1',
        deviceId: 'WM001',
      ),
    );
    await prefs.setHomeSnapshot(
      tenantId,
      HomeSnapshot(
        metadata: TenantMetadataResponse(
          metadataHash: 'hash',
          tenantId: tenantId,
          buildingName: 'Sunrise',
          structure: const TenantStructure(),
          owner: const TenantMetadataOwner(
            userId: 'user-1',
            email: 'owner@example.com',
            displayName: 'Owner',
          ),
          devices: const [],
        ),
        dashboard: const HomeDashboardResponse(
          metadataHash: 'hash',
          generatedAt: '2026-01-01T00:00:00Z',
          devices: [],
        ),
      ),
    );

    expect(prefs.tenantExists, isTrue);
    expect(prefs.getWaterUnits(), isNotEmpty);
    expect(prefs.getCachedUserProfile(), isNotNull);

    await prefs.clearAccountData(tenantId: tenantId);

    expect(prefs.tenantExists, isFalse);
    expect(prefs.getWaterUnits(), isEmpty);
    expect(prefs.getCachedUserProfile(), isNull);
    expect(prefs.getHomeSnapshot(tenantId), isNull);
  });
}
