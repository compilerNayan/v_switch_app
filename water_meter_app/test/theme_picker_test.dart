import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/theme/app_theme.dart';
import 'package:water_meter_app/features/settings/theme_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('selecting a theme updates appThemeIdProvider', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.themeFor(AppThemeId.ocean),
          home: const Scaffold(body: ThemePicker()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forest'), findsOneWidget);
    await tester.tap(find.text('Forest'));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ThemePicker)),
    );
    expect(container.read(appThemeIdProvider), AppThemeId.forest);
  });
}
