import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_vision_board/widgets/dashboard/water_intake_card.dart';

void main() {
  testWidgets('control buttons are 36px tall', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: WaterIntakeCard())),
    );
    await tester.pump();

    final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    final buttonBoxes = sizedBoxes.where((b) => b.height == 36.0).toList();
    expect(buttonBoxes.length, greaterThanOrEqualTo(2));
  });
}
