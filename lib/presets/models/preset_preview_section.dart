import 'package:flutter/material.dart';

import '../../models/habit_action_step.dart';

class PresetPreviewSection {
  final String title;
  final IconData icon;
  final List<HabitActionStep> steps;

  const PresetPreviewSection({
    required this.title,
    required this.icon,
    required this.steps,
  });
}
