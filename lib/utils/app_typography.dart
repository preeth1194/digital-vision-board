import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Standardized typography system for the app.
/// All text styles use Inter font, theme-aware colors, and consistent sizing.
/// Headings use the theme's onSurface (dark warm brown / cream) for readability.
class AppTypography {
  AppTypography._();

  /// Resolve the heading color from the theme's onSurface.
  static Color _headingColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Heading 1 - 24sp, bold
  /// Used for main screen titles
  static TextStyle heading1(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: _headingColor(context),
      letterSpacing: -0.5,
    );
  }

  /// Heading 2 - 20sp, semi-bold
  /// Used for section titles
  static TextStyle heading2(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: _headingColor(context),
      letterSpacing: -0.3,
    );
  }

  /// Heading 3 - 18sp, semi-bold
  /// Used for subsection titles and card titles
  static TextStyle heading3(BuildContext context) {
    return GoogleFonts.inter(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: _headingColor(context),
      letterSpacing: -0.2,
    );
  }

  /// Body - 16sp, regular
  /// Used for main content text
  static TextStyle body(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurface,
      height: 1.5,
    );
  }

  /// Body Small - 14sp, regular
  /// Used for secondary content
  static TextStyle bodySmall(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurface,
      height: 1.5,
    );
  }

  /// Caption - 12sp, regular
  /// Used for captions, hints, and metadata
  static TextStyle caption(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurfaceVariant,
      height: 1.4,
    );
  }

  /// Button - 16sp, medium
  /// Used for button text
  static TextStyle button(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: colorScheme.onPrimary,
      letterSpacing: 0.1,
    );
  }

  /// Secondary text - uses onSurfaceVariant color
  /// Used for less prominent text
  static TextStyle secondary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurfaceVariant,
      height: 1.5,
    );
  }

  /// Error text - uses error color
  static TextStyle error(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colorScheme.error,
      height: 1.5,
    );
  }
}
