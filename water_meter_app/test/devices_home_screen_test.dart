import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/models/user_device.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/device_providers.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';
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

  testWidgets('shows device list and add another device', (tester) async {
    const devices = [
      UserDevice(
        id: 'wm-001',
        typeId: 'water_meter',
        name: 'Water Meter 001',
        deviceId: '001',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userDevicesProvider.overrideWith((ref) async => devices),
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
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Water Meter 001'), findsOneWidget);
    expect(find.text('Add another device'), findsOneWidget);
  });
}
