import '../services/logical_date_service.dart';
import 'habit_item.dart';

/// Calendar month window for insights charts and share cards.
final class InsightsMonthSummary {
  final int year;
  final int month;
  final List<DateTime> days;

  InsightsMonthSummary._({
    required this.year,
    required this.month,
    required this.days,
  });

  factory InsightsMonthSummary.forMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final days = <DateTime>[];
    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      days.add(DateTime(d.year, d.month, d.day));
    }
    return InsightsMonthSummary._(year: year, month: month, days: days);
  }

  int get daysInMonth => days.length;

  /// Days in this month where [habit] is scheduled.
  static int scheduledDaysInMonth(HabitItem habit, InsightsMonthSummary summary) {
    return summary.days.where((d) => habit.isScheduledOnDate(d)).length;
  }

  /// Scheduled days in the month that were completed.
  static int completedScheduledDaysInMonth(
    HabitItem habit,
    InsightsMonthSummary summary,
  ) {
    return summary.days
        .where((d) => habit.isScheduledOnDate(d) && habit.isCompletedOnDate(d))
        .length;
  }

  static int seedsEarnedInMonth(HabitItem habit, InsightsMonthSummary summary) {
    var sum = 0;
    for (final d in summary.days) {
      final iso = LogicalDateService.toIsoDate(d);
      sum += habit.feedbackByDate[iso]?.coinsEarned ?? 0;
    }
    return sum;
  }

  /// `null` when time-bound is off — use copy fallback in UI.
  static int? estimatedMinutesInvested(
    HabitItem habit,
    InsightsMonthSummary summary,
  ) {
    final tb = habit.timeBound;
    if (tb == null || !tb.enabled) return null;
    final n = completedScheduledDaysInMonth(habit, summary);
    if (n <= 0) return null;
    return n * tb.durationMinutes;
  }

  /// Longest run of consecutive *scheduled* days completed within the month.
  static int longestCompletionRunInMonth(
    HabitItem habit,
    InsightsMonthSummary summary,
  ) {
    var best = 0;
    var current = 0;
    for (final d in summary.days) {
      if (!habit.isScheduledOnDate(d)) continue;
      if (habit.isCompletedOnDate(d)) {
        current++;
        if (current > best) best = current;
      } else {
        current = 0;
      }
    }
    return best;
  }

  /// Per day: count of habits scheduled and completed that day.
  static List<int> aggregateCompletionsPerDay(
    List<HabitItem> habits,
    InsightsMonthSummary summary,
  ) {
    return summary.days
        .map(
          (d) => habits
              .where((h) => h.isScheduledOnDate(d) && h.isCompletedOnDate(d))
              .length,
        )
        .toList();
  }

  /// Per day: 1 if [habit] completed on that day, else 0 (all month days).
  static List<int> habitCompletionSeries(
    HabitItem habit,
    InsightsMonthSummary summary,
  ) {
    return summary.days
        .map((d) => habit.isCompletedOnDate(d) ? 1 : 0)
        .toList();
  }
}
