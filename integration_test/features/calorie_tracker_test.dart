// E2E: Calorie Tracker — full food log flow
//
// Run individually with:
//   flutter test integration_test/features/calorie_tracker_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import '../helpers/app_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Calorie Tracker', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    testWidgets('Dashboard shows CalorieTrackerCard with "+ Food" button',
        (tester) async {
      await pumpAppWithMocks(tester);
      // Dashboard should be the default landing screen
      expect(find.text('+ Food'), findsOneWidget);
    });

    testWidgets('Tapping +100 increments calorie count', (tester) async {
      await pumpAppWithMocks(tester);
      // Initial state: "2,000 kcal remaining" or similar
      await tester.tap(find.text('+100'));
      await settle(tester, duration: const Duration(milliseconds: 800));
      // After tapping +100, the display should show 100 kcal
      expect(find.text('100'), findsWidgets);
    });

    testWidgets('Tapping +200 increments calorie count', (tester) async {
      await pumpAppWithMocks(tester);
      await tester.tap(find.text('+200'));
      await settle(tester, duration: const Duration(milliseconds: 800));
      expect(find.text('200'), findsWidgets);
    });

    testWidgets('Tapping "+ Food" opens "Log Food" bottom sheet',
        (tester) async {
      await pumpAppWithMocks(tester);
      await tapAndSettle(tester, find.text('+ Food'));
      expect(find.text('Log Food'), findsOneWidget);
    });

    testWidgets('Log Food sheet has Food name, Qty, Calories fields',
        (tester) async {
      await pumpAppWithMocks(tester);
      await tapAndSettle(tester, find.text('+ Food'));
      expect(find.text('Food name'), findsOneWidget);
      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
    });

    testWidgets(
        'Typing food name shows autocomplete suggestions from seed recipes',
        (tester) async {
      await pumpAppWithMocks(tester);
      await tapAndSettle(tester, find.text('+ Food'));
      await tester.enterText(
          find.widgetWithText(TextField, 'Food name'), 'ch');
      await settle(tester, duration: const Duration(milliseconds: 400));
      // Seed data has "High-Protein Chicken & Rice Bowl"
      expect(find.textContaining('Chicken'), findsWidgets);
    });

    testWidgets(
        'Tapping recipe suggestion auto-fills food name and calories',
        (tester) async {
      await pumpAppWithMocks(tester);
      await tapAndSettle(tester, find.text('+ Food'));
      await tester.enterText(
          find.widgetWithText(TextField, 'Food name'), 'ch');
      await settle(tester, duration: const Duration(milliseconds: 400));

      // Tap the first suggestion
      final suggestion = find.textContaining('Chicken').first;
      await tester.tap(suggestion);
      await settle(tester);

      // Calories field should be auto-filled (non-empty)
      final calField = tester
          .widget<TextField>(find.widgetWithText(TextField, 'Calories'));
      expect(calField.controller?.text.isNotEmpty ?? false, isTrue);
    });

    testWidgets('"Add macro breakdown" toggle expands macro fields',
        (tester) async {
      await pumpAppWithMocks(tester);
      await tapAndSettle(tester, find.text('+ Food'));
      expect(find.text('Protein'), findsNothing);
      await tester.tap(find.textContaining('macro breakdown'));
      await settle(tester);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('Fiber'), findsOneWidget);
    });

    testWidgets('"Add to Log" closes sheet and updates calorie display',
        (tester) async {
      await pumpAppWithMocks(tester);
      await tapAndSettle(tester, find.text('+ Food'));

      // Fill food name and calories
      await tester.enterText(
          find.widgetWithText(TextField, 'Food name'), 'Banana');
      await tester.enterText(
          find.widgetWithText(TextField, 'Calories'), '89');
      await settle(tester);

      await tester.tap(find.text('Add to Log'));
      await settle(tester, duration: const Duration(seconds: 1));

      // Sheet should be closed
      expect(find.text('Log Food'), findsNothing);
      // Calorie display should show 89
      expect(find.text('89'), findsWidgets);
    });

    testWidgets('Dashboard shows macro summary row after logging food with macros',
        (tester) async {
      await pumpAppWithMocks(tester);
      await tapAndSettle(tester, find.text('+ Food'));

      // Enter food with macros
      await tester.enterText(
          find.widgetWithText(TextField, 'Food name'), 'Egg');
      await tester.enterText(
          find.widgetWithText(TextField, 'Calories'), '70');

      // Toggle macros
      await tester.tap(find.textContaining('macro breakdown'));
      await settle(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Protein'), '6');
      await tester.enterText(find.widgetWithText(TextField, 'Carbs'), '1');
      await tester.enterText(find.widgetWithText(TextField, 'Fat'), '5');
      await settle(tester);

      await tester.tap(find.text('Add to Log'));
      await settle(tester, duration: const Duration(seconds: 1));

      // Macro summary P/C/F chips should appear
      expect(find.text('P'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('Reset icon shows confirm dialog; tapping Reset clears calories',
        (tester) async {
      await pumpAppWithMocks(tester);
      // Add some calories so reset icon appears
      await tester.tap(find.text('+100'));
      await settle(tester, duration: const Duration(milliseconds: 800));

      // Find and tap the refresh icon
      final refreshIcon = find.byIcon(Icons.refresh_rounded);
      expect(refreshIcon, findsOneWidget);
      await tester.tap(refreshIcon);
      await settle(tester);

      // Confirm dialog should appear
      expect(find.text('Reset Today'), findsOneWidget);
      await tester.tap(find.text('Reset'));
      await settle(tester, duration: const Duration(milliseconds: 800));

      // Calories back to 0
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('Tapping goal label opens "Daily Calorie Goal" dialog',
        (tester) async {
      await pumpAppWithMocks(tester);
      final goalFinder = find.textContaining('goal');
      expect(goalFinder, findsWidgets);
      await tester.tap(goalFinder.first);
      await settle(tester);
      expect(find.text('Daily Calorie Goal'), findsOneWidget);
      await dismissDialog(tester);
    });
  });
}
