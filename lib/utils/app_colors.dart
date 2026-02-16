import 'package:flutter/material.dart';

/// Custom color palette for the Digital Vision Board app.
/// "Organic Clarity" theme — white and light green aesthetic.
///
/// Named palette:
/// - Darkest: #1A2E1A (deep forest-black)
/// - Dark:    #2D5A3D (forestGreen)
/// - Medium:  #4A7C59 (mossGreen)
/// - Light:   #A8D5BA (mintGreen)
/// - Lightest: #D4EBD4 (pale green tint)
class AppColors {
  AppColors._();

  // ── Primary palette (abstract names kept for backward-compat) ──
  static const Color darkest = Color(0xFF1A2E1A);
  static const Color dark = Color(0xFF2D5A3D);
  static const Color medium = Color(0xFF4A7C59);
  static const Color light = Color(0xFFA8D5BA);
  static const Color lightest = Color(0xFFD4EBD4);

  // ── Semantic named colors ──
  static const Color offWhite = Color(0xFFF8F9F4);
  static const Color mintGreen = Color(0xFFA8D5BA);
  static const Color sageGreen = Color(0xFF8FBC8F);
  static const Color mossGreen = Color(0xFF4A7C59);
  static const Color forestGreen = Color(0xFF2D5A3D);
  static const Color gold = Color(0xFFD4A843);
  static const Color cream = Color(0xFFFAFAF5);

  // ── Derived / utility colors ──
  static const Color backgroundDark = Color(0xFF0F1A0F);
  static const Color backgroundLight = Color(0xFFF8F9F4);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color errorLight = Color(0xFFBA1A1A);
  static const Color errorDark = Color(0xFFFFB4AB);
  static const Color onErrorLight = Color(0xFFFFFFFF);
  static const Color onErrorDark = Color(0xFF690005);

  /// Light theme ColorScheme
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    // Primary
    primary: mossGreen,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE8F5E9),
    onPrimaryContainer: darkest,
    // Secondary
    secondary: forestGreen,
    onSecondary: Colors.white,
    secondaryContainer: mintGreen,
    onSecondaryContainer: darkest,
    // Tertiary (gold accent — coins, sliders)
    tertiary: gold,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFF3D6),
    onTertiaryContainer: Color(0xFF3E2E00),
    // Error
    error: errorLight,
    onError: onErrorLight,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    // Surface
    surface: surfaceLight,
    onSurface: darkest,
    onSurfaceVariant: forestGreen,
    // Outline
    outline: mossGreen,
    outlineVariant: mintGreen,
    // Shadow & Scrim
    shadow: darkest,
    scrim: darkest,
    // Inverse
    inverseSurface: darkest,
    onInverseSurface: lightest,
    inversePrimary: mintGreen,
    // Surface variants
    surfaceContainerHighest: lightest,
    surfaceContainerHigh: Color(0xFFE8F5E9),
    surfaceContainer: Color(0xFFF0F7F0),
    surfaceContainerLow: Color(0xFFF5FAF5),
    surfaceContainerLowest: surfaceLight,
    surfaceDim: mintGreen,
    surfaceBright: surfaceLight,
  );

  /// Dark theme ColorScheme
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    // Primary
    primary: mintGreen,
    onPrimary: darkest,
    primaryContainer: forestGreen,
    onPrimaryContainer: lightest,
    // Secondary
    secondary: lightest,
    onSecondary: darkest,
    secondaryContainer: forestGreen,
    onSecondaryContainer: lightest,
    // Tertiary (gold accent — coins, sliders)
    tertiary: Color(0xFFE8C46A),
    onTertiary: Color(0xFF3E2E00),
    tertiaryContainer: Color(0xFF5C4400),
    onTertiaryContainer: Color(0xFFFFF3D6),
    // Error
    error: errorDark,
    onError: onErrorDark,
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    // Surface
    surface: darkest,
    onSurface: Color(0xFFE8F5E9),
    onSurfaceVariant: mintGreen,
    // Outline
    outline: sageGreen,
    outlineVariant: forestGreen,
    // Shadow & Scrim
    shadow: Colors.black,
    scrim: Colors.black,
    // Inverse
    inverseSurface: lightest,
    onInverseSurface: darkest,
    inversePrimary: mossGreen,
    // Surface variants
    surfaceContainerHighest: forestGreen,
    surfaceContainerHigh: Color(0xFF1E3A1E),
    surfaceContainer: Color(0xFF152B15),
    surfaceContainerLow: Color(0xFF122412),
    surfaceContainerLowest: backgroundDark,
    surfaceDim: darkest,
    surfaceBright: forestGreen,
  );
}
