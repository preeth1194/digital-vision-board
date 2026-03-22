import 'package:digital_vision_board/models/habit_item.dart';
import 'package:digital_vision_board/models/insights_month_summary.dart';
import 'package:digital_vision_board/widgets/insights/insights_stat_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
  });

  group('InsightsStatGrid', () {
    testWidgets('renders all four stat labels', (tester) async {
      const habit = HabitItem(id: 'h1', name: 'Run', frequency: 'Daily');
      final summary = InsightsMonthSummary.forMonth(2026, 3);
      await tester.pumpWidget(_wrap(
        InsightsStatGrid(habit: habit, summary: summary),
      ));
      expect(find.text('Seeds this month'), findsOneWidget);
      expect(find.text('Current streak'), findsOneWidget);
      expect(find.text('Best run'), findsOneWidget);
      expect(find.text('Time invested'), findsOneWidget);
    });

    testWidgets('shows — for time when timeBound is null', (tester) async {
      const habit = HabitItem(id: 'h1', name: 'Run', frequency: 'Daily');
      final summary = InsightsMonthSummary.forMonth(2026, 3);
      await tester.pumpWidget(_wrap(
        InsightsStatGrid(habit: habit, summary: summary),
      ));
      expect(find.text('—'), findsOneWidget);
    });
  });
}
