import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/core/utils/secret_tap_detector.dart';

void main() {
  testWidgets('activates after ten taps within the reset window', (tester) async {
    var activated = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecretTapDetector(
            onActivated: () => activated++,
            child: const Text('Building'),
          ),
        ),
      ),
    );

    for (var i = 0; i < 9; i++) {
      await tester.tap(find.text('Building'));
      await tester.pump();
    }
    expect(activated, 0);

    await tester.tap(find.text('Building'));
    await tester.pump();
    expect(activated, 1);
  });
}
