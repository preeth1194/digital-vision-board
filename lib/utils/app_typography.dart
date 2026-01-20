import 'package:flutter/material.dart';

/// Standardized typography system for the app.
/// All text styles use theme-aware colors and consistent sizing.
class AppTypography {
  AppTypography._();

  /// Heading 1 - 24sp, bold
  /// Used for main screen titles
  static TextStyle heading1(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: colorScheme.onSurface,
    );
  }

  /// Heading 2 - 20sp, semi-bold
  /// Used for section titles
  static TextStyle heading2(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    );
  }

  /// Heading 3 - 18sp, semi-bold
  /// Used for subsection titles and card titles
  static TextStyle heading3(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface,
    );
  }

  /// Body - 16sp, regular
  /// Used for main content text
  static TextStyle body(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurface,
    );
  }

  /// Body Small - 14sp, regular
  /// Used for secondary content
  static TextStyle bodySmall(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurface,
    );
  }

  /// Caption - 12sp, regular
  /// Used for captions, hints, and metadata
  static TextStyle caption(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurfaceVariant,
    );
  }

  /// Button - 16sp, medium
  /// Used for button text
  static TextStyle button(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: colorScheme.onPrimary,
    );
  }

  /// Secondary text - uses onSurfaceVariant color
  /// Used for less prominent text
  static TextStyle secondary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colorScheme.onSurfaceVariant,
    );
  }

  /// Error text - uses error color
  static TextStyle error(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: colorScheme.error,
    );
  }
}
