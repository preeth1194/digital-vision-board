import 'package:flutter/material.dart';

/// Centralized theme configuration for the Digital Vision Board app.
/// 
/// This file contains all theme-related constants and configurations,
/// making it easy to customize colors, fonts, and other styling properties.
class AppTheme {
  AppTheme._();

  // ============================================================================
  // COLOR CONFIGURATION
  // ============================================================================

  /// Primary brand color - used for main actions, buttons, and highlights
  static const Color primaryColor = Color(0xFF6B46C1); // Deep Purple

  /// Secondary color - used for secondary actions and accents
  static const Color secondaryColor = Color(0xFF9333EA); // Purple

  /// Tertiary color - used for additional accents
  static const Color tertiaryColor = Color(0xFFA855F7); // Light Purple

  /// Success color - used for positive actions and confirmations
  static const Color successColor = Color(0xFF10B981); // Green

  /// Error color - used for errors and destructive actions
  static const Color errorColor = Color(0xFFEF4444); // Red

  /// Warning color - used for warnings
  static const Color warningColor = Color(0xFFF59E0B); // Amber

  /// Info color - used for informational messages
  static const Color infoColor = Color(0xFF3B82F6); // Blue

  // ============================================================================
  // LIGHT THEME COLORS
  // ============================================================================

