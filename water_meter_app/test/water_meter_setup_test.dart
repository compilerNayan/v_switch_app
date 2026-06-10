import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/provisioning/mock_enrollment_client.dart';
import 'package:water_meter_app/core/provisioning/provisioning_state.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/providers/provisioning_providers.dart';
import 'package:water_meter_app/core/providers/tenant_providers.dart';
import 'package:water_meter_app/features/devices/water_meter/steps/device_prep_step.dart';
import 'package:water_meter_app/features/devices/water_meter/steps/name_device_step.dart';
import 'package:water_meter_app/features/devices/water_meter/water_meter_setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
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

  testWidgets('name device step requires a label', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ProvisioningNotifier? notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async => null),
          tenantConfigProvider.overrideWith((ref) async => null),
          mockEnrollmentClientProvider
              .overrideWithValue(const MockEnrollmentClient(delayMs: 0)),
          provisioningNotifierProvider.overrideWith((ref) {
            notifier = ProvisioningNotifier(ref)
              ..setDeviceSerial('SERIAL1');
            return notifier!;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NameDeviceStep()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unit details'), findsOneWidget);

    final addButton = find.text('Add device (mock)');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsWidgets);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'D205');
    await tester.enterText(fields.at(2), 'Ravi Kumar');
    await tester.enterText(fields.at(3), '+919876543210');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(notifier!.state.step, WaterMeterSetupStep.success);
    expect(notifier!.state.deviceDisplayName, 'D205');
    expect(notifier!.state.block, isNull);
    expect(notifier!.state.wing, isNull);
  });

  test('provisioning state copyWith clears error when requested', () {
    const state = ProvisioningState(errorMessage: 'fail');
    final updated = state.copyWith(clearError: true);
    expect(updated.errorMessage, isNull);
    expect(updated.step, WaterMeterSetupStep.devicePrep);
  });
}
