import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/models/current_reading.dart';
import 'package:water_meter_app/core/models/device_health.dart';
import 'package:water_meter_app/core/models/quota_config.dart';
import 'package:water_meter_app/core/models/user_profile.dart';
import 'package:water_meter_app/core/models/valve_state.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/control_providers.dart';
import 'package:water_meter_app/core/providers/device_tile_providers.dart';
import 'package:water_meter_app/features/units/unit_tile.dart';
import 'support/test_user_profile_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final unit = WaterUnit(
    id: 'wm-1',
    name: 'D205',
    deviceId: 'WM000001',
    block: 'A',
    wing: 'East',
  );

  testWidgets('shows disabled call buttons and snackbar without phone', (tester) async {
    final valve = ValveState(
      deviceId: 'WM000001',
      timestamp: DateTime.utc(2026, 6, 6),
      targetPressurePercent: 100,
      actualPressurePercent: 98,
      lastUserPressurePercent: 100,
      isOff: false,
      controlMode: ValveControlMode.manual,
      effectivePressurePercent: 98,
    );

    final reading = CurrentReading(
      deviceId: 'WM000001',
      timestamp: DateTime.utc(2026, 6, 6),
      flowRateLpm: 0,
      cumulativeLiters: 1000,
      status: WaterDeviceStatus.idle,
    );

    final quota = QuotaResponse(
      deviceId: 'WM000001',
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
          authInitProvider.overrideWith((ref) async {}),
          userProfileProvider.overrideWith(
            () => TestUserProfileNotifier(
              const UserProfile(
                userId: 'admin',
                email: 'admin@test.com',
                displayName: 'Admin',
                tenantId: 'demo',
                onboardingComplete: true,
              ),
            ),
          ),
          isDeviceAdminProvider.overrideWith((ref) => true),
          deviceValveProvider('WM000001').overrideWith((ref) async => valve),
          deviceQuotaProvider('WM000001').overrideWith((ref) async => quota),
          deviceTodayUsageProvider('WM000001').overrideWith((ref) async => 50),
          deviceCurrentReadingProvider('WM000001')
              .overrideWith((ref) async => reading),
          deviceHealthProvider('WM000001').overrideWith(
            (ref) async => DeviceHealth.fromReading(
              unitId: 'WM000001',
              readingTimestamp: reading.timestamp.toLocal(),
            ),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: UnitTile(unit: unit)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chat_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.phone_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('No phone number on file. Add one in Edit unit.'),
      findsOneWidget,
    );
  });
}
