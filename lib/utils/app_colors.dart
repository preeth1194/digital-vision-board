import 'package:flutter/material.dart';

/// Custom color palette for the Digital Vision Board app.
/// Based on the blue color palette:
/// - Darkest: #021024
/// - Dark: #052659
/// - Medium: #5483B3
/// - Light: #7DA0CA
/// - Lightest: #C1E8FF
class AppColors {
  AppColors._();

  // Primary palette colors
  static const Color darkest = Color(0xFF021024);
  static const Color dark = Color(0xFF052659);
  static const Color medium = Color(0xFF5483B3);
  static const Color light = Color(0xFF7DA0CA);
  static const Color lightest = Color(0xFFC1E8FF);

  // Additional derived colors
  static const Color backgroundDark = Color(0xFF010812);
  static const Color backgroundLight = Color(0xFFF8FCFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color onErrorDark = Color(0xFF690005);

  /// Light theme ColorScheme
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary
    primary: medium,
    onPrimary: Colors.white,
    primaryContainer: lightest,
    onPrimaryContainer: darkest,
    // Secondary
    secondary: dark,
    onSecondary: Colors.white,
    secondaryContainer: light,
    onSecondaryContainer: darkest,
    // Tertiary
    tertiary: dark,
    onTertiary: Colors.white,
    tertiaryContainer: lightest,
    onTertiaryContainer: darkest,
    // Error
    error: errorLight,
    onError: onErrorLight,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    // Surface
    surface: surfaceLight,
    onSurface: darkest,
    onSurfaceVariant: dark,
    // Outline
    outline: medium,
    outlineVariant: light,
    // Background (deprecated but still used)
    // Shadow & Scrim
    shadow: darkest,
    scrim: darkest,
    // Inverse
    inverseSurface: darkest,
    onInverseSurface: lightest,
    inversePrimary: light,
    // Surface variants
    surfaceContainerHighest: lightest,
    surfaceContainerHigh: Color(0xFFE8F4FF),
    surfaceContainer: Color(0xFFF0F8FF),
    surfaceContainerLow: Color(0xFFF5FAFF),
    surfaceContainerLowest: surfaceLight,
    surfaceDim: light,
    surfaceBright: surfaceLight,
  );

  /// Dark theme ColorScheme
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary
    primary: light,
    onPrimary: darkest,
    primaryContainer: dark,
    onPrimaryContainer: lightest,
    // Secondary
    secondary: lightest,
    onSecondary: darkest,
    secondaryContainer: dark,
    onSecondaryContainer: lightest,
    // Tertiary
    tertiary: lightest,
    onTertiary: darkest,
    tertiaryContainer: dark,
    onTertiaryContainer: lightest,
    // Error
    error: errorDark,
    onError: onErrorDark,
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    // Surface
    surface: darkest,
    onSurface: lightest,
    onSurfaceVariant: light,
    // Outline
    outline: medium,
    outlineVariant: dark,
    // Background (deprecated but still used)
    // Shadow & Scrim
    shadow: Colors.black,
    scrim: Colors.black,
    // Inverse
    inverseSurface: lightest,
    onInverseSurface: darkest,
    inversePrimary: medium,
    // Surface variants
    surfaceContainerHighest: dark,
    surfaceContainerHigh: Color(0xFF0A1E3A),
    surfaceContainer: Color(0xFF061528),
    surfaceContainerLow: Color(0xFF040F1E),
    surfaceContainerLowest: backgroundDark,
    surfaceDim: darkest,
    surfaceBright: dark,
  );
}
