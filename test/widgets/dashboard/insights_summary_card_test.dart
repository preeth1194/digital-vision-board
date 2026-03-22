import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:digital_vision_board/widgets/dashboard/insights_summary_card.dart';

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  testWidgets('loading state: shows LinearProgressIndicator, no old heading row', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InsightsSummaryCard())),
    );
    // No pump() — widget is in loading state (_loaded == false)
    expect(find.byType(LinearProgressIndicator), findsWidgets);
    // Old card had a heading Row with 'Insights' text — new loading state has no such text
    expect(find.text('Insights'), findsNothing);
  });

  testWidgets('loading state: does NOT show insights_rounded icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: InsightsSummaryCard())),
    );
    expect(find.byIcon(Icons.insights_rounded), findsNothing);
  });
}
