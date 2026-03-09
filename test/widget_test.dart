import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:digital_vision_board/main.dart';
import 'package:digital_vision_board/widgets/dashboard/calorie_tracker_card.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _setupMocks() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
}

void main() {
  // ── App smoke test ─────────────────────────────────────────────────────────

  testWidgets('App boots and shows vision board', (WidgetTester tester) async {
    await _setupMocks();
    await tester.pumpWidget(const DigitalVisionBoardApp());
    // Use pump() instead of pumpAndSettle() because the widget tree contains
    // repeating animations (e.g. pulse in bottom nav bar) and periodic timers
    // that prevent settling.
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(Scaffold), findsWidgets);
  });

  // ── CalorieTrackerCard widget tests ───────────────────────────────────────

  group('CalorieTrackerCard', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<void> pumpCard(WidgetTester tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalorieTrackerCard(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('renders "+ Food" button', (tester) async {
      await pumpCard(tester);
      expect(find.text('+ Food'), findsOneWidget);
    });

    testWidgets('renders +100 button', (tester) async {
      await pumpCard(tester);
      expect(find.text('+100'), findsOneWidget);
    });

    testWidgets('renders +200 button', (tester) async {
      await pumpCard(tester);
      expect(find.text('+200'), findsOneWidget);
    });

    testWidgets('renders +500 button', (tester) async {
      await pumpCard(tester);
      expect(find.text('+500'), findsOneWidget);
    });

    testWidgets('tapping goal chip opens "Daily Calorie Goal" dialog',
        (tester) async {
      await pumpCard(tester);
      final goalFinder = find.textContaining('goal');
      expect(goalFinder, findsWidgets);
      await tester.tap(goalFinder.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Daily Calorie Goal'), findsOneWidget);
    });

    testWidgets('tapping "+ Food" opens "Log Food" bottom sheet',
        (tester) async {
      await pumpCard(tester);
      await tester.tap(find.text('+ Food'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Log Food'), findsOneWidget);
    });

    testWidgets('bottom sheet shows Food name, Qty, Calories fields',
        (tester) async {
      await pumpCard(tester);
      await tester.tap(find.text('+ Food'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Food name'), findsOneWidget);
      expect(find.text('Qty'), findsOneWidget);
      expect(find.text('Calories'), findsOneWidget);
    });

    testWidgets('bottom sheet has "Add macro breakdown" toggle', (tester) async {
      await pumpCard(tester);
      await tester.tap(find.text('+ Food'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('macro breakdown'), findsOneWidget);
    });

    testWidgets('macro fields appear after tapping "Add macro breakdown"',
        (tester) async {
      await pumpCard(tester);
      await tester.tap(find.text('+ Food'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Protein'), findsNothing);
      await tester.tap(find.textContaining('macro breakdown'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
    });

    testWidgets('bottom sheet shows "Add to Log" button', (tester) async {
      await pumpCard(tester);
      await tester.tap(find.text('+ Food'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Add to Log'), findsOneWidget);
    });

    testWidgets('typing 2+ chars in Food name shows recipe suggestions',
        (tester) async {
      await pumpCard(tester);
      await tester.tap(find.text('+ Food'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.enterText(find.widgetWithText(TextField, 'Food name'), 'ch');
      await tester.pump(const Duration(milliseconds: 300));
      // Seed data includes "High-Protein Chicken & Rice Bowl" and others
      expect(find.textContaining('Chicken'), findsWidgets);
    });
  });
}
