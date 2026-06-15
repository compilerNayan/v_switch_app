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

  testWidgets('usage screen shows dual charts and day summaries', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UsageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Yesterday'), findsWidgets);
    expect(find.text('Usage by period'), findsOneWidget);
    expect(find.text('Total'), findsWidgets);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Cumulative usage'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
  });

  testWidgets('bar chart query is not reset on every rebuild', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UsageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsageScreen)),
    );
    final queryAfterLoad = container.read(barUsageQueryProvider);
    expect(queryAfterLoad, isNotNull);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final queryAfterRebuild = container.read(barUsageQueryProvider);
    expect(queryAfterRebuild, queryAfterLoad);
  });

  testWidgets('cumulative range chips update cumulative query', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: UsageScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UsageScreen)),
    );
    expect(
      container.read(cumulativeUsageQueryProvider)?.preset.name,
      'thirtyDays',
    );
  });
}
