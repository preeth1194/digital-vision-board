import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../rituals/add_habit_modal.dart';

// Re-export HabitCreateRequest for backward compatibility (now defined in habit_item.dart)
export '../../models/habit_item.dart' show HabitCreateRequest;

/// Shows the Add Habit flow. Delegates to [showAddHabitModal] (unified scrollable page).
Future<HabitCreateRequest?> showAddHabitDialog(
  BuildContext context, {
  String? initialName,
  String? suggestedGoalDeadline,
  required List<HabitItem> existingHabits,
}) async {
  return showAddHabitModal(
    context,
    existingHabits: existingHabits,
    initialHabit: null,
      initialName: initialName,
      suggestedGoalDeadline: suggestedGoalDeadline,
  );
}

/// Shows the Edit Habit flow. Delegates to [showAddHabitModal] (unified scrollable page).
Future<HabitCreateRequest?> showEditHabitDialog(
  BuildContext context, {
  required HabitItem habit,
  String? suggestedGoalDeadline,
  required List<HabitItem> existingHabits,
}) async {
  return showAddHabitModal(
    context,
    existingHabits: existingHabits,
      initialHabit: habit,
      suggestedGoalDeadline: suggestedGoalDeadline,
  );
}
