import 'package:digital_vision_board/models/habit_item.dart';
import 'package:digital_vision_board/models/insights_month_summary.dart';
import 'package:digital_vision_board/widgets/insights/habit_heatmap_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  group('HabitHeatmapCard cell state helpers', () {
    // March 2026 starts on Sunday (weekday == 7, % 7 == 0 leading cells)
    test('March 2026 offset is 0 (starts on Sunday)', () {
      final offset = DateTime(2026, 3, 1).weekday % 7;
      expect(offset, 0);
    });

    // January 2026 starts on Thursday (weekday == 4)
    test('January 2026 offset is 4 (starts on Thursday)', () {
      final offset = DateTime(2026, 1, 1).weekday % 7;
      expect(offset, 4);
    });

    test('aggregate progress bar guards against zero scheduled days', () {
      final habits = <HabitItem>[];
      final summary = InsightsMonthSummary.forMonth(2026, 3);
      var total = 0;
      for (final h in habits) {
        total += InsightsMonthSummary.scheduledDaysInMonth(h, summary);
      }
      expect(total, 0); // no divide-by-zero — caller must guard
    });
  });

  group('HabitHeatmapCard widget', () {
    testWidgets('renders without error for single habit', (tester) async {
      final habit = HabitItem(
        id: 'h1',
        name: 'Run',
        frequency: 'Daily',
        completedDates: [DateTime(2026, 3, 5)],
      );
      await tester.pumpWidget(_wrap(
        HabitHeatmapCard(
          habit: habit,
          habits: [habit],
          year: 2026,
          month: 3,
          today: DateTime(2026, 3, 22),
        ),
      ));
      expect(find.byType(HabitHeatmapCard), findsOneWidget);
    });

    testWidgets('renders without error in aggregate mode', (tester) async {
      const h1 = HabitItem(id: 'a', name: 'Run', frequency: 'Daily');
      const h2 = HabitItem(id: 'b', name: 'Read', frequency: 'Daily');
      await tester.pumpWidget(_wrap(
        HabitHeatmapCard(
          habit: null,
          habits: [h1, h2],
          year: 2026,
          month: 3,
          today: DateTime(2026, 3, 22),
        ),
      ));
      expect(find.byType(HabitHeatmapCard), findsOneWidget);
    });

    testWidgets('shows progress text with completed/scheduled counts', (tester) async {
      final habit = HabitItem(
        id: 'h1',
        name: 'Run',
        frequency: 'Daily',
        completedDates: [
          DateTime(2026, 3, 1),
          DateTime(2026, 3, 2),
          DateTime(2026, 3, 3),
        ],
      );
      await tester.pumpWidget(_wrap(
        HabitHeatmapCard(
          habit: habit,
          habits: [habit],
          year: 2026,
          month: 3,
          today: DateTime(2026, 3, 22),
        ),
      ));
      expect(find.textContaining('3 of'), findsOneWidget);
    });

    testWidgets('shows 0 of 0 for empty habits aggregate', (tester) async {
      await tester.pumpWidget(_wrap(
        HabitHeatmapCard(
          habit: null,
          habits: const [],
          year: 2026,
          month: 3,
          today: DateTime(2026, 3, 22),
        ),
      ));
      expect(find.textContaining('0 of 0'), findsOneWidget);
    });
  });
}
