import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:digital_vision_board/main.dart';

/// Pumps the real [DigitalVisionBoardApp] with mocked dependencies.
///
/// Call this in the first line of every integration test that needs the
/// full app widget tree.
Future<void> pumpAppWithMocks(WidgetTester tester) async {
  // Prevent network calls for fonts in CI / offline test runs.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Clear all persisted state so each test starts fresh.
  SharedPreferences.setMockInitialValues({});

  await tester.pumpWidget(const DigitalVisionBoardApp());

  // Settle initial animations without using pumpAndSettle
  // (the app has repeating pulse animations that never fully settle).
  await tester.pump(const Duration(seconds: 2));
}

/// Waits a short time to let async loaders & animations advance.
Future<void> settle(WidgetTester tester, {Duration? duration}) async {
  await tester.pump(duration ?? const Duration(milliseconds: 500));
}

/// Taps the first widget matching [finder] and waits for any triggered
/// animations / async work to advance.
Future<void> tapAndSettle(
  WidgetTester tester,
  Finder finder, {
  Duration? duration,
}) async {
  await tester.tap(finder);
  await settle(tester, duration: duration);
}

/// Dismisses any open dialog by tapping the first 'Cancel' button or the
/// barrier outside the dialog.
Future<void> dismissDialog(WidgetTester tester) async {
  final cancelBtn = find.text('Cancel');
  if (cancelBtn.evaluate().isNotEmpty) {
    await tester.tap(cancelBtn.first);
    await settle(tester);
  } else {
    // Tap outside the dialog to dismiss it
    await tester.tapAt(const Offset(20, 20));
    await settle(tester);
  }
}

/// Navigates to the bottom nav item with [label].
Future<void> navigateToTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  if (tab.evaluate().isNotEmpty) {
    await tester.tap(tab.first);
    await settle(tester, duration: const Duration(seconds: 1));
  }
}
