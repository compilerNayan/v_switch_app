import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/models/quota_config.dart';
import 'package:water_meter_app/core/models/valve_state.dart';
import 'package:water_meter_app/core/models/water_unit.dart';
import 'package:water_meter_app/core/providers/control_providers.dart';
import 'package:water_meter_app/core/providers/unit_providers.dart';
import 'package:water_meter_app/features/control/control_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final valve = ValveState(
    deviceId: 'WM-1',
    timestamp: DateTime.utc(2026, 6, 6, 14, 30),
    targetPressurePercent: 80,
    actualPressurePercent: 78,
    lastUserPressurePercent: 80,
    isOff: false,
    controlMode: ValveControlMode.manual,
    effectivePressurePercent: 78,
  );

  final quota = QuotaResponse(
    deviceId: 'WM-1',
    enabled: false,
    dailyLimitLiters: 500,
    timezone: 'UTC',
    steps: const [],
    status: QuotaStatus(
      date: DateTime(2026, 6, 6),
      usedLiters: 120,
      activeStepIndex: -1,
      remainingLiters: 380,
    ),
  );

  testWidgets('renders tap control and pressure labels', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedRouteDeviceIdProvider.overrideWith((ref) => 'wm-1'),
          isDeviceAdminProvider.overrideWith((ref) => true),
          valveControlNotifierProvider.overrideWith(() => _FakeValveNotifier(valve)),
          quotaStateProvider.overrideWith((ref) async => quota),
        ],
        child: const MaterialApp(home: ControlScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tap control'), findsOneWidget);
    expect(find.textContaining('Actual:'), findsOneWidget);
    expect(find.textContaining('Target:'), findsOneWidget);
  });

  testWidgets('maintenance mode locks valve controls', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedRouteDeviceIdProvider.overrideWith((ref) => 'wm-1'),
          isDeviceAdminProvider.overrideWith((ref) => true),
          waterUnitsProvider.overrideWith(
            (ref) async => const [
              WaterUnit(
                id: 'wm-1',
                name: 'D205',
                deviceId: 'WM-1',
                maintenanceMode: true,
              ),
            ],
          ),
          valveControlNotifierProvider.overrideWith(() => _FakeValveNotifier(valve)),
          quotaStateProvider.overrideWith((ref) async => quota),
        ],
        child: const MaterialApp(home: ControlScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maintenance mode — valve locked off'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.onChanged, isNull);
  });
}

class _FakeValveNotifier extends ValveControlNotifier {
  _FakeValveNotifier(this.initial);

  final ValveState initial;

  @override
  Future<ValveState> build() async => initial;
}
