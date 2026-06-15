import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:water_meter_app/app.dart';
import 'package:water_meter_app/core/auth/mock_auth_service.dart';
import 'package:water_meter_app/core/providers/app_providers.dart';
import 'support/test_user_profile_notifier.dart';

void main() {
  testWidgets('App shows sign-in when not authenticated', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(MockAuthService()),
          authInitProvider.overrideWith((ref) async {}),
          userProfileProvider.overrideWith(() => TestUserProfileNotifier(null)),
        ],
        child: const WaterMeterApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
