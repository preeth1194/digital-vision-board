import '../models/action_step_template.dart';
import '../models/habit_item.dart';
import '../models/skincare_planner.dart';
import '../presets/services/skincare_preset_compiler.dart';
import '../services/action_templates_service.dart';
import '../services/dv_auth_service.dart';
import '../services/habit_storage_service.dart';
import '../services/skincare_planner_storage_service.dart';

/// Result of [PlannerGuideDataService.load].
class PlannerGuideLoadResult {
  final List<HabitItem> habits;
  final List<ActionStepTemplate> templates;
  final String? error;
  final int liveSkincareStepCount;
  final String? liveSkincarePresetTitle;

  const PlannerGuideLoadResult({
    required this.habits,
    required this.templates,
    this.error,
    required this.liveSkincareStepCount,
    this.liveSkincarePresetTitle,
  });
}

/// Handles all async data loading for [PlannerGuideScreen].
///
/// Accepts [fallbackTemplates] and [habitCategoryForTemplate] as callbacks so
/// the large static data in the screen stays co-located with its UI context
/// while the async I/O logic lives here.
class PlannerGuideDataService {
  PlannerGuideDataService._();

  static Future<PlannerGuideLoadResult> load({
    required List<ActionStepTemplate> Function() fallbackTemplates,
    required String Function(ActionStepTemplate) habitCategoryForTemplate,
  }) async {
    final habits = await HabitStorageService.loadAll();

    final planner = await SkincarePlannerStorageService.loadOrDefault();
    final liveWeeklyPlan =
        SkincarePresetCompiler.weeklyPlanForCurrentTrackerWeek(planner);
    final liveMorning = SkincarePresetCompiler.buildHabitPartsFromPlanner(
      planner: planner,
      weeklyPlan: liveWeeklyPlan,
      morning: true,
    );
    final liveEvening = SkincarePresetCompiler.buildHabitPartsFromPlanner(
      planner: planner,
      weeklyPlan: liveWeeklyPlan,
      morning: false,
    );
    final liveSkincareStepCount =
        liveMorning.steps.length + liveEvening.steps.length;
    final liveSkincarePresetTitle = planner.title.trim().isEmpty
        ? null
        : planner.title.trim();

    try {
      final token = await DvAuthService.getDvToken();
      List<ActionStepTemplate> templates;
      if (token == null) {
        templates = fallbackTemplates();
      } else {
        templates = await ActionTemplatesService.listApproved(dvToken: token);
        if (templates.isEmpty) {
          templates = fallbackTemplates();
        } else {
          // Fill in fallback templates for any UI category not covered by cloud
          final fallbacks = fallbackTemplates();
          final cloudCategories =
              templates.map(habitCategoryForTemplate).toSet();
          for (final fb in fallbacks) {
            if (!cloudCategories.contains(habitCategoryForTemplate(fb))) {
              templates = [...templates, fb];
            }
          }
        }
      }
      return PlannerGuideLoadResult(
        habits: habits,
        templates: templates,
        liveSkincareStepCount: liveSkincareStepCount,
        liveSkincarePresetTitle: liveSkincarePresetTitle,
      );
    } catch (e) {
      return PlannerGuideLoadResult(
        habits: habits,
        templates: fallbackTemplates(),
        error: 'Could not load cloud templates. Showing defaults.',
        liveSkincareStepCount: liveSkincareStepCount,
        liveSkincarePresetTitle: liveSkincarePresetTitle,
      );
    }
  }
}
