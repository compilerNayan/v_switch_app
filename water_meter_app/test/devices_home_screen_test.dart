import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/api/mock_water_api_client.dart';
import 'package:water_meter_app/core/models/current_reading.dart';
import 'package:water_meter_app/core/models/device_health.dart';
import 'package:water_meter_app/core/models/quota_config.dart';
import 'package:water_meter_app/core/models/user_profile.dart';
import 'package:water_meter_app/core/models/valve_state.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/control_providers.dart';
import 'package:water_meter_app/core/providers/device_tile_providers.dart';
import 'package:water_meter_app/core/providers/unit_providers.dart';
import 'package:water_meter_app/features/building/building_home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows empty state with add water meter button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          waterUnitsProvider.overrideWith((ref) async => []),
          userProfileProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: BuildingHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No water meters yet'), findsOneWidget);
    expect(find.text('Add water meter'), findsOneWidget);
  });

  testWidgets('shows unit tile with name and switch', (tester) async {
    const units = [
      WaterUnit(id: 'wm-001', name: 'D205', deviceId: '001'),
    ];

    final valve = ValveState(
      deviceId: '001',
      timestamp: DateTime.utc(2026, 6, 6),
      targetPressurePercent: 100,
      actualPressurePercent: 98,
      lastUserPressurePercent: 100,
      isOff: false,
      controlMode: ValveControlMode.manual,
      effectivePressurePercent: 98,
    );

    final reading = CurrentReading(
      deviceId: '001',
      timestamp: DateTime.utc(2026, 6, 6),
      flowRateLpm: 2.3,
      cumulativeLiters: 1000,
      status: WaterDeviceStatus.flowing,
    );

    final quota = QuotaResponse(
      deviceId: '001',
      enabled: false,
      dailyLimitLiters: 500,
      timezone: 'UTC',
      steps: const [],
      status: QuotaStatus(
        date: DateTime(2026, 6, 6),
        usedLiters: 50,
        activeStepIndex: -1,
        remainingLiters: 450,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          waterUnitsProvider.overrideWith((ref) async => units),
          userProfileProvider.overrideWith(
            (ref) async => const UserProfile(
              userId: 'admin',
              email: 'a@test.com',
              displayName: 'Admin',
              role: UserRole.admin,
              tenantId: 't1',
              onboardingComplete: true,
            ),
          ),
          waterApiClientProvider.overrideWithValue(MockWaterApiClient(seed: 1)),
          isDeviceAdminProvider.overrideWith((ref) => true),
          deviceValveProvider('001').overrideWith((ref) async => valve),
          deviceQuotaProvider('001').overrideWith((ref) async => quota),
          deviceTodayUsageProvider('001').overrideWith((ref) async => 50),
          deviceCurrentReadingProvider('001')
              .overrideWith((ref) async => reading),
          deviceHealthProvider('001').overrideWith(
            (ref) async => DeviceHealth.fromReading(
              unitId: '001',
              readingTimestamp: reading.timestamp.toLocal(),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const BuildingHomeScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('D205'), findsWidgets);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Add water meter'), findsOneWidget);
  });
}
