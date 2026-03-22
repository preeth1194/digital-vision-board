import 'package:digital_vision_board/screens/onboarding/steps/step_profile_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('StepProfileSetup: Continue disabled until name entered', (
    WidgetTester tester,
  ) async {
    var advanced = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StepProfileSetup(onNext: () => advanced = true),
        ),
      ),
    );

    final continueBtn = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueBtn).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pump();

    expect(tester.widget<FilledButton>(continueBtn).onPressed, isNotNull);

    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    expect(advanced, true);
  });
}