  /// Light theme background colors
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF9FAFB);
  static const Color lightSurfaceVariant = Color(0xFFF3F4F6);

  /// Light theme text colors
  static const Color lightOnBackground = Color(0xFF111827);
  static const Color lightOnSurface = Color(0xFF1F2937);
  static const Color lightOnSurfaceVariant = Color(0xFF6B7280);

  // ============================================================================
  // DARK THEME COLORS
  // ============================================================================

  /// Dark theme background colors
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);

  /// Dark theme text colors
  static const Color darkOnBackground = Color(0xFFF1F5F9);
  static const Color darkOnSurface = Color(0xFFE2E8F0);
  static const Color darkOnSurfaceVariant = Color(0xFFCBD5E1);

  // ============================================================================
  // FONT CONFIGURATION
  // ============================================================================

  /// Primary font family - used throughout the app
  static const String primaryFontFamily = 'Roboto';

  /// Secondary font family - used for headings and special text
  static const String secondaryFontFamily = 'Roboto';

  /// Monospace font family - used for code or technical content
  static const String monospaceFontFamily = 'RobotoMono';

  // ============================================================================
  // TYPOGRAPHY CONFIGURATION
  // ============================================================================

  /// Display large text style
  static const TextStyle displayLarge = TextStyle(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
  );

  /// Display medium text style
  static const TextStyle displayMedium = TextStyle(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
  );

  /// Display small text style
  static const TextStyle displaySmall = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
  );

  /// Headline large text style
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.25,
  );

  /// Headline medium text style
  static const TextStyle headlineMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.29,
  );

  /// Headline small text style
  static const TextStyle headlineSmall = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.33,
  );

  /// Title large text style
  static const TextStyle titleLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.27,
  );

  /// Title medium text style
  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.5,
  );

  /// Title small text style
  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  /// Body large text style
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.5,
  );

  /// Body medium text style
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
  );

  /// Body small text style
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
  );

  /// Label large text style
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
  );

  /// Label medium text style
  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
  );

  /// Label small text style
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
  );

  // ============================================================================
  // SPACING CONFIGURATION
  // ============================================================================

  /// Base spacing unit (4dp)
  static const double spacingUnit = 4.0;

  /// Spacing values
  static const double spacingXS = spacingUnit * 1; // 4
  static const double spacingS = spacingUnit * 2; // 8
  static const double spacingM = spacingUnit * 4; // 16
  static const double spacingL = spacingUnit * 6; // 24
  static const double spacingXL = spacingUnit * 8; // 32
  static const double spacingXXL = spacingUnit * 12; // 48

  // ============================================================================
  // BORDER RADIUS CONFIGURATION
  // ============================================================================

  /// Border radius values
  static const double radiusXS = 4.0;
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 9999.0;

  // ============================================================================
  // ELEVATION CONFIGURATION
  // ============================================================================

  /// Elevation values for Material Design
  static const double elevationNone = 0.0;
  static const double elevationLow = 1.0;
  static const double elevationMedium = 2.0;
  static const double elevationHigh = 4.0;
  static const double elevationVeryHigh = 8.0;

  // ============================================================================
  // THEME DATA BUILDERS
  // ============================================================================

  /// Builds the light theme
  static ThemeData buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: tertiaryColor,
      error: errorColor,
      surface: lightSurface,
      onSurface: lightOnSurface,
      background: lightBackground,
      onBackground: lightOnBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: primaryFontFamily,
      scaffoldBackgroundColor: lightBackground,
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: elevationNone,
        centerTitle: true,
        titleTextStyle: titleLarge.copyWith(
          color: colorScheme.onSurface,
        ),
      ),

      // Card theme
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: elevationMedium,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingS,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: displayLarge.copyWith(color: colorScheme.onBackground),
        displayMedium: displayMedium.copyWith(color: colorScheme.onBackground),
        displaySmall: displaySmall.copyWith(color: colorScheme.onBackground),
        headlineLarge: headlineLarge.copyWith(color: colorScheme.onBackground),
        headlineMedium: headlineMedium.copyWith(color: colorScheme.onBackground),
        headlineSmall: headlineSmall.copyWith(color: colorScheme.onBackground),
        titleLarge: titleLarge.copyWith(color: colorScheme.onSurface),
        titleMedium: titleMedium.copyWith(color: colorScheme.onSurface),
        titleSmall: titleSmall.copyWith(color: colorScheme.onSurface),
        bodyLarge: bodyLarge.copyWith(color: colorScheme.onSurface),
        bodyMedium: bodyMedium.copyWith(color: colorScheme.onSurface),
        bodySmall: bodySmall.copyWith(color: colorScheme.onSurfaceVariant),
        labelLarge: labelLarge.copyWith(color: colorScheme.onSurface),
        labelMedium: labelMedium.copyWith(color: colorScheme.onSurface),
        labelSmall: labelSmall.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  /// Builds the dark theme
  static ThemeData buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: tertiaryColor,
      error: errorColor,
      surface: darkSurface,
      onSurface: darkOnSurface,
      background: darkBackground,
      onBackground: darkOnBackground,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: primaryFontFamily,
      scaffoldBackgroundColor: darkBackground,
      
      // AppBar theme
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: elevationNone,
        centerTitle: true,
        titleTextStyle: titleLarge.copyWith(
          color: colorScheme.onSurface,
        ),
      ),

      // Card theme
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),

      // Button themes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: elevationMedium,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusM),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingM,
            vertical: spacingS,
          ),
        ),
      ),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),

      // Text theme
      textTheme: TextTheme(
        displayLarge: displayLarge.copyWith(color: colorScheme.onBackground),
        displayMedium: displayMedium.copyWith(color: colorScheme.onBackground),
        displaySmall: displaySmall.copyWith(color: colorScheme.onBackground),
        headlineLarge: headlineLarge.copyWith(color: colorScheme.onBackground),
        headlineMedium: headlineMedium.copyWith(color: colorScheme.onBackground),
        headlineSmall: headlineSmall.copyWith(color: colorScheme.onBackground),
        titleLarge: titleLarge.copyWith(color: colorScheme.onSurface),
        titleMedium: titleMedium.copyWith(color: colorScheme.onSurface),
        titleSmall: titleSmall.copyWith(color: colorScheme.onSurface),
        bodyLarge: bodyLarge.copyWith(color: colorScheme.onSurface),
        bodyMedium: bodyMedium.copyWith(color: colorScheme.onSurface),
        bodySmall: bodySmall.copyWith(color: colorScheme.onSurfaceVariant),
        labelLarge: labelLarge.copyWith(color: colorScheme.onSurface),
        labelMedium: labelMedium.copyWith(color: colorScheme.onSurface),
        labelSmall: labelSmall.copyWith(color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
