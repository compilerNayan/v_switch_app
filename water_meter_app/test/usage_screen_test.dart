import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/providers/water_providers.dart';
import 'package:water_meter_app/features/usage/usage_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('today and 7-day presets load usage data', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UsageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No data for this period'), findsNothing);
    expect(find.text('Total'), findsOneWidget);

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();

    expect(find.text('No data for this period'), findsNothing);
    expect(find.text('Total'), findsOneWidget);
  });

  testWidgets('usage query is not reset on every rebuild for today preset', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UsageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsageScreen)),
    );
    final queryAfterLoad = container.read(usageQueryProvider);
    expect(queryAfterLoad, isNotNull);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final queryAfterRebuild = container.read(usageQueryProvider);
    expect(queryAfterRebuild, queryAfterLoad);
  });
}
