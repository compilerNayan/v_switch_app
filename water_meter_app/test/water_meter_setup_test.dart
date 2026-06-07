import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/provisioning/provisioning_state.dart';
import 'package:water_meter_app/features/devices/water_meter/steps/device_prep_step.dart';
import 'package:water_meter_app/features/devices/water_meter/water_meter_setup_screen.dart';

void main() {
  testWidgets('device prep step requires green light confirmation', (tester) async {
    var continued = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DevicePrepStep(onContinue: () => continued = true),
        ),
      ),
    );

    expect(find.text('Continue'), findsOneWidget);
    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.tap(find.text('Device is powered on and within range'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(continued, isTrue);
  });

  testWidgets('setup screen starts on device prep step', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: WaterMeterSetupScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prepare your water meter'), findsOneWidget);
    expect(find.text('Set up water meter'), findsOneWidget);
  });

  test('provisioning state copyWith clears error when requested', () {
    const state = ProvisioningState(errorMessage: 'fail');
    final updated = state.copyWith(clearError: true);
    expect(updated.errorMessage, isNull);
    expect(updated.step, WaterMeterSetupStep.devicePrep);
  });
}
