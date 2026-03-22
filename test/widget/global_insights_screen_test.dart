import 'package:digital_vision_board/models/vision_components.dart';
import 'package:digital_vision_board/screens/global_insights_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GlobalInsightsScreen shows empty state with no habits', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlobalInsightsScreen(components: []),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('No activity to analyze yet'), findsOneWidget);
  });
}
