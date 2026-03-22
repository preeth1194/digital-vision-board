import 'package:digital_vision_board/screens/onboarding/onboarding_first_habit_draft.dart';
import 'package:digital_vision_board/screens/onboarding/steps/step_first_habit.dart';
import 'package:digital_vision_board/screens/onboarding/steps/step_first_habit_routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StepFirstHabit: Continue disabled until name; draft updated', (
    WidgetTester tester,
  ) async {
    final draft = OnboardingFirstHabitDraft();
    var advanced = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StepFirstHabit(
            draft: draft,
            notifyParent: () {},
            onNext: () => advanced = true,
          ),
        ),
      ),
    );

    final continueBtn = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueBtn).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Stretch');
    await tester.pump();

    expect(tester.widget<FilledButton>(continueBtn).onPressed, isNotNull);

    await tester.tap(continueBtn);
    await tester.pump();

    expect(advanced, true);
    expect(draft.name, 'Stretch');
    expect(draft.habitId, isNotNull);
    expect(draft.habitId!.isNotEmpty, true);
  });

  testWidgets('StepFirstHabitRoutine: Continue without inputs advances', (
    WidgetTester tester,
  ) async {
    final draft = OnboardingFirstHabitDraft()
      ..habitId = 'test_habit_1'
      ..name = 'Stretch';

    var advanced = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StepFirstHabitRoutine(
            draft: draft,
            notifyParent: () {},
            onNext: () => advanced = true,
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();

    expect(advanced, true);
    expect(draft.actionSteps, isEmpty);
  });
}
