import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/features/devices/add_device_screen.dart';

void main() {
  testWidgets('renders standard device type names', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AddDeviceScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Smart Plug'), findsOneWidget);
    expect(find.text('Choose a device type'), findsOneWidget);
  });

  testWidgets('tap shows not supported yet snackbar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AddDeviceScreen()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switch'));
    await tester.pump();

    expect(find.text('Switch is not supported yet'), findsOneWidget);
  });
}
