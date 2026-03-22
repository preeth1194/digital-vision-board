import 'package:flutter/material.dart';

import '../../models/habit_action_step.dart';

/// Mutable state collected across the three first-habit onboarding pages.
class OnboardingFirstHabitDraft {
  String? habitId;
  String name = '';
  String? category;

  /// CBT "if" line — maps to [CbtEnhancements.predictedObstacle].
  String copingIf = '';

  /// CBT "then" line — maps to [CbtEnhancements.ifThenPlan].
  String copingThen = '';

  List<HabitActionStep> actionSteps = [];
  bool reminderEnabled = false;
  TimeOfDay? reminderTime;

  /// Habit stacking (optional), collected on the routine step.
  bool stackAnchorEnabled = false;
  String stackAnchorText = '';
  /// When user picks an existing saved habit from suggestions.
  String? stackAfterHabitId;
  String stackRelationship = 'Before';

  final List<String> motivationPaths = [];
}
