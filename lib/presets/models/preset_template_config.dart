import 'package:flutter/material.dart';

enum PresetTemplateSection {
  routinePreview,
  weeklyPlanner,
  products,
  notes,
  linkedHabits,
}

class PresetTemplateConfig {
  final String id;
  final String title;
  final IconData icon;
  final List<PresetTemplateSection> sections;
  final bool supportsAmPmSplit;
  final bool allowEdit;
  final bool allowCreateHabits;
  final String createButtonLabel;

  const PresetTemplateConfig({
    required this.id,
    required this.title,
    required this.icon,
    required this.sections,
    this.supportsAmPmSplit = false,
    this.allowEdit = true,
    this.allowCreateHabits = true,
    this.createButtonLabel = 'Create habits',
  });
}
