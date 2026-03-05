import 'package:flutter/material.dart';

import '../../models/habit_action_step.dart';
import '../../models/habit_item.dart';
import '../../models/skincare_planner.dart';
import '../../services/habit_storage_service.dart';

typedef SkincareHabitParts = ({
  List<HabitActionStep> steps,
  List<int> weekdays,
});

class SkincarePresetCompiler {
  const SkincarePresetCompiler._();

  static int currentMonthlyTrackerIndex({DateTime? now}) {
    final today = now ?? DateTime.now();
    final weekOfMonth = ((today.day - 1) ~/ 7) + 1;
    if (weekOfMonth == 1) return 0;
    if (weekOfMonth == 2) return 1;
    if (weekOfMonth == 3) return 2;
    return 0;
  }

  static SkincareWeeklyPlan weeklyPlanForCurrentTrackerWeek(
    SkincarePlanner planner, {
    DateTime? now,
  }) {
    final idx = currentMonthlyTrackerIndex(now: now);
    final tracker = planner.monthlyTracker[idx];
    for (final plan in planner.weeklyPlans) {
      if (plan.id == tracker.weeklyPlanId) return plan;
    }
    for (final plan in planner.weeklyPlans) {
      if (plan.id == planner.selectedWeeklyPlanId) return plan;
    }
    return planner.weeklyPlans.first;
  }

  static String uniqueHabitName(String base, Set<String> takenLower) {
    var candidate = base.trim().isEmpty ? 'Skincare Habit' : base.trim();
    if (!takenLower.contains(candidate.toLowerCase())) {
      takenLower.add(candidate.toLowerCase());
      return candidate;
    }
    int n = 2;
    while (takenLower.contains('$candidate ($n)'.toLowerCase())) {
      n++;
    }
    final next = '$candidate ($n)';
    takenLower.add(next.toLowerCase());
    return next;
  }

  static SkincareRoutineSet? routineSetById(
    SkincarePlanner planner,
    String? id, {
    required bool morning,
  }) {
    if (id == null || id.trim().isEmpty) return null;
    final sets = morning
        ? planner.morningRoutineSets
        : planner.eveningRoutineSets;
    for (final set in sets) {
      if (set.id == id) return set;
    }
    return null;
  }

  static int weekdayFromDayKey(String dayKey) {
    return HabitActionStep.weekdayFromPlannerKey(dayKey) ?? DateTime.sunday;
  }

  static SkincareHabitParts buildHabitPartsFromPlanner({
    required SkincarePlanner planner,
    required SkincareWeeklyPlan weeklyPlan,
    required bool morning,
  }) {
    final weekdays = <int>{};
    final uniqueTitles = <String>{};
    final steps = <HabitActionStep>[];
    for (final day in SkincarePlanner.weekDays) {
      final dayPlan =
          weeklyPlan.weeklyPlanByDay[day] ?? SkincareWeeklyDayPlan(dayKey: day);
      final sourceId = morning
          ? dayPlan.morningSourceId
          : dayPlan.eveningSourceId;
      final set = routineSetById(planner, sourceId, morning: morning);
      if (set == null) continue;
      weekdays.add(weekdayFromDayKey(day));
      for (final row in set.rows) {
        final title = row.task.trim().isNotEmpty
            ? row.task.trim()
            : row.productUsed.trim();
        if (title.isEmpty) continue;
        if (uniqueTitles.contains(title.toLowerCase())) continue;
        uniqueTitles.add(title.toLowerCase());
        steps.add(
          HabitActionStep(
            id: '${morning ? 'am' : 'pm'}-$day-${DateTime.now().microsecondsSinceEpoch}-${steps.length}',
            title: title,
            stepLabel: '${steps.length + 1}',
            productName: title,
            notes: row.note,
            plannerDay: morning ? 'am_daily' : 'pm_daily',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: steps.length,
          ),
        );
      }
    }
    return (steps: steps, weekdays: weekdays.toList()..sort());
  }

  static Future<List<String>> createHabitsFromPlanner({
    required SkincarePlanner planner,
    required String baseTitle,
    required bool morningEnabled,
    required bool eveningEnabled,
    String habitCategory = 'Health',
  }) async {
    final weeklyPlan = weeklyPlanForCurrentTrackerWeek(planner);
    final morning = morningEnabled
        ? buildHabitPartsFromPlanner(
            planner: planner,
            weeklyPlan: weeklyPlan,
            morning: true,
          )
        : (steps: <HabitActionStep>[], weekdays: <int>[]);
    final evening = eveningEnabled
        ? buildHabitPartsFromPlanner(
            planner: planner,
            weeklyPlan: weeklyPlan,
            morning: false,
          )
        : (steps: <HabitActionStep>[], weekdays: <int>[]);

    final existing = await HabitStorageService.loadAll();
    final taken = existing.map((h) => h.name.toLowerCase()).toSet();
    final morningName = uniqueHabitName('$baseTitle Morning', taken);
    final eveningName = uniqueHabitName('$baseTitle Evening', taken);
    final createdNames = <String>[];

    if (morning.steps.isNotEmpty) {
      await HabitStorageService.addHabit(
        HabitItem(
          id: 'skincare-am-${DateTime.now().microsecondsSinceEpoch}',
          name: morningName,
          category: habitCategory,
          frequency: 'Weekly',
          weeklyDays: morning.weekdays.isEmpty
              ? const [1, 2, 3, 4, 5, 6, 7]
              : morning.weekdays,
          actionSteps: morning.steps,
          completedDates: const [],
        ),
      );
      createdNames.add(morningName);
    }

    if (evening.steps.isNotEmpty) {
      await HabitStorageService.addHabit(
        HabitItem(
          id: 'skincare-pm-${DateTime.now().microsecondsSinceEpoch}',
          name: eveningName,
          category: habitCategory,
          frequency: 'Weekly',
          weeklyDays: evening.weekdays.isEmpty
              ? const [1, 2, 3, 4, 5, 6, 7]
              : evening.weekdays,
          actionSteps: evening.steps,
          completedDates: const [],
        ),
      );
      createdNames.add(eveningName);
    }

    return createdNames;
  }
}
