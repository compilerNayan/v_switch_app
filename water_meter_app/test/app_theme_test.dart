import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:water_meter_app/core/storage/preferences_storage.dart';
import 'package:water_meter_app/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppTheme', () {
    test('themeFor builds ThemeData for every theme id', () {
      for (final id in AppThemeId.values) {
        final theme = AppTheme.themeFor(id);
        expect(theme.useMaterial3, isTrue);
        expect(
          theme.colorScheme.brightness,
          id.isDark ? Brightness.dark : Brightness.light,
        );
      }
    });

    test('ocean is the default light theme', () {
      final theme = AppTheme.themeFor(AppThemeId.ocean);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFF0277BD));
    });

    test('midnight is dark', () {
      final theme = AppTheme.themeFor(AppThemeId.midnight);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });
  });

  group('AppThemeId storage', () {
    test('fromStorage defaults to ocean', () {
      expect(AppThemeId.fromStorage(null), AppThemeId.ocean);
      expect(AppThemeId.fromStorage('unknown'), AppThemeId.ocean);
    });

    test('round-trips through preferences', () async {
      final prefs = await PreferencesStorage.create();
      await prefs.setAppThemeId(AppThemeId.indigo);
      expect(prefs.appThemeId, AppThemeId.indigo);
      expect(AppThemeId.fromStorage('indigo'), AppThemeId.indigo);
    });
  });
}
