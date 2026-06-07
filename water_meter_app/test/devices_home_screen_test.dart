import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/api/mock_water_api_client.dart';
import 'package:water_meter_app/core/models/current_reading.dart';
import 'package:water_meter_app/core/models/quota_config.dart';
import 'package:water_meter_app/core/models/user_device.dart';
import 'package:water_meter_app/core/models/valve_state.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/control_providers.dart';
import 'package:water_meter_app/core/providers/device_providers.dart';
import 'package:water_meter_app/core/providers/device_tile_providers.dart';
import 'package:water_meter_app/features/devices/devices_home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows empty state with add first device button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userDevicesProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: DevicesHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No devices yet'), findsOneWidget);
    expect(find.text('Add your first device'), findsOneWidget);
  });

  testWidgets('shows device tile with name and switch', (tester) async {
    const devices = [
      UserDevice(
        id: 'wm-001',
        typeId: 'water_meter',
        name: 'D205',
        deviceId: '001',
      ),
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
          userDevicesProvider.overrideWith((ref) async => devices),
          waterApiClientProvider.overrideWithValue(MockWaterApiClient(seed: 1)),
          isDeviceAdminProvider.overrideWith((ref) => true),
          deviceValveProvider('001').overrideWith((ref) async => valve),
          deviceQuotaProvider('001').overrideWith((ref) async => quota),
          deviceTodayUsageProvider('001').overrideWith((ref) async => 50),
          deviceCurrentReadingProvider('001')
              .overrideWith((ref) async => reading),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, __) => const DevicesHomeScreen(),
              ),
              GoRoute(
                path: '/devices/add',
                builder: (_, __) => const Scaffold(body: Text('Add screen')),
              ),
              GoRoute(
                path: '/devices/:deviceId/dashboard',
                builder: (_, __) => const Scaffold(body: Text('Dashboard')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('D205'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Add device'), findsOneWidget);
    expect(find.text('Tap for details →'), findsOneWidget);
  });
}
