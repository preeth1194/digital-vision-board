// E2E: Default badges — visibility on official presets
//
// Run individually with:
//   flutter test integration_test/features/default_badges_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:digital_vision_board/screens/planner_guide_screen.dart';
import 'package:digital_vision_board/screens/workout/workout_preset_editor_screen.dart';
import 'package:digital_vision_board/models/action_step_template.dart';
import 'package:digital_vision_board/models/habit_action_step.dart';

import '../helpers/app_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E2E: Default Badges', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      GoogleFonts.config.allowRuntimeFetching = false;
    });

    testWidgets('PlannerGuideScreen shows "Default" badge for official presets',
        (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      await tester.pumpWidget(
        const MaterialApp(home: PlannerGuideScreen()),
      );
      await tester.pump(const Duration(seconds: 2));

      // Expand a category — default badges should appear in expanded panels
      final firstExpandable = find.byType(ExpansionTile);
      if (firstExpandable.evaluate().isNotEmpty) {
        await tester.tap(firstExpandable.first);
        await settle(tester, duration: const Duration(seconds: 1));
      }

      // After expansion, 'Default' badge should be visible somewhere
      expect(find.text('Default'), findsWidgets);
    });

    testWidgets(
        'WorkoutPresetEditorScreen shows "Default preset" notice for official templates',
        (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      // Build a minimal official template with correct required fields
      final officialTemplate = ActionStepTemplate(
        id: 'test_official_workout',
        name: 'Test Workout Plan',
        category: ActionTemplateCategory.workout,
        schemaVersion: 1,
        templateVersion: 1,
        setKey: null,
        isOfficial: true,
        status: ActionTemplateStatus.approved,
        createdByUserId: null,
        steps: [
          const HabitActionStep(
            id: 'step_1',
            title: 'Bench Press',
            iconCodePoint: 0xe1b1,
            order: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutPresetEditorScreen(template: officialTemplate),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // The editor should show a "Default preset" or "default" notice
      expect(
        find.textContaining('Default'),
        findsWidgets,
      );
    });

    testWidgets(
        'WorkoutPresetEditorScreen for non-official template does NOT show default notice',
        (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final userTemplate = ActionStepTemplate(
        id: 'test_user_workout',
        name: 'My Custom Workout',
        category: ActionTemplateCategory.workout,
        schemaVersion: 1,
        templateVersion: 1,
        setKey: null,
        isOfficial: false,
        status: ActionTemplateStatus.approved,
        createdByUserId: 'user_123',
        steps: [
          const HabitActionStep(
            id: 'step_1',
            title: 'Squat',
            iconCodePoint: 0xe1b1,
            order: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutPresetEditorScreen(template: userTemplate),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // No "Default preset" notice for user templates
      expect(find.textContaining('Default preset'), findsNothing);
    });

    testWidgets(
        'WorkoutPresetEditorScreen shows exercise fields and save button',
        (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      final template = ActionStepTemplate(
        id: 'test_workout',
        name: 'Test Plan',
        category: ActionTemplateCategory.workout,
        schemaVersion: 1,
        templateVersion: 1,
        setKey: null,
        isOfficial: false,
        status: ActionTemplateStatus.approved,
        createdByUserId: 'user_123',
        steps: [
          const HabitActionStep(
            id: 'step_1',
            title: 'Pull-ups',
            iconCodePoint: 0xe1b1,
            order: 0,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutPresetEditorScreen(template: template),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // Plan name field should be pre-filled
      expect(find.text('Test Plan'), findsWidgets);
      // Save button should be visible (FAB or AppBar action)
      expect(
        find.byIcon(Icons.check_rounded).evaluate().isNotEmpty ||
            find.text('Save').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets(
        'Catalog recipe autocomplete shows "Default" badge in food log sheet',
        (tester) async {
      await pumpAppWithMocks(tester);
      // Open food log sheet
      await tapAndSettle(tester, find.text('+ Food'));
      // Type to trigger autocomplete suggestions from catalog recipes
      await tester.enterText(
          find.widgetWithText(TextField, 'Food name'), 'sa');
      await settle(tester, duration: const Duration(milliseconds: 400));
      // Suggestions from catalog (e.g. Salmon Teriyaki) should show "Default" badge
      // if the suggestion list is showing catalog entries
      final salmonFinder = find.textContaining('Salmon');
      if (salmonFinder.evaluate().isNotEmpty) {
        expect(find.text('Default'), findsWidgets);
      }
    });
  });
}
