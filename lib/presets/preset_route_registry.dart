import 'package:flutter/material.dart';

import '../models/action_step_template.dart';
import '../screens/meal_prep/meal_prep_week_screen.dart';
import '../screens/skincare/skincare_planner_screen.dart';
import '../screens/workout/workout_preset_viewer_screen.dart';
import 'models/preset_template_config.dart';
import 'preset_template_adapter.dart';
import 'widgets/generic_preset_editor_screen.dart';

class PresetRouteRegistry {
  const PresetRouteRegistry._();

  static final List<PresetTemplateAdapter> _adapters = [
    const _SkincarePresetTemplateAdapter(),
    const _MealPrepPresetTemplateAdapter(),
    const _WorkoutPresetTemplateAdapter(),
    const _GenericPresetTemplateAdapter(),
  ];

  static PresetTemplateAdapter adapterForTemplate(ActionStepTemplate template) {
    for (final adapter in _adapters) {
      if (adapter.supportsTemplate(template)) return adapter;
    }
    return const _GenericPresetTemplateAdapter();
  }
}

class _SkincarePresetTemplateAdapter extends PresetTemplateAdapter {
  const _SkincarePresetTemplateAdapter();

  @override
  PresetTemplateConfig buildConfig(ActionStepTemplate template) {
    return const PresetTemplateConfig(
      id: 'skincare',
      title: 'Skincare Planner',
      icon: Icons.auto_awesome_outlined,
      sections: [
        PresetTemplateSection.routinePreview,
        PresetTemplateSection.weeklyPlanner,
        PresetTemplateSection.products,
      ],
      supportsAmPmSplit: true,
      allowEdit: true,
      allowCreateHabits: true,
      createButtonLabel: 'Create habits',
    );
  }

  @override
  Future<ActionStepTemplate?> openEditor(
    BuildContext context,
    ActionStepTemplate template,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SkincarePlannerScreen(initialTemplate: template),
      ),
    );
    return null;
  }

  @override
  bool supportsTemplate(ActionStepTemplate template) {
    return template.category == ActionTemplateCategory.skincare;
  }
}

class _MealPrepPresetTemplateAdapter extends PresetTemplateAdapter {
  const _MealPrepPresetTemplateAdapter();

  @override
  PresetTemplateConfig buildConfig(ActionStepTemplate template) {
    return const PresetTemplateConfig(
      id: 'meal_prep',
      title: 'Meal Prep Planner',
      icon: Icons.calendar_month_outlined,
      sections: [
        PresetTemplateSection.routinePreview,
        PresetTemplateSection.weeklyPlanner,
        PresetTemplateSection.linkedHabits,
      ],
      supportsAmPmSplit: false,
      allowEdit: true,
      allowCreateHabits: true,
      createButtonLabel: 'Create habit',
    );
  }

  @override
  Future<ActionStepTemplate?> openEditor(
    BuildContext context,
    ActionStepTemplate template,
  ) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MealPrepWeekScreen()));
    return null;
  }

  @override
  bool supportsTemplate(ActionStepTemplate template) {
    return template.category == ActionTemplateCategory.mealPrep;
  }
}

class _WorkoutPresetTemplateAdapter extends PresetTemplateAdapter {
  const _WorkoutPresetTemplateAdapter();

  @override
  PresetTemplateConfig buildConfig(ActionStepTemplate template) {
    final level = (template.metadata['level'] as String? ?? '').isNotEmpty
        ? template.metadata['level'] as String
        : 'Workout';
    final durationWeeks = template.metadata['durationWeeks'];
    final daysPerWeek = template.metadata['daysPerWeek'];
    final subtitle = [
      if (durationWeeks != null) '$durationWeeks weeks',
      if (daysPerWeek != null) '$daysPerWeek days/week',
    ].join(' · ');
    return PresetTemplateConfig(
      id: 'workout',
      title: '$level Plan${subtitle.isNotEmpty ? ' — $subtitle' : ''}',
      icon: Icons.fitness_center_outlined,
      sections: [PresetTemplateSection.routinePreview],
      supportsAmPmSplit: false,
      allowEdit: false,
      allowCreateHabits: false,
      createButtonLabel: 'View Plan',
    );
  }

  @override
  Future<ActionStepTemplate?> openEditor(
    BuildContext context,
    ActionStepTemplate template,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutPresetViewerScreen(template: template),
      ),
    );
    return null;
  }

  @override
  bool supportsTemplate(ActionStepTemplate template) {
    return template.category == ActionTemplateCategory.workout;
  }
}

class _GenericPresetTemplateAdapter extends PresetTemplateAdapter {
  const _GenericPresetTemplateAdapter();

  @override
  PresetTemplateConfig buildConfig(ActionStepTemplate template) {
    return const PresetTemplateConfig(
      id: 'generic',
      title: 'Preset Planner',
      icon: Icons.grid_view_rounded,
      sections: [PresetTemplateSection.routinePreview],
      supportsAmPmSplit: false,
      allowEdit: true,
      allowCreateHabits: true,
      createButtonLabel: 'Create habit',
    );
  }

  @override
  Future<ActionStepTemplate?> openEditor(
    BuildContext context,
    ActionStepTemplate template,
  ) async {
    return Navigator.of(context).push<ActionStepTemplate>(
      MaterialPageRoute<ActionStepTemplate>(
        builder: (_) => GenericPresetEditorScreen(template: template),
      ),
    );
  }

  @override
  bool supportsTemplate(ActionStepTemplate template) => true;
}
