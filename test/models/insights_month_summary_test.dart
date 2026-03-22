import 'package:digital_vision_board/models/habit_item.dart';
import 'package:digital_vision_board/models/insights_month_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InsightsMonthSummary', () {
    test('forMonth has correct day count', () {
      final s = InsightsMonthSummary.forMonth(2026, 2);
      expect(s.daysInMonth, 28);
      final s2 = InsightsMonthSummary.forMonth(2024, 2);
      expect(s2.daysInMonth, 29);
    });

    test('habitCompletionSeries matches completions', () {
      final habit = HabitItem(
        id: '1',
        name: 'Run',
        category: 'Health',
        frequency: 'Daily',
        weeklyDays: const [],
        completedDates: [
          DateTime(2026, 3, 1),
          DateTime(2026, 3, 3),
        ],
      );
      final summary = InsightsMonthSummary.forMonth(2026, 3);
      final series = InsightsMonthSummary.habitCompletionSeries(habit, summary);
      expect(series.length, 31);
      expect(series[0], 1); // Mar 1
      expect(series[1], 0); // Mar 2
      expect(series[2], 1); // Mar 3
    });

    test('aggregateCompletionsPerDay sums habits', () {
      final h1 = HabitItem(
        id: '1',
        name: 'A',
        category: 'Health',
        frequency: 'Daily',
        weeklyDays: const [],
        completedDates: [DateTime(2026, 3, 5)],
      );
      final h2 = HabitItem(
        id: '2',
        name: 'B',
        category: 'Health',
        frequency: 'Daily',
        weeklyDays: const [],
        completedDates: [DateTime(2026, 3, 5)],
      );
      final summary = InsightsMonthSummary.forMonth(2026, 3);
      final agg = InsightsMonthSummary.aggregateCompletionsPerDay(
        [h1, h2],
        summary,
      );
      expect(agg[4], 2);
    });
  });
}
