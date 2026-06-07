import 'package:flutter/material.dart';

enum AppThemeId {
  ocean,
  slate,
  forest,
  indigo,
  midnight;

  String get label {
    switch (this) {
      case AppThemeId.ocean:
        return 'Ocean';
      case AppThemeId.slate:
        return 'Slate';
      case AppThemeId.forest:
        return 'Forest';
      case AppThemeId.indigo:
        return 'Indigo';
      case AppThemeId.midnight:
        return 'Midnight';
    }
  }

  String get description {
    switch (this) {
      case AppThemeId.ocean:
        return 'Blue and teal water-utility style';
      case AppThemeId.slate:
        return 'Cool gray-blue enterprise look';
      case AppThemeId.forest:
        return 'Deep green sustainability palette';
      case AppThemeId.indigo:
        return 'Modern indigo SaaS dashboard';
      case AppThemeId.midnight:
        return 'Dark navy professional theme';
    }
  }

  bool get isDark => this == AppThemeId.midnight;

  ({Color primary, Color secondary, Color surface}) get previewColors {
    switch (this) {
      case AppThemeId.ocean:
        return (
          primary: const Color(0xFF0277BD),
          secondary: const Color(0xFF00ACC1),
          surface: const Color(0xFFF5FAFD),
        );
      case AppThemeId.slate:
        return (
          primary: const Color(0xFF455A64),
          secondary: const Color(0xFF78909C),
          surface: const Color(0xFFF4F6F8),
        );
      case AppThemeId.forest:
        return (
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF558B2F),
          surface: const Color(0xFFF3F8F4),
        );
      case AppThemeId.indigo:
        return (
          primary: const Color(0xFF3949AB),
          secondary: const Color(0xFF7E57C2),
          surface: const Color(0xFFF5F4FA),
        );
      case AppThemeId.midnight:
        return (
          primary: const Color(0xFF5C6BC0),
          secondary: const Color(0xFF26A69A),
          surface: const Color(0xFF1A1F2E),
        );
    }
  }

  static AppThemeId fromStorage(String? value) {
    switch (value) {
      case 'slate':
        return AppThemeId.slate;
      case 'forest':
        return AppThemeId.forest;
      case 'indigo':
        return AppThemeId.indigo;
      case 'midnight':
        return AppThemeId.midnight;
      default:
        return AppThemeId.ocean;
    }
  }

  String toStorage() => name;
}

class AppTheme {
  AppTheme._();

  static ThemeData themeFor(AppThemeId id) {
    final preview = id.previewColors;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: preview.primary,
      primary: preview.primary,
      secondary: preview.secondary,
      surface: preview.surface,
      brightness: id.isDark ? Brightness.dark : Brightness.light,
    );

    return _buildThemeData(colorScheme);
  }

  /// Kept for backwards compatibility in tests/docs.
  static ThemeData light() => themeFor(AppThemeId.ocean);

  static ThemeData _buildThemeData(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.onPrimaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
    );
  }

  static LinearGradient dashboardHeaderGradient(ColorScheme scheme) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        scheme.primary,
        scheme.secondary,
      ],
    );
  }
}
