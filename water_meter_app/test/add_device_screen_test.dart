import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/providers/app_providers.dart';
import 'package:water_meter_app/core/storage/preferences_storage.dart';
import 'package:water_meter_app/features/devices/add_device_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({PreferencesStorage? prefsOverride}) {
    return ProviderScope(
      overrides: [
        if (prefsOverride != null)
          preferencesStorageProvider.overrideWith(
            (ref) async => prefsOverride,
          ),
        deviceOnboardingCompleteProvider.overrideWith(
          (ref) async => prefsOverride?.deviceOnboardingComplete ?? false,
        ),
      ],
      child: MaterialApp(
        home: const AddDeviceScreen(),
      ),
    );
  }

  testWidgets('renders standard device type names', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Smart Plug'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
    expect(find.text('Choose a device type to get started'), findsOneWidget);
  });

  testWidgets('tap shows not supported yet snackbar', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switch'));
    await tester.pump();

    expect(find.text('Switch is not supported yet'), findsOneWidget);
  });

  testWidgets('skip marks device onboarding complete', (tester) async {
    final prefs = await PreferencesStorage.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStorageProvider.overrideWith((ref) async => prefs),
          deviceOnboardingCompleteProvider.overrideWith(
            (ref) async => prefs.deviceOnboardingComplete,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const Scaffold(body: Text('Home')),
              ),
              GoRoute(
                path: '/onboarding/devices',
                builder: (context, state) => const AddDeviceScreen(),
              ),
            ],
            initialLocation: '/onboarding/devices',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(prefs.deviceOnboardingComplete, isTrue);
    expect(find.text('Home'), findsOneWidget);
  });
}
