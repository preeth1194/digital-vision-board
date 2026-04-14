import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../models/action_step_template.dart';
import '../models/habit_action_step.dart';
import '../models/habit_item.dart';
import '../models/meal_prep_week.dart';
import '../models/recipe.dart';
import '../models/skincare_planner.dart';
import '../presets/models/preset_preview_section.dart';
import '../presets/models/preset_template_config.dart';
import '../presets/preset_route_registry.dart';
import '../presets/services/skincare_preset_compiler.dart';
import '../presets/widgets/preset_template_screen.dart';
import '../screens/presets/preset_shop_screen.dart';
import '../services/habit_storage_service.dart';
import '../services/planner_guide_data_service.dart';
import '../services/meal_prep_storage_service.dart';
import '../services/preset_habit_creation_service.dart';
import '../services/recipe_storage_service.dart';
import '../services/skincare_planner_storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_typography.dart';
import '../widgets/rituals/add_habit_modal.dart';

class PlannerGuideScreen extends StatefulWidget {
  final ValueNotifier<int>? dataVersion;
  final VoidCallback? onOpenChallengePreset;

  const PlannerGuideScreen({
    super.key,
    this.dataVersion,
    this.onOpenChallengePreset,
  });

  @override
  State<PlannerGuideScreen> createState() => _PlannerGuideScreenState();
}

class _PlannerGuideScreenState extends State<PlannerGuideScreen> {
  bool _loading = true;
  String? _error;
  List<ActionStepTemplate> _templates = const [];
  List<HabitItem> _existingHabits = const [];
  String _categorySearchQuery = '';
  int? _liveSkincareGuideStepCount;
  String? _liveSkincarePresetTitle;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final result = await PlannerGuideDataService.load(
      fallbackTemplates: _fallbackTemplates,
      habitCategoryForTemplate: _habitCategoryForTemplate,
    );
    if (!mounted) return;
    setState(() {
      _existingHabits = result.habits;
      _templates = result.templates;
      _liveSkincareGuideStepCount = result.liveSkincareStepCount;
      _liveSkincarePresetTitle = result.liveSkincarePresetTitle;
      _loading = false;
      _error = result.error;
    });
  }

  String _guideSummaryTextForCategory(
    String category,
    ActionStepTemplate? guide,
  ) {
    if (category == _challengeGuideCategory) {
      return 'Unlock this challenge with 20 coins.';
    }
    if (guide == null) return 'Try again after refresh.';
    if (guide.category == ActionTemplateCategory.skincare &&
        _liveSkincareGuideStepCount != null) {
      return '${_liveSkincareGuideStepCount!} action steps';
    }
    return '${guide.steps.length} action steps';
  }

  String _guideTitleTextForCategory(
    String category,
    ActionStepTemplate? guide,
  ) {
    if (category == _challengeGuideCategory) return '75 Hard';
    if (guide == null) return 'No preset available';
    if (guide.category == ActionTemplateCategory.skincare) {
      final live = (_liveSkincarePresetTitle ?? '').trim();
      if (live.isNotEmpty) return live;
    }
    return guide.name;
  }

  List<ActionStepTemplate> _fallbackTemplates() {
    ActionStepTemplate t({
      required String id,
      required String name,
      required ActionTemplateCategory category,
      required String habitCategory,
      List<String> steps = const [],
      List<HabitActionStep>? structuredSteps,
      required String setKey,
      Map<String, dynamic> metadata = const {},
      int schemaVersion = 1,
    }) {
      final resolvedSteps =
          structuredSteps ??
          [
            for (int i = 0; i < steps.length; i++)
              HabitActionStep(
                id: '$id-step-$i',
                title: steps[i],
                iconCodePoint: Icons.check_circle_outline.codePoint,
                order: i,
              ),
          ];
      return ActionStepTemplate(
        id: id,
        name: name,
        category: category,
        schemaVersion: schemaVersion,
        templateVersion: 1,
        setKey: setKey,
        isOfficial: true,
        status: ActionTemplateStatus.approved,
        createdByUserId: null,
        steps: resolvedSteps,
        metadata: {'habitCategory': habitCategory, ...metadata},
      );
    }

    return [
      t(
        id: 'default_set_beginner_skincare',
        name: 'Beginner AM/PM Skincare',
        category: ActionTemplateCategory.skincare,
        habitCategory: 'Health',
        setKey: 'default_set_beginner',
        structuredSteps: [
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-0',
            title: 'Cleanser',
            stepLabel: '1',
            productType: 'Cleanser',
            productName: 'Cleanser',
            notes: 'AM',
            plannerDay: 'am_daily',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 0,
          ),
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-1',
            title: 'Toner',
            stepLabel: '2',
            productType: 'Toner',
            productName: 'Toner',
            notes: 'AM',
            plannerDay: 'am_daily',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 1,
          ),
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-2',
            title: 'Serum',
            stepLabel: '3',
            productType: 'Serum',
            productName: 'Serum',
            notes: 'AM',
            plannerDay: 'am_daily',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 2,
          ),
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-3',
            title: 'Moisturizer',
            stepLabel: '4',
            productType: 'Moisturizer',
            productName: 'Moisturizer',
            notes: 'AM',
            plannerDay: 'am_daily',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 3,
          ),
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-4',
            title: 'Sunscreen (SPF 30+)',
            stepLabel: '5',
            productType: 'Sunscreen',
            productName: 'Sunscreen (SPF 30+)',
            notes: 'AM',
            plannerDay: 'am_daily',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 4,
          ),
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-5',
            title: 'Exfoliation',
            stepLabel: 'Monday',
            productType: 'Exfoliation',
            productName: 'Exfoliation',
            notes: '1-2x a week',
            plannerDay: 'pm_mon',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 5,
          ),
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-6',
            title: 'Cleansing',
            stepLabel: 'Tuesday',
            productType: 'Cleansing',
            productName: 'Cleansing',
            notes: 'Sheet mask / Overnight gel',
            plannerDay: 'pm_tue',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 6,
          ),
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-7',
            title: 'Hydrating Mask',
            stepLabel: 'Thursday',
            productType: 'Hydrating Mask',
            productName: 'Hydrating Mask',
            notes: 'Great for oily skin',
            plannerDay: 'pm_thu',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 7,
          ),
          HabitActionStep(
            id: 'default_set_beginner_skincare-step-8',
            title: 'Clay Mask / Detox',
            stepLabel: 'Friday',
            productType: 'Clay Mask / Detox',
            productName: 'Clay Mask / Detox',
            notes: 'Great for oily skin',
            plannerDay: 'pm_fri',
            iconCodePoint: Icons.check_circle_outline.codePoint,
            order: 8,
          ),
        ],
        metadata: {
          'supportsAmPmSplit': true,
          'templateLayout': 'skincare_weekly_planner',
          'amDefaultTimeMinutes': 420,
          'pmDefaultTimeMinutes': 1260,
        },
      ),
      t(
        id: 'default_set_structured_skincare',
        name: 'Structured Concern-Based Skincare',
        category: ActionTemplateCategory.skincare,
        habitCategory: 'Health',
        setKey: 'default_set_structured',
        steps: [
          'Cleanser',
          'Exfoliate (optional)',
          'Treatment serum',
          'Moisturizer',
          'SPF',
        ],
      ),
      t(
        id: 'default_set_beginner_workout',
        name: 'Start from Scratch – 6 Week Full Body',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Fitness',
        setKey: 'default_set_beginner',
        schemaVersion: 2,
        metadata: {
          'goal': 'Build Muscle & Strength',
          'level': 'Beginner',
          'durationWeeks': 6,
          'daysPerWeek': 4,
          'schedule': 'Mon / Tue / Thu / Fri',
          'split': 'Full Body – Workout A + B alternating',
          'timePerSession': '45–60 min',
          'equipment': [
            'Barbell',
            'Dumbbell',
            'Cable Machine',
            'Bench',
            'Machine',
          ],
          'note':
              'Two alternating full-body workouts. Use a 2-second tempo (up and down) on all reps. Warm-up sets required on marked exercises.',
        },
        structuredSteps: [
          // Workout A – Mon & Thu
          HabitActionStep(
            id: 'w-a1',
            title: 'Barbell Bench Press',
            iconCodePoint: 58728,
            order: 0,
            plannerDay: 'Workout A – Mon & Thu',
            stepLabel: '2 × 8–10',
            productType: 'Chest',
            productName: 'Barbell',
            notes: 'Warm-up set required. 2 sec up, 2 sec down.',
          ),
          HabitActionStep(
            id: 'w-a2',
            title: 'Incline Dumbbell Press',
            iconCodePoint: 58728,
            order: 1,
            plannerDay: 'Workout A – Mon & Thu',
            stepLabel: '2 × 10',
            productType: 'Chest',
            productName: 'Dumbbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'w-a3',
            title: 'Bent-Over Barbell Row',
            iconCodePoint: 58728,
            order: 2,
            plannerDay: 'Workout A – Mon & Thu',
            stepLabel: '2 × 8–10',
            productType: 'Back',
            productName: 'Barbell',
            notes: 'Keep back flat and neutral throughout',
          ),
          HabitActionStep(
            id: 'w-a4',
            title: 'Lat Pulldown',
            iconCodePoint: 58728,
            order: 3,
            plannerDay: 'Workout A – Mon & Thu',
            stepLabel: '2 × 10',
            productType: 'Back',
            productName: 'Cable Machine',
            notes: '',
          ),
          HabitActionStep(
            id: 'w-a5',
            title: 'Barbell Overhead Press',
            iconCodePoint: 58728,
            order: 4,
            plannerDay: 'Workout A – Mon & Thu',
            stepLabel: '2 × 8–10',
            productType: 'Shoulders',
            productName: 'Barbell',
            notes: 'Press in a straight line overhead',
          ),
          HabitActionStep(
            id: 'w-a6',
            title: 'Dumbbell Curl',
            iconCodePoint: 58728,
            order: 5,
            plannerDay: 'Workout A – Mon & Thu',
            stepLabel: '2 × 10',
            productType: 'Biceps',
            productName: 'Dumbbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'w-a7',
            title: 'Tricep Rope Pushdown',
            iconCodePoint: 58728,
            order: 6,
            plannerDay: 'Workout A – Mon & Thu',
            stepLabel: '2 × 10',
            productType: 'Triceps',
            productName: 'Cable Machine',
            notes: '',
          ),
          // Workout B – Tue & Fri
          HabitActionStep(
            id: 'w-b1',
            title: 'Barbell Back Squat',
            iconCodePoint: 58728,
            order: 7,
            plannerDay: 'Workout B – Tue & Fri',
            stepLabel: '2 × 10–12',
            productType: 'Legs',
            productName: 'Barbell',
            notes: 'Warm-up set required. Sit back, keep chest up.',
          ),
          HabitActionStep(
            id: 'w-b2',
            title: 'Romanian Deadlift',
            iconCodePoint: 58728,
            order: 8,
            plannerDay: 'Workout B – Tue & Fri',
            stepLabel: '2 × 10–12',
            productType: 'Hamstrings',
            productName: 'Barbell',
            notes: 'Feel the stretch at the bottom',
          ),
          HabitActionStep(
            id: 'w-b3',
            title: 'Leg Press',
            iconCodePoint: 58728,
            order: 9,
            plannerDay: 'Workout B – Tue & Fri',
            stepLabel: '2 × 12',
            productType: 'Legs',
            productName: 'Machine',
            notes: '',
          ),
          HabitActionStep(
            id: 'w-b4',
            title: 'Leg Curl',
            iconCodePoint: 58728,
            order: 10,
            plannerDay: 'Workout B – Tue & Fri',
            stepLabel: '2 × 12',
            productType: 'Hamstrings',
            productName: 'Machine',
            notes: '',
          ),
          HabitActionStep(
            id: 'w-b5',
            title: 'Standing Calf Raise',
            iconCodePoint: 58728,
            order: 11,
            plannerDay: 'Workout B – Tue & Fri',
            stepLabel: '2 × 15',
            productType: 'Calves',
            productName: 'Machine',
            notes: '',
          ),
          HabitActionStep(
            id: 'w-b6',
            title: 'Plank',
            iconCodePoint: 58728,
            order: 12,
            plannerDay: 'Workout B – Tue & Fri',
            stepLabel: '2 × 30 sec',
            productType: 'Core',
            productName: 'Bodyweight',
            notes: '',
          ),
          HabitActionStep(
            id: 'w-b7',
            title: 'Crunches',
            iconCodePoint: 58728,
            order: 13,
            plannerDay: 'Workout B – Tue & Fri',
            stepLabel: '2 × 15–20',
            productType: 'Core',
            productName: 'Bodyweight',
            notes: '',
          ),
        ],
      ),
      t(
        id: 'default_set_structured_workout',
        name: '8-Week Mass Building Hypertrophy',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Fitness',
        setKey: 'default_set_structured',
        schemaVersion: 2,
        metadata: {
          'goal': 'Build Mass & Hypertrophy',
          'level': 'Intermediate',
          'durationWeeks': 8,
          'daysPerWeek': 4,
          'schedule': 'Mon / Tue / Thu / Fri',
          'split': 'Chest & Delts / Back / Arms / Legs',
          'timePerSession': '60–75 min',
          'equipment': ['Barbell', 'Dumbbell', 'Cable Machine', 'Machine'],
          'note':
              'Uses Rest-Pause, Drop Sets, and Slow Negatives on final sets to maximise hypertrophy stimulus.',
        },
        structuredSteps: [
          // Workout 1 – Mon
          HabitActionStep(
            id: 'h-1a',
            title: 'Incline Barbell Bench Press',
            iconCodePoint: 58728,
            order: 0,
            plannerDay: 'Workout 1 – Mon (Chest & Side Delts)',
            stepLabel: '3 × 12, 10, 12*',
            productType: 'Chest',
            productName: 'Barbell',
            notes: '*Rest-Pause Set on final set',
          ),
          HabitActionStep(
            id: 'h-1b',
            title: 'Flat Dumbbell Bench Press',
            iconCodePoint: 58728,
            order: 1,
            plannerDay: 'Workout 1 – Mon (Chest & Side Delts)',
            stepLabel: '3 × 12, 10, 15+',
            productType: 'Chest',
            productName: 'Dumbbell',
            notes: '+Drop Set on final set',
          ),
          HabitActionStep(
            id: 'h-1c',
            title: 'Cable Crossover',
            iconCodePoint: 58728,
            order: 2,
            plannerDay: 'Workout 1 – Mon (Chest & Side Delts)',
            stepLabel: '3 × 12, 12, 12^',
            productType: 'Chest',
            productName: 'Cable Machine',
            notes: '^3–5 sec negatives on final set',
          ),
          HabitActionStep(
            id: 'h-1d',
            title: 'Seated Lateral Raise',
            iconCodePoint: 58728,
            order: 3,
            plannerDay: 'Workout 1 – Mon (Chest & Side Delts)',
            stepLabel: '3 × 12',
            productType: 'Side Delts',
            productName: 'Dumbbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'h-1e',
            title: 'Cable Lateral Raise',
            iconCodePoint: 58728,
            order: 4,
            plannerDay: 'Workout 1 – Mon (Chest & Side Delts)',
            stepLabel: '3 × 12',
            productType: 'Side Delts',
            productName: 'Cable Machine',
            notes: '',
          ),
          // Workout 2 – Tue
          HabitActionStep(
            id: 'h-2a',
            title: 'Bent-Over Barbell Row',
            iconCodePoint: 58728,
            order: 5,
            plannerDay: 'Workout 2 – Tue (Back & Rear Delts)',
            stepLabel: '3 × 12, 10, 12*',
            productType: 'Back',
            productName: 'Barbell',
            notes: '*Rest-Pause Set',
          ),
          HabitActionStep(
            id: 'h-2b',
            title: 'Dumbbell Pullover',
            iconCodePoint: 58728,
            order: 6,
            plannerDay: 'Workout 2 – Tue (Back & Rear Delts)',
            stepLabel: '3 × 12, 10, 15+',
            productType: 'Back',
            productName: 'Dumbbell',
            notes: '+Drop Set',
          ),
          HabitActionStep(
            id: 'h-2c',
            title: 'Seated Cable Row',
            iconCodePoint: 58728,
            order: 7,
            plannerDay: 'Workout 2 – Tue (Back & Rear Delts)',
            stepLabel: '3 × 12, 12, 12^',
            productType: 'Back',
            productName: 'Cable Machine',
            notes: '^Slow negatives on final set',
          ),
          HabitActionStep(
            id: 'h-2d',
            title: 'Reverse Pec Deck',
            iconCodePoint: 58728,
            order: 8,
            plannerDay: 'Workout 2 – Tue (Back & Rear Delts)',
            stepLabel: '3 × 12',
            productType: 'Rear Delts',
            productName: 'Machine',
            notes: '',
          ),
          // Workout 3 – Thu
          HabitActionStep(
            id: 'h-3a',
            title: 'EZ Bar Curl',
            iconCodePoint: 58728,
            order: 9,
            plannerDay: 'Workout 3 – Thu (Arms)',
            stepLabel: '3 × 12, 10, 12*',
            productType: 'Biceps',
            productName: 'EZ Bar',
            notes: '*Rest-Pause Set',
          ),
          HabitActionStep(
            id: 'h-3b',
            title: 'Hammer Curl',
            iconCodePoint: 58728,
            order: 10,
            plannerDay: 'Workout 3 – Thu (Arms)',
            stepLabel: '3 × 12',
            productType: 'Biceps',
            productName: 'Dumbbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'h-3c',
            title: 'Skull Crushers',
            iconCodePoint: 58728,
            order: 11,
            plannerDay: 'Workout 3 – Thu (Arms)',
            stepLabel: '3 × 12, 10, 15+',
            productType: 'Triceps',
            productName: 'EZ Bar',
            notes: '+Drop Set on final set',
          ),
          HabitActionStep(
            id: 'h-3d',
            title: 'Cable Tricep Pushdown',
            iconCodePoint: 58728,
            order: 12,
            plannerDay: 'Workout 3 – Thu (Arms)',
            stepLabel: '3 × 12',
            productType: 'Triceps',
            productName: 'Cable Machine',
            notes: '',
          ),
          // Workout 4 – Fri
          HabitActionStep(
            id: 'h-4a',
            title: 'Barbell Back Squat',
            iconCodePoint: 58728,
            order: 13,
            plannerDay: 'Workout 4 – Fri (Legs)',
            stepLabel: '3 × 12, 10, 12*',
            productType: 'Quads',
            productName: 'Barbell',
            notes: '*Rest-Pause Set',
          ),
          HabitActionStep(
            id: 'h-4b',
            title: 'Romanian Deadlift',
            iconCodePoint: 58728,
            order: 14,
            plannerDay: 'Workout 4 – Fri (Legs)',
            stepLabel: '3 × 12',
            productType: 'Hamstrings',
            productName: 'Barbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'h-4c',
            title: 'Leg Extension',
            iconCodePoint: 58728,
            order: 15,
            plannerDay: 'Workout 4 – Fri (Legs)',
            stepLabel: '3 × 12, 12, 15+',
            productType: 'Quads',
            productName: 'Machine',
            notes: '+Drop Set on final set',
          ),
          HabitActionStep(
            id: 'h-4d',
            title: 'Seated Leg Curl',
            iconCodePoint: 58728,
            order: 16,
            plannerDay: 'Workout 4 – Fri (Legs)',
            stepLabel: '3 × 12',
            productType: 'Hamstrings',
            productName: 'Machine',
            notes: '',
          ),
          HabitActionStep(
            id: 'h-4e',
            title: 'Standing Calf Raise',
            iconCodePoint: 58728,
            order: 17,
            plannerDay: 'Workout 4 – Fri (Legs)',
            stepLabel: '4 × 12',
            productType: 'Calves',
            productName: 'Machine',
            notes: '',
          ),
        ],
      ),
      // ── 3: No-Equipment Home Workout ─────────────────────────────────────
      t(
        id: 'default_home_bodyweight_workout',
        name: 'No-Equipment Home HIIT – 4 Week',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Fitness',
        setKey: 'default_set_home',
        schemaVersion: 2,
        metadata: {
          'goal': 'Fat Loss & Conditioning',
          'level': 'Beginner–Intermediate',
          'durationWeeks': 4,
          'daysPerWeek': 3,
          'schedule': 'Mon / Wed / Fri',
          'split': 'Full-Body HIIT Circuits',
          'timePerSession': '30 min',
          'equipment': ['Bodyweight'],
          'note': 'Work 40 sec / Rest 20 sec per exercise. Complete 3 rounds.',
        },
        structuredSteps: [
          HabitActionStep(
            id: 'hw-1',
            title: 'Jumping Jacks',
            iconCodePoint: 58728,
            order: 0,
            plannerDay: 'Circuit A – Mon',
            stepLabel: '3 × 40 sec',
            productType: 'Cardio',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-2',
            title: 'Push-Ups',
            iconCodePoint: 58728,
            order: 1,
            plannerDay: 'Circuit A – Mon',
            stepLabel: '3 × 40 sec',
            productType: 'Chest',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec — modify on knees if needed',
          ),
          HabitActionStep(
            id: 'hw-3',
            title: 'Bodyweight Squat',
            iconCodePoint: 58728,
            order: 2,
            plannerDay: 'Circuit A – Mon',
            stepLabel: '3 × 40 sec',
            productType: 'Legs',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-4',
            title: 'Mountain Climbers',
            iconCodePoint: 58728,
            order: 3,
            plannerDay: 'Circuit A – Mon',
            stepLabel: '3 × 40 sec',
            productType: 'Core',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-5',
            title: 'Glute Bridges',
            iconCodePoint: 58728,
            order: 4,
            plannerDay: 'Circuit A – Mon',
            stepLabel: '3 × 40 sec',
            productType: 'Glutes',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec — squeeze at the top',
          ),
          HabitActionStep(
            id: 'hw-6',
            title: 'Plank Hold',
            iconCodePoint: 58728,
            order: 5,
            plannerDay: 'Circuit A – Mon',
            stepLabel: '3 × 40 sec',
            productType: 'Core',
            productName: 'Bodyweight',
            notes: 'Rest: 60 sec between rounds',
          ),
          HabitActionStep(
            id: 'hw-7',
            title: 'Burpees',
            iconCodePoint: 58728,
            order: 6,
            plannerDay: 'Circuit B – Wed',
            stepLabel: '3 × 40 sec',
            productType: 'Full Body',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-8',
            title: 'Reverse Lunges',
            iconCodePoint: 58728,
            order: 7,
            plannerDay: 'Circuit B – Wed',
            stepLabel: '3 × 40 sec',
            productType: 'Legs',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec — alternate legs',
          ),
          HabitActionStep(
            id: 'hw-9',
            title: 'Superman Hold',
            iconCodePoint: 58728,
            order: 8,
            plannerDay: 'Circuit B – Wed',
            stepLabel: '3 × 40 sec',
            productType: 'Lower Back',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-10',
            title: 'Tricep Dips (Chair)',
            iconCodePoint: 58728,
            order: 9,
            plannerDay: 'Circuit B – Wed',
            stepLabel: '3 × 40 sec',
            productType: 'Triceps',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-11',
            title: 'High Knees',
            iconCodePoint: 58728,
            order: 10,
            plannerDay: 'Circuit C – Fri',
            stepLabel: '3 × 40 sec',
            productType: 'Cardio',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-12',
            title: 'Jump Squats',
            iconCodePoint: 58728,
            order: 11,
            plannerDay: 'Circuit C – Fri',
            stepLabel: '3 × 40 sec',
            productType: 'Legs',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-13',
            title: 'Side Plank (each side)',
            iconCodePoint: 58728,
            order: 12,
            plannerDay: 'Circuit C – Fri',
            stepLabel: '3 × 20 sec',
            productType: 'Core',
            productName: 'Bodyweight',
            notes: 'Rest: 20 sec',
          ),
          HabitActionStep(
            id: 'hw-14',
            title: 'Diamond Push-Ups',
            iconCodePoint: 58728,
            order: 13,
            plannerDay: 'Circuit C – Fri',
            stepLabel: '3 × 40 sec',
            productType: 'Triceps',
            productName: 'Bodyweight',
            notes: 'Rest: 60 sec between rounds',
          ),
        ],
      ),
      // ── 4: Strength + Cardio PPL Split ─────────────────────────────────
      t(
        id: 'default_ppl_strength_workout',
        name: 'Push / Pull / Legs – 6 Day Split',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Fitness',
        setKey: 'default_set_ppl',
        schemaVersion: 2,
        metadata: {
          'goal': 'Strength & Size',
          'level': 'Intermediate',
          'durationWeeks': 10,
          'daysPerWeek': 6,
          'schedule': 'Mon–Sat',
          'split': 'Push / Pull / Legs × 2 per week',
          'timePerSession': '60–75 min',
          'equipment': ['Barbell', 'Dumbbell', 'Cable Machine', 'Machine'],
          'note':
              'Rest 2–3 min on compound lifts, 60–90 sec on isolation work.',
        },
        structuredSteps: [
          // Push – Mon
          HabitActionStep(
            id: 'ppl-p1',
            title: 'Barbell Bench Press',
            iconCodePoint: 58728,
            order: 0,
            plannerDay: 'Push – Mon',
            stepLabel: '4 × 6–8',
            productType: 'Chest',
            productName: 'Barbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-p2',
            title: 'Overhead Press',
            iconCodePoint: 58728,
            order: 1,
            plannerDay: 'Push – Mon',
            stepLabel: '3 × 8',
            productType: 'Shoulders',
            productName: 'Barbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-p3',
            title: 'Incline Dumbbell Press',
            iconCodePoint: 58728,
            order: 2,
            plannerDay: 'Push – Mon',
            stepLabel: '3 × 10–12',
            productType: 'Chest',
            productName: 'Dumbbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-p4',
            title: 'Cable Lateral Raise',
            iconCodePoint: 58728,
            order: 3,
            plannerDay: 'Push – Mon',
            stepLabel: '4 × 15',
            productType: 'Delts',
            productName: 'Cable Machine',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-p5',
            title: 'Tricep Rope Pushdown',
            iconCodePoint: 58728,
            order: 4,
            plannerDay: 'Push – Mon',
            stepLabel: '3 × 12',
            productType: 'Triceps',
            productName: 'Cable Machine',
            notes: '',
          ),
          // Pull – Tue
          HabitActionStep(
            id: 'ppl-l1',
            title: 'Weighted Pull-Ups',
            iconCodePoint: 58728,
            order: 5,
            plannerDay: 'Pull – Tue',
            stepLabel: '4 × 5–6',
            productType: 'Back',
            productName: 'Bodyweight',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-l2',
            title: 'Barbell Row',
            iconCodePoint: 58728,
            order: 6,
            plannerDay: 'Pull – Tue',
            stepLabel: '3 × 8',
            productType: 'Back',
            productName: 'Barbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-l3',
            title: 'Face Pulls',
            iconCodePoint: 58728,
            order: 7,
            plannerDay: 'Pull – Tue',
            stepLabel: '4 × 15',
            productType: 'Rear Delts',
            productName: 'Cable Machine',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-l4',
            title: 'Hammer Curl',
            iconCodePoint: 58728,
            order: 8,
            plannerDay: 'Pull – Tue',
            stepLabel: '3 × 12',
            productType: 'Biceps',
            productName: 'Dumbbell',
            notes: '',
          ),
          // Legs – Wed
          HabitActionStep(
            id: 'ppl-leg1',
            title: 'Barbell Back Squat',
            iconCodePoint: 58728,
            order: 9,
            plannerDay: 'Legs – Wed',
            stepLabel: '4 × 6',
            productType: 'Quads',
            productName: 'Barbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-leg2',
            title: 'Romanian Deadlift',
            iconCodePoint: 58728,
            order: 10,
            plannerDay: 'Legs – Wed',
            stepLabel: '3 × 10',
            productType: 'Hamstrings',
            productName: 'Barbell',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-leg3',
            title: 'Leg Press',
            iconCodePoint: 58728,
            order: 11,
            plannerDay: 'Legs – Wed',
            stepLabel: '3 × 12',
            productType: 'Quads',
            productName: 'Machine',
            notes: '',
          ),
          HabitActionStep(
            id: 'ppl-leg4',
            title: 'Seated Calf Raise',
            iconCodePoint: 58728,
            order: 12,
            plannerDay: 'Legs – Wed',
            stepLabel: '4 × 15',
            productType: 'Calves',
            productName: 'Machine',
            notes: '',
          ),
        ],
      ),
      // ── 5: 5×5 Powerlifting Strength ─────────────────────────────────────
      t(
        id: 'default_5x5_strength_workout',
        name: '5×5 Powerlifting Strength – 12 Week',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Fitness',
        setKey: 'default_set_5x5',
        schemaVersion: 2,
        metadata: {
          'goal': 'Maximum Strength',
          'level': 'Intermediate–Advanced',
          'durationWeeks': 12,
          'daysPerWeek': 3,
          'schedule': 'Mon / Wed / Fri',
          'split': 'Squat / Bench / Deadlift alternating',
          'timePerSession': '60–90 min',
          'equipment': ['Barbell', 'Bench', 'Power Rack'],
          'note':
              'Add 2.5 kg each session. Deload every 4th week at 60% of working weight.',
        },
        structuredSteps: [
          HabitActionStep(
            id: '5x5-a1',
            title: 'Barbell Back Squat',
            iconCodePoint: 58728,
            order: 0,
            plannerDay: 'Workout A – Mon & Fri',
            stepLabel: '5 × 5',
            productType: 'Legs',
            productName: 'Barbell',
            notes: 'Progress load each session',
          ),
          HabitActionStep(
            id: '5x5-a2',
            title: 'Barbell Bench Press',
            iconCodePoint: 58728,
            order: 1,
            plannerDay: 'Workout A – Mon & Fri',
            stepLabel: '5 × 5',
            productType: 'Chest',
            productName: 'Barbell',
            notes: 'Progress load each session',
          ),
          HabitActionStep(
            id: '5x5-a3',
            title: 'Barbell Row',
            iconCodePoint: 58728,
            order: 2,
            plannerDay: 'Workout A – Mon & Fri',
            stepLabel: '5 × 5',
            productType: 'Back',
            productName: 'Barbell',
            notes: 'Progress load each session',
          ),
          HabitActionStep(
            id: '5x5-b1',
            title: 'Barbell Back Squat',
            iconCodePoint: 58728,
            order: 3,
            plannerDay: 'Workout B – Wed',
            stepLabel: '5 × 5',
            productType: 'Legs',
            productName: 'Barbell',
            notes: 'Same weight as last Workout A',
          ),
          HabitActionStep(
            id: '5x5-b2',
            title: 'Overhead Press',
            iconCodePoint: 58728,
            order: 4,
            plannerDay: 'Workout B – Wed',
            stepLabel: '5 × 5',
            productType: 'Shoulders',
            productName: 'Barbell',
            notes: 'Progress load each session',
          ),
          HabitActionStep(
            id: '5x5-b3',
            title: 'Conventional Deadlift',
            iconCodePoint: 58728,
            order: 5,
            plannerDay: 'Workout B – Wed',
            stepLabel: '1 × 5',
            productType: 'Full Body',
            productName: 'Barbell',
            notes: 'Progress 5 kg each session — heaviest lift of the day',
          ),
          HabitActionStep(
            id: '5x5-acc1',
            title: 'Dips',
            iconCodePoint: 58728,
            order: 6,
            plannerDay: 'Accessory (optional)',
            stepLabel: '3 × 8–10',
            productType: 'Triceps',
            productName: 'Bodyweight',
            notes: '',
          ),
          HabitActionStep(
            id: '5x5-acc2',
            title: 'Pull-Ups',
            iconCodePoint: 58728,
            order: 7,
            plannerDay: 'Accessory (optional)',
            stepLabel: '3 × 6–8',
            productType: 'Back',
            productName: 'Bodyweight',
            notes: '',
          ),
        ],
      ),
      t(
        id: 'default_weekly_muscle_split_daypart',
        name: 'Weekly Muscle Group Split',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Fitness',
        setKey: 'default_set_muscle_split',
        schemaVersion: 2,
        metadata: {
          'goal': 'Muscle Group Focus',
          'level': 'Beginner–Intermediate',
          'durationWeeks': 8,
          'daysPerWeek': 5,
          'schedule': 'Mon–Fri (Sat/Sun Rest)',
          'split': 'Mon Chest · Tue Back · Wed Shoulders · Thu Legs · Fri Arms',
          'timePerSession': '45–60 min',
          'supportsDaypartByWeekday': true,
          'note':
              'Select Morning and/or Evening for each training day. Keep Sat/Sun as rest unless manually enabled.',
        },
        structuredSteps: [
          HabitActionStep(
            id: 'muscle-split-mon',
            title: 'Chest Session',
            iconCodePoint: 58728,
            order: 0,
            plannerDay: 'mon',
            stepLabel: '4 exercises',
            productType: 'Chest',
            productName: 'Gym',
            notes: 'Focus: upper + mid chest',
          ),
          HabitActionStep(
            id: 'muscle-split-tue',
            title: 'Back Session',
            iconCodePoint: 58728,
            order: 1,
            plannerDay: 'tue',
            stepLabel: '4 exercises',
            productType: 'Back',
            productName: 'Gym',
            notes: 'Focus: lats + upper back',
          ),
          HabitActionStep(
            id: 'muscle-split-wed',
            title: 'Shoulders Session',
            iconCodePoint: 58728,
            order: 2,
            plannerDay: 'wed',
            stepLabel: '4 exercises',
            productType: 'Shoulders',
            productName: 'Gym',
            notes: 'Focus: front + side + rear delts',
          ),
          HabitActionStep(
            id: 'muscle-split-thu',
            title: 'Legs Session',
            iconCodePoint: 58728,
            order: 3,
            plannerDay: 'thu',
            stepLabel: '5 exercises',
            productType: 'Legs',
            productName: 'Gym',
            notes: 'Focus: quads + hamstrings + calves',
          ),
          HabitActionStep(
            id: 'muscle-split-fri',
            title: 'Arms Session',
            iconCodePoint: 58728,
            order: 4,
            plannerDay: 'fri',
            stepLabel: '4 exercises',
            productType: 'Arms (Biceps & Triceps)',
            productName: 'Gym',
            notes: 'Focus: biceps + triceps',
          ),
        ],
      ),
      t(
        id: 'default_set_beginner_meal_prep',
        name: 'Beginner Weekly Meal Prep',
        category: ActionTemplateCategory.mealPrep,
        habitCategory: 'Health',
        setKey: 'default_set_beginner',
        steps: [
          'Choose 3 recipes',
          'Create grocery list',
          'Batch cook',
          'Portion & store',
        ],
      ),
      t(
        id: 'default_set_structured_meal_prep',
        name: 'Structured Batch + Leftovers Plan',
        category: ActionTemplateCategory.mealPrep,
        habitCategory: 'Health',
        setKey: 'default_set_structured',
        steps: [
          'Macro plan',
          'Shopping',
          'Batch cook proteins',
          'Prep carbs/veg',
          'Label meals',
        ],
      ),
      t(
        id: 'default_set_beginner_recipe',
        name: 'Beginner Recipe Draft',
        category: ActionTemplateCategory.recipe,
        habitCategory: 'Health',
        setKey: 'default_set_beginner',
        steps: [
          'List ingredients',
          'Prep ingredients',
          'Cook',
          'Taste and adjust',
        ],
      ),
      t(
        id: 'default_set_structured_recipe',
        name: 'Structured Recipe Workflow',
        category: ActionTemplateCategory.recipe,
        habitCategory: 'Health',
        setKey: 'default_set_structured',
        steps: [
          'Mise en place',
          'Primary cook method',
          'Secondary method',
          'Plate and review',
        ],
      ),
      t(
        id: 'default_productivity_guide',
        name: 'Daily Focus System',
        category: ActionTemplateCategory.productivity,
        habitCategory: 'Productivity',
        setKey: 'default_set_beginner',
        steps: [
          'Review yesterday\'s wins & gaps',
          'Set top 3 priorities for today',
          'Clear distractions (phone, tabs)',
          '90-min deep work block',
          'Midday check-in on priorities',
          'Process inbox to zero',
          'Plan tomorrow\'s top 3',
          'End-of-day shutdown ritual',
        ],
      ),
      t(
        id: 'default_mindfulness_guide',
        name: 'Morning Mindfulness Reset',
        category: ActionTemplateCategory.mindfulness,
        habitCategory: 'Mindfulness',
        setKey: 'default_set_beginner',
        steps: [
          '5-min breathing reset (box breathing)',
          'Body scan head to toe',
          'Set one intention for the day',
          'Write 3 gratitude points',
          '5-min evening reflection',
          'Note one thing to release',
        ],
      ),
      t(
        id: 'default_mindfulness_meditation',
        name: 'Meditation Practice',
        category: ActionTemplateCategory.mindfulness,
        habitCategory: 'Mindfulness',
        setKey: 'default_set_structured',
        steps: [
          'Settle posture, close eyes',
          '2-min breath awareness',
          '10-min open monitoring',
          'Gently return when mind wanders',
          'Journal one insight after sitting',
        ],
      ),
      t(
        id: 'default_learning_guide',
        name: 'Learning Sprint',
        category: ActionTemplateCategory.learning,
        habitCategory: 'Learning',
        setKey: 'default_set_beginner',
        steps: [
          'Choose one focused topic',
          '25-min active study (Pomodoro)',
          'Summarise in your own words',
          'Test yourself with questions',
          'Connect to something you already know',
          'Capture key insights in notes',
          'Review previous session\'s notes',
        ],
      ),
      t(
        id: 'default_relationships_guide',
        name: 'Relationship Nurturing',
        category: ActionTemplateCategory.relationships,
        habitCategory: 'Relationships',
        setKey: 'default_set_beginner',
        steps: [
          'Reach out to one person',
          'Ask a meaningful question',
          'Listen without interrupting',
          'Follow up on something they shared',
          'Express appreciation or acknowledgement',
          'Plan next touchpoint',
        ],
      ),
      t(
        id: 'default_finance_guide',
        name: 'Weekly Finance Check-in',
        category: ActionTemplateCategory.finance,
        habitCategory: 'Finance',
        setKey: 'default_set_beginner',
        steps: [
          'Review all transactions from the week',
          'Categorise any uncategorised spend',
          'Check budget vs actuals',
          'Transfer planned amount to savings',
          'Check progress toward financial goal',
          'Note one spending win and one area to cut',
        ],
      ),
      t(
        id: 'default_creativity_guide',
        name: 'Creative Flow Session',
        category: ActionTemplateCategory.creativity,
        habitCategory: 'Creativity',
        setKey: 'default_set_beginner',
        steps: [
          'Collect 3 sources of inspiration',
          'Write / sketch without judging',
          'Create a rough first draft',
          'Refine one section or element',
          'Step away and rest',
          'Return and iterate',
          'Share or publish the output',
        ],
      ),
      t(
        id: 'default_other_guide',
        name: 'General Habit Starter',
        category: ActionTemplateCategory.health,
        habitCategory: 'Health',
        setKey: 'default_set_beginner',
        steps: [
          'Define the smallest possible action',
          'Do it immediately after a trigger',
          'Track completion in the app',
          'Reflect: what made it easy or hard?',
          'Improve one thing for tomorrow',
        ],
      ),
    ];
  }

  String _habitCategoryForTemplate(ActionStepTemplate template) {
    final fromMeta = template.metadata['habitCategory'];
    if (fromMeta is String && fromMeta.trim().isNotEmpty) {
      return fromMeta.trim();
    }
    switch (template.category) {
      case ActionTemplateCategory.skincare:
      case ActionTemplateCategory.health:
      case ActionTemplateCategory.mealPrep:
      case ActionTemplateCategory.recipe:
      case ActionTemplateCategory.health:
      case ActionTemplateCategory.weeklyMealPrep:
      case ActionTemplateCategory.productivity:
      case ActionTemplateCategory.mindfulness:
      case ActionTemplateCategory.learning:
      case ActionTemplateCategory.relationships:
      case ActionTemplateCategory.finance:
      case ActionTemplateCategory.creativity:
        return 'Health';
      case ActionTemplateCategory.workout:
      case ActionTemplateCategory.fitness:
        return 'Fitness';
      case ActionTemplateCategory.challenges:
        return _challengeGuideCategory;
      case ActionTemplateCategory.weeklyMealPrep:
        return _mealPrepGuideCategory;
      case ActionTemplateCategory.productivity:
        return 'Productivity';
      case ActionTemplateCategory.mindfulness:
        return 'Mindfulness';
      case ActionTemplateCategory.learning:
        return 'Learning';
      case ActionTemplateCategory.relationships:
        return 'Relationships';
      case ActionTemplateCategory.finance:
        return 'Finance';
      case ActionTemplateCategory.creativity:
        return 'Creativity';
    }
  }

  List<ActionStepTemplate> _byHabitCategory(String category) {
    final list = _templates
        .where((t) => _habitCategoryForTemplate(t) == category)
        .toList();
    list.sort((a, b) {
      final aOfficial = a.isOfficial ? 0 : 1;
      final bOfficial = b.isOfficial ? 0 : 1;
      if (aOfficial != bOfficial) return aOfficial.compareTo(bOfficial);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  List<ActionStepTemplate> _sortedTemplatesByPriority(
    Iterable<ActionStepTemplate> templates, {
    bool preferSkincareLayout = false,
  }) {
    final list = templates.toList();
    list.sort((a, b) {
      int score(ActionStepTemplate t) {
        var s = 0;
        if (!t.isOfficial) s += 100;
        if (preferSkincareLayout) {
          if (t.category != ActionTemplateCategory.skincare) s += 20;
          if (t.metadata['templateLayout'] != 'skincare_weekly_planner') s += 8;
          if (!t.name.toLowerCase().contains('beginner')) s += 3;
        }
        return s;
      }

      final byScore = score(a).compareTo(score(b));
      if (byScore != 0) return byScore;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  ActionStepTemplate? _primaryGuideForPlannerCategory(String category) {
    if (category == _mealPrepGuideCategory) {
      final mealPrep = _sortedTemplatesByPriority(
        _templates.where((t) => t.category == ActionTemplateCategory.mealPrep),
      );
      return mealPrep.isEmpty ? null : mealPrep.first;
    }

    if (category == 'Health') {
      final skincareFirst = _sortedTemplatesByPriority(
        _templates.where(
          (t) =>
              t.category == ActionTemplateCategory.skincare ||
              t.name.toLowerCase().contains('skincare'),
        ),
        preferSkincareLayout: true,
      );
      if (skincareFirst.isNotEmpty) return skincareFirst.first;
    }

    final categoryTemplates = _sortedTemplatesByPriority(
      _byHabitCategory(category),
    );
    return categoryTemplates.isEmpty ? null : categoryTemplates.first;
  }

  Future<void> _createHabitFromTemplate(ActionStepTemplate template) async {
    final gate = await PresetHabitCreationService.checkGate();
    if (!gate.canCreate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Need ${gate.requiredCoins} coins to create habits from this preset.',
          ),
        ),
      );
      return;
    }

    bool created = false;
    if (template.category == ActionTemplateCategory.skincare) {
      created = await _createSkincareHabitsFromTemplate(template);
    } else if (_isOneTapFitnessPreset(template)) {
      created = await _createOneTapFitnessHabitFromTemplate(template);
    } else {
      final habitCategory = _habitCategoryForTemplate(template);
      final request = await showAddHabitModal(
        context,
        existingHabits: _existingHabits,
        initialName: template.name,
        initialActionSteps: template.steps,
        initialTemplateId: template.id,
        initialTemplateVersion: template.templateVersion,
        initialCategory: habitCategory,
      );
      if (request == null) return;

      try {
        final newHabit = _buildHabitFromRequest(request);
        await HabitStorageService.addHabit(newHabit);
        widget.dataVersion?.value = (widget.dataVersion?.value ?? 0) + 1;
        created = true;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Habit created from "${template.name}"')),
          );
          await _load();
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to create habit right now. Please try again.',
              ),
            ),
          );
        }
      }
    }

    if (!created) return;
    await PresetHabitCreationService.applyChargeForSuccessfulCreate();
  }

  bool _isOneTapFitnessPreset(ActionStepTemplate template) {
    return template.category == ActionTemplateCategory.workout &&
        _habitCategoryForTemplate(template).toLowerCase() == 'fitness';
  }

  Future<bool> _createOneTapFitnessHabitFromTemplate(
    ActionStepTemplate template,
  ) async {
    developer.log(
      'Workout preset create requested',
      name: 'planner_guide.workout_create',
      error: {
        'templateId': template.id,
        'templateVersion': template.templateVersion,
        'templateName': template.name,
        'rawSteps': template.steps.length,
      },
    );
    final newHabits = _buildOneTapPresetHabits(template);
    if (newHabits.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No preset exercises available.')),
      );
      return false;
    }
    try {
      developer.log(
        'Workout preset split computed',
        name: 'planner_guide.workout_create',
        error: {
          'templateId': template.id,
          'templateVersion': template.templateVersion,
          'createdHabits': newHabits
              .map(
                (h) => {
                  'name': h.name,
                  'weeklyDays': h.weeklyDays,
                  'steps': h.actionSteps.length,
                },
              )
              .toList(),
          'firstHabitSteps': newHabits.isEmpty
              ? const []
              : newHabits.first.actionSteps
                    .take(5)
                    .map((s) => s.title)
                    .toList(),
        },
      );
      for (final habit in newHabits) {
        await HabitStorageService.addHabit(habit);
      }
      widget.dataVersion?.value = (widget.dataVersion?.value ?? 0) + 1;
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${newHabits.length} ${newHabits.length == 1 ? 'habit' : 'habits'} from "${template.name}"',
          ),
        ),
      );
      await _load();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create habit right now. Please try again.'),
        ),
      );
      return false;
    }
  }

  Future<bool> _createSkincareHabitsFromTemplate(
    ActionStepTemplate template,
  ) async {
    final planner = await SkincarePlannerStorageService.loadOrDefault();
    final morningEnabled = planner.morningRoutineEnabled;
    final eveningEnabled = planner.eveningRoutineEnabled;
    if (!morningEnabled && !eveningEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one routine must be enabled.')),
      );
      return false;
    }

    final baseTitle = planner.title.trim().isEmpty
        ? template.name
        : planner.title.trim();
    try {
      final createdNames = await SkincarePresetCompiler.createHabitsFromPlanner(
        planner: planner,
        baseTitle: baseTitle,
        morningEnabled: morningEnabled,
        eveningEnabled: eveningEnabled,
      );

      if (createdNames.isEmpty) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No skincare steps available to create habits.'),
          ),
        );
        return false;
      }

      widget.dataVersion?.value = (widget.dataVersion?.value ?? 0) + 1;
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Created ${createdNames.length == 1 ? 'habit' : 'habits'}: ${createdNames.join(' and ')}',
          ),
        ),
      );
      await _load();
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create habit right now. Please try again.'),
        ),
      );
      return false;
    }
  }

  HabitItem _buildHabitFromRequest(HabitCreateRequest request) {
    return HabitItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: request.name,
      category: request.category,
      frequency: request.frequency,
      weeklyDays: request.weeklyDays,
      deadline: request.deadline,
      afterHabitId: request.afterHabitId,
      timeOfDay: request.timeOfDay,
      reminderMinutes: request.reminderMinutes,
      reminderEnabled: request.reminderEnabled,
      chaining: request.chaining,
      cbtEnhancements: request.cbtEnhancements,
      timeBound: request.timeBound,
      locationBound: request.locationBound,
      trackingSpec: request.trackingSpec,
      iconIndex: request.iconIndex,
      completedDates: const [],
      actionSteps: request.actionSteps,
      startTimeMinutes: request.startTimeMinutes,
      templateId: request.templateId,
      templateVersion: request.templateVersion,
    );
  }

  List<HabitItem> _buildOneTapPresetHabits(ActionStepTemplate template) {
    final normalizedSteps = List<HabitActionStep>.from(template.steps)
      ..sort((a, b) => a.order.compareTo(b.order));
    final exerciseNamedSteps = normalizedSteps.map((s) {
      final fallback = s.displayTitle.trim();
      final title = s.title.trim();
      return s.copyWith(title: title.isEmpty ? fallback : title);
    }).toList();

    final amSteps = <HabitActionStep>[];
    final pmSteps = <HabitActionStep>[];
    final unslottedSteps = <HabitActionStep>[];
    for (final step in exerciseNamedSteps) {
      final part = _daypartFromPlannerKey(step.plannerDay);
      if (part == 'am') {
        amSteps.add(step);
      } else if (part == 'pm') {
        pmSteps.add(step);
      } else {
        unslottedSteps.add(step);
      }
    }

    final hasAm = amSteps.isNotEmpty;
    final hasPm = pmSteps.isNotEmpty;
    developer.log(
      'Workout template daypart buckets',
      name: 'planner_guide.workout_create',
      error: {
        'templateId': template.id,
        'templateVersion': template.templateVersion,
        'hasAm': hasAm,
        'hasPm': hasPm,
        'amSteps': amSteps.length,
        'pmSteps': pmSteps.length,
        'unslottedSteps': unslottedSteps.length,
      },
    );
    final existingNames = _existingHabits
        .map((h) => h.name.trim().toLowerCase())
        .toSet();
    final createdNames = <String>{};

    String uniqueName(String base) {
      final trimmed = base.trim().isEmpty ? 'New Habit' : base.trim();
      if (!existingNames.contains(trimmed.toLowerCase()) &&
          !createdNames.contains(trimmed.toLowerCase())) {
        createdNames.add(trimmed.toLowerCase());
        return trimmed;
      }
      var suffix = 2;
      while (existingNames.contains('$trimmed ($suffix)'.toLowerCase()) ||
          createdNames.contains('$trimmed ($suffix)'.toLowerCase())) {
        suffix++;
      }
      final resolved = '$trimmed ($suffix)';
      createdNames.add(resolved.toLowerCase());
      return resolved;
    }

    HabitItem buildHabit({
      required String name,
      required List<HabitActionStep> steps,
    }) {
      final weeklyDays = _weeklyDaysFromSteps(steps, template);
      return HabitItem(
        id: 'preset-${DateTime.now().microsecondsSinceEpoch}-${steps.length}',
        name: uniqueName(name),
        category: _habitCategoryForTemplate(template),
        frequency: weeklyDays.isEmpty ? 'Daily' : 'Weekly',
        weeklyDays: weeklyDays,
        completedDates: const [],
        actionSteps: steps,
        templateId: template.id,
        templateVersion: template.templateVersion,
      );
    }

    if (!hasAm && !hasPm) {
      return [buildHabit(name: template.name, steps: exerciseNamedSteps)];
    }

    final habits = <HabitItem>[];
    if (hasAm) {
      final steps = [...amSteps, ...unslottedSteps]
        ..sort((a, b) => a.order.compareTo(b.order));
      habits.add(buildHabit(name: '${template.name} (Morning)', steps: steps));
    }
    if (hasPm) {
      final steps = [...pmSteps, ...unslottedSteps]
        ..sort((a, b) => a.order.compareTo(b.order));
      habits.add(buildHabit(name: '${template.name} (Evening)', steps: steps));
    }
    return habits;
  }

  List<int> _weeklyDaysFromSteps(
    List<HabitActionStep> steps,
    ActionStepTemplate template,
  ) {
    final fromSteps = <int>{};
    for (final step in steps) {
      for (final weekday in _extractWeekdays(step.plannerDay)) {
        fromSteps.add(weekday);
      }
    }
    if (fromSteps.isNotEmpty) {
      final sorted = fromSteps.toList()..sort();
      return sorted;
    }

    final scheduleMeta = template.metadata['schedule'];
    if (scheduleMeta is String) {
      final fromSchedule = _extractWeekdays(scheduleMeta);
      if (fromSchedule.isNotEmpty) return fromSchedule;
    }

    final daysPerWeek = (template.metadata['daysPerWeek'] as num?)?.toInt();
    if (daysPerWeek != null && daysPerWeek > 0) {
      final clamped = daysPerWeek.clamp(1, 7);
      return List<int>.generate(clamped, (index) => DateTime.monday + index);
    }
    return const [];
  }

  String? _daypartFromPlannerKey(String? rawValue) {
    final raw = (rawValue ?? '').trim().toLowerCase();
    if (raw.isEmpty) return null;
    if (RegExp(r'(^|[_\s-])am($|[_\s-])').hasMatch(raw)) return 'am';
    if (RegExp(r'(^|[_\s-])pm($|[_\s-])').hasMatch(raw)) return 'pm';
    return null;
  }

  List<int> _extractWeekdays(String? text) {
    final raw = (text ?? '').trim().toLowerCase();
    if (raw.isEmpty) return const [];

    const tokenMap = <String, int>{
      'monday': DateTime.monday,
      'mon': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'tue': DateTime.tuesday,
      'tues': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'wed': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'thu': DateTime.thursday,
      'thur': DateTime.thursday,
      'thurs': DateTime.thursday,
      'friday': DateTime.friday,
      'fri': DateTime.friday,
      'saturday': DateTime.saturday,
      'sat': DateTime.saturday,
      'sunday': DateTime.sunday,
      'sun': DateTime.sunday,
    };

    final weekdays = <int>{};
    final tokens = raw
        .split(RegExp(r'[^a-z]+'))
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty);
    for (final token in tokens) {
      final mapped = tokenMap[token];
      if (mapped != null) weekdays.add(mapped);
    }

    final sorted = weekdays.toList()..sort();
    return sorted;
  }

  Future<void> _openGuidePreview(ActionStepTemplate template) async {
    var confirmMessage = 'This will create habits from the selected preset.';
    final adapter = PresetRouteRegistry.adapterForTemplate(template);
    final config = adapter.buildConfig(template);
    final skincarePlanner = template.category == ActionTemplateCategory.skincare
        ? await SkincarePlannerStorageService.loadOrDefault()
        : null;
    MealPrepWeek? mealPrepWeek;
    Map<String, Recipe> recipesById = const {};
    if (template.category == ActionTemplateCategory.mealPrep) {
      final weeks = await MealPrepStorageService.loadAll();
      mealPrepWeek = weeks.isEmpty ? null : weeks.first;
      final recipes = await RecipeStorageService.loadAll();
      recipesById = {for (final recipe in recipes) recipe.id: recipe};
    }
    final resolvedPresetName =
        template.category == ActionTemplateCategory.skincare
        ? ((skincarePlanner?.title ?? '').trim().isNotEmpty
              ? skincarePlanner!.title.trim()
              : template.name)
        : template.name;
    if (template.category == ActionTemplateCategory.skincare) {
      final planner = skincarePlanner!;
      final enabledCount =
          (planner.morningRoutineEnabled ? 1 : 0) +
          (planner.eveningRoutineEnabled ? 1 : 0);
      final targetLabel = enabledCount == 2
          ? 'Morning and Evening'
          : (planner.morningRoutineEnabled ? 'Morning' : 'Evening');
      confirmMessage =
          'This will create $enabledCount ${enabledCount == 1 ? 'habit' : 'habits'} ($targetLabel) from the weekly plan associated with the current week of this month.';
    }
    final previewSections = _previewSectionsForTemplate(
      template: template,
      config: config,
      skincarePlanner: skincarePlanner,
      mealPrepWeek: mealPrepWeek,
      recipesById: recipesById,
    );
    final resolvedTotalSteps = previewSections.isEmpty
        ? template.steps.length
        : previewSections.fold<int>(
            0,
            (sum, section) => sum + section.steps.length,
          );

    if (!mounted) return;
    final heroTag = 'preset_header_${template.id}';
    final action = await Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => PresetDetailPage(
          heroTag: heroTag,
          presetName: resolvedPresetName,
          habitCategory: _habitCategoryForTemplate(template),
          totalSteps: resolvedTotalSteps,
          config: config,
          previewSections: previewSections,
        ),
      ),
    );
    if (!mounted || action == null || action == 'close') return;
    if (action == 'edit') {
      final edited = await adapter.openEditor(context, template);
      if (edited != null) {
        setState(() {
          _templates = _templates
              .map((t) => t.id == edited.id ? edited : t)
              .toList();
        });
        if (!mounted) return;
        await _openGuidePreview(edited);
        return;
      }
      await _load();
      return;
    }
    if (action == 'create') {
      if (template.category == ActionTemplateCategory.mealPrep) {
        await adapter.openEditor(context, template);
        if (!mounted) return;
        await _load();
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create habits?'),
          content: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await _createHabitFromTemplate(template);
    }
  }


  List<PresetPreviewSection> _previewSectionsForTemplate({
    required ActionStepTemplate template,
    required PresetTemplateConfig config,
    required SkincarePlanner? skincarePlanner,
    required MealPrepWeek? mealPrepWeek,
    required Map<String, Recipe> recipesById,
  }) {
    if (!config.sections.contains(PresetTemplateSection.routinePreview)) {
      return const [];
    }
    if (config.supportsAmPmSplit) {
      final weeklyPlan = skincarePlanner != null
          ? SkincarePresetCompiler.weeklyPlanForCurrentTrackerWeek(
              skincarePlanner,
            )
          : null;
      final morningSteps = skincarePlanner != null && weeklyPlan != null
          ? SkincarePresetCompiler.buildHabitPartsFromPlanner(
              planner: skincarePlanner,
              weeklyPlan: weeklyPlan,
              morning: true,
            ).steps
          : template.steps
                .where(
                  (s) => (s.plannerDay ?? '').trim().toLowerCase().startsWith(
                    'am',
                  ),
                )
                .toList();
      final eveningSteps = skincarePlanner != null && weeklyPlan != null
          ? SkincarePresetCompiler.buildHabitPartsFromPlanner(
              planner: skincarePlanner,
              weeklyPlan: weeklyPlan,
              morning: false,
            ).steps
          : template.steps
                .where(
                  (s) => (s.plannerDay ?? '').trim().toLowerCase().startsWith(
                    'pm',
                  ),
                )
                .toList();
      return [
        PresetPreviewSection(
          title: 'Morning Routine',
          icon: Icons.wb_sunny_outlined,
          steps: morningSteps,
        ),
        PresetPreviewSection(
          title: 'Evening Routine',
          icon: Icons.nights_stay_outlined,
          steps: eveningSteps,
        ),
      ];
    }
    if (template.category == ActionTemplateCategory.workout) {
      final weeklyMuscleSummary = _weeklyWorkoutMuscleSummary(template);
      return [
        PresetPreviewSection(
          title: 'Weekly Muscle Focus',
          icon: Icons.calendar_month_outlined,
          steps: weeklyMuscleSummary,
        ),
        PresetPreviewSection(
          title: 'Preset Steps',
          icon: Icons.playlist_add_check_outlined,
          steps: template.steps,
        ),
      ];
    }
    if (template.category == ActionTemplateCategory.mealPrep) {
      final planned = _mealPrepPreviewSteps(mealPrepWeek, recipesById);
      if (planned.isNotEmpty) {
        return [
          PresetPreviewSection(
            title: 'Weekly Meal Plan',
            icon: Icons.calendar_month_outlined,
            steps: planned,
          ),
        ];
      }
    }
    return [
      PresetPreviewSection(
        title: 'Preset Steps',
        icon: Icons.playlist_add_check_outlined,
        steps: template.steps,
      ),
    ];
  }

  List<HabitActionStep> _mealPrepPreviewSteps(
    MealPrepWeek? week,
    Map<String, Recipe> recipesById,
  ) {
    if (week == null) return const [];
    const dayOrder = <String>[
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    const dayLabel = <String, String>{
      'monday': 'Mon',
      'tuesday': 'Tue',
      'wednesday': 'Wed',
      'thursday': 'Thu',
      'friday': 'Fri',
      'saturday': 'Sat',
      'sunday': 'Sun',
    };
    const slotOrder = <String>['breakfast', 'lunch', 'dinner', 'snack'];
    const slotLabel = <String, String>{
      'breakfast': 'Breakfast',
      'lunch': 'Lunch',
      'dinner': 'Dinner',
      'snack': 'Snack',
    };

    final planned = <HabitActionStep>[];
    for (final day in dayOrder) {
      final slots = week.recipeIdByDayAndSlot[day] ?? const <String, String>{};
      for (final slot in slotOrder) {
        final recipeId = slots[slot];
        if (recipeId == null || recipeId.trim().isEmpty) continue;
        final recipe = recipesById[recipeId];
        final title = recipe?.title.trim().isNotEmpty == true
            ? recipe!.title.trim()
            : recipeId;
        final calories = (recipe?.macros?.calories ?? 0) > 0
            ? '${recipe!.macros!.calories.round()} kcal'
            : '';
        planned.add(
          HabitActionStep(
            id: 'meal-preview-$day-$slot-${planned.length}',
            title:
                '${dayLabel[day] ?? day} • ${slotLabel[slot] ?? slot}: $title${calories.isNotEmpty ? ' ($calories)' : ''}',
            iconCodePoint: Icons.restaurant_menu.codePoint,
            order: planned.length,
          ),
        );
      }
    }
    return planned;
  }

  List<HabitActionStep> _weeklyWorkoutMuscleSummary(
    ActionStepTemplate template,
  ) {
    final weekdayOrder = <int>[
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];
    final dayLabel = <int, String>{
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    final musclesByDay = <int, Set<String>>{
      for (final day in weekdayOrder) day: <String>{},
    };

    for (final step in template.steps) {
      final days = _extractWeekdays(step.plannerDay);
      if (days.isEmpty) continue;
      final muscle = (step.productType ?? '').trim().isNotEmpty
          ? (step.productType ?? '').trim()
          : step.title.trim();
      if (muscle.isEmpty) continue;
      for (final day in days) {
        musclesByDay.putIfAbsent(day, () => <String>{}).add(muscle);
      }
    }

    return [
      for (int i = 0; i < weekdayOrder.length; i++)
        HabitActionStep(
          id: 'workout-weekly-summary-$i',
          title:
              '${dayLabel[weekdayOrder[i]]}: ${musclesByDay[weekdayOrder[i]]!.isEmpty ? 'Rest' : musclesByDay[weekdayOrder[i]]!.join(' + ')}',
          iconCodePoint: Icons.check_circle_outline.codePoint,
          order: i,
        ),
    ];
  }

  static const List<String> _habitCategoriesInOrder = [
    'Health',
    'Fitness',
    'Productivity',
    'Mindfulness',
    'Learning',
    'Relationships',
    'Finance',
    'Creativity',
  ];
  static const String _challengeGuideCategory = 'Challenges';
  static const String _mealPrepGuideCategory = 'Weekly Meal Prep';

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Health':
        return Icons.favorite_outline;
      case 'Fitness':
        return Icons.fitness_center;
      case 'Productivity':
        return Icons.bolt_outlined;
      case 'Mindfulness':
        return Icons.self_improvement_outlined;
      case 'Learning':
        return Icons.menu_book_outlined;
      case 'Relationships':
        return Icons.people_outline;
      case 'Finance':
        return Icons.account_balance_wallet_outlined;
      case 'Creativity':
        return Icons.palette_outlined;
      case _challengeGuideCategory:
        return Icons.military_tech_outlined;
      case _mealPrepGuideCategory:
        return Icons.calendar_month_outlined;
      case 'Other':
      default:
        return Icons.grid_view_rounded;
    }
  }

  List<String> get _plannerGuideCategories => [
    _challengeGuideCategory,
    ..._habitCategoriesInOrder,
    _mealPrepGuideCategory,
  ];

  List<String> get _filteredPlannerGuideCategories {
    final q = _categorySearchQuery.trim().toLowerCase();
    final base = _plannerGuideCategories;
    final filtered = q.isEmpty
        ? base.toList()
        : base.where((category) {
            if (category.toLowerCase().contains(q)) return true;
            final presetName = _guideTitleTextForCategory(
              category,
              _primaryGuideForPlannerCategory(category),
            ).toLowerCase();
            return presetName.contains(q);
          }).toList();
    final indexByCategory = <String, int>{
      for (int i = 0; i < base.length; i++) base[i]: i,
    };
    filtered.sort((a, b) {
      final countCompare = _guideCountForPlannerCategory(
        b,
      ).compareTo(_guideCountForPlannerCategory(a));
      if (countCompare != 0) return countCompare;
      return (indexByCategory[a] ?? 0).compareTo(indexByCategory[b] ?? 0);
    });
    return filtered;
  }

  String _categoryDescription(String category) {
    switch (category) {
      case 'Health':
        return 'Build routines for energy, sleep, and wellness.';
      case 'Fitness':
        return 'Plan workouts and progressive training sessions.';
      case 'Productivity':
        return 'Structure focus blocks and output systems.';
      case 'Mindfulness':
        return 'Create calm rituals and emotional resets.';
      case 'Learning':
        return 'Break study goals into practical sessions.';
      case 'Relationships':
        return 'Nurture connection habits and communication.';
      case 'Finance':
        return 'Track spending, saving, and money habits.';
      case 'Creativity':
        return 'Turn ideas into repeatable creative flow.';
      case _challengeGuideCategory:
        return 'Commit to signature challenge presets.';
      case _mealPrepGuideCategory:
        return 'Plan weekly meal prep and connect recipes to habits.';
      default:
        return 'Explore category-specific action-step presets.';
    }
  }

  int _guideCountForPlannerCategory(String category) {
    if (category == _challengeGuideCategory) return 1;
    return _primaryGuideForPlannerCategory(category) == null ? 0 : 1;
  }

  Future<void> _onPlannerCategoryTap(String category) async {
    await _onPlannerGuideTap(category);
  }

  Future<void> _onPlannerGuideTap(String category) async {
    if (category == _challengeGuideCategory) {
      widget.onOpenChallengePreset?.call();
      return;
    }
    final guide = _primaryGuideForPlannerCategory(category);
    if (guide == null) return;
    await _openGuidePreview(guide);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleCategories = _filteredPlannerGuideCategories;
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                if (_error != null)
                  _MinimalOutlinePanel(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTypography.bodySmall(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                _DoubleBorderSearchField(
                  onChanged: (value) {
                    setState(() => _categorySearchQuery = value);
                  },
                  onOpenShop: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PresetShopScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (visibleCategories.isEmpty)
                  _MinimalOutlinePanel(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No category or preset matches your search.',
                      style: AppTypography.body(context).copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else ...[
                  for (int i = 0; i < visibleCategories.length; i++)
                    _StaggeredPresetRow(
                      listIndex: i,
                      animationSignature:
                          '${_categorySearchQuery}_'
                          '${visibleCategories.join('|')}',
                      child: _PresetRichCard(
                        category: visibleCategories[i],
                        categoryIcon: _iconForCategory(visibleCategories[i]),
                        guide: _primaryGuideForPlannerCategory(
                          visibleCategories[i],
                        ),
                        guideTitle: _guideTitleTextForCategory(
                          visibleCategories[i],
                          _primaryGuideForPlannerCategory(visibleCategories[i]),
                        ),
                        onTap: () => _onPlannerGuideTap(visibleCategories[i]),
                      ),
                    ),
                ],
              ],
            ),
          );
    return Scaffold(body: content);
  }
}


class _GuideCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _GuideCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _CloudSection(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle entrance when the filtered list changes (search / order).
class _StaggeredPresetRow extends StatelessWidget {
  const _StaggeredPresetRow({
    required this.listIndex,
    required this.animationSignature,
    required this.child,
  });

  final int listIndex;
  final String animationSignature;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final capped = listIndex.clamp(0, 12);
    return TweenAnimationBuilder<double>(
      key: ValueKey('preset_stagger_${animationSignature}_$listIndex'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + capped * 24),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 6),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _PresetRichCard extends StatelessWidget {
  final String category;
  final IconData categoryIcon;
  final ActionStepTemplate? guide;
  final String guideTitle;
  final VoidCallback? onTap;

  const _PresetRichCard({
    required this.category,
    required this.categoryIcon,
    required this.guide,
    required this.guideTitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = AppColors.categoryBgColor(category, isDark);
    final iconColor = AppColors.categoryIconColor(category, isDark);
    final hasGuide = guide != null;
    final heroTag = hasGuide ? 'preset_header_${guide!.id}' : null;
    // isActive: card has real content — either a loaded preset OR a special
    // category route (e.g. Challenges → "75 Hard") with its own handler.
    final isActive = hasGuide ||
        (guideTitle.isNotEmpty && guideTitle != 'No preset available');

    final allSteps = guide?.steps ?? const <HabitActionStep>[];
    final previewSteps = allSteps.take(2).toList();
    final extraCount = allSteps.length - previewSteps.length;

    final headerContent = Container(
      height: 62,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            headerColor.withValues(alpha: 0.55),
            headerColor,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(categoryIcon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  guideTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            size: 18,
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pureBlack.withValues(alpha: 0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (heroTag != null)
                    Hero(
                      tag: heroTag,
                      child: Material(
                        type: MaterialType.transparency,
                        child: headerContent,
                      ),
                    )
                  else
                    headerContent,
                  if (previewSteps.isNotEmpty || extraCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final step in previewSteps)
                            _StepChip(label: _stepLabel(step)),
                          if (extraCount > 0)
                            _StepChip(
                              label: '+$extraCount',
                              isMore: true,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stepLabel(HabitActionStep step) {
    final t = step.title.trim();
    if (t.isNotEmpty) {
      final words = t.split(' ');
      return words.take(2).join(' ');
    }
    final d = step.displayTitle.trim();
    if (d.isNotEmpty) {
      final words = d.split(' ');
      return words.take(2).join(' ');
    }
    return 'Step';
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool isMore;

  const _StepChip({required this.label, this.isMore = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderColor = isMore
        ? cs.primary.withValues(alpha: 0.35)
        : cs.outlineVariant.withValues(alpha: 0.85);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMore
            ? cs.primary.withValues(alpha: 0.08)
            : cs.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.caption(context).copyWith(
          color: isMore ? cs.primary : cs.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Flat outlined surface for Presets — minimal chrome (no cloud shadow).
class _MinimalOutlinePanel extends StatelessWidget {
  const _MinimalOutlinePanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

/// Search field with outer + inner borders (Morning Garden accent ring).
class _DoubleBorderSearchField extends StatefulWidget {
  const _DoubleBorderSearchField({
    required this.onChanged,
    required this.onOpenShop,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onOpenShop;

  @override
  State<_DoubleBorderSearchField> createState() =>
      _DoubleBorderSearchFieldState();
}

class _DoubleBorderSearchFieldState extends State<_DoubleBorderSearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              cursorColor: colorScheme.primary,
              style: AppTypography.body(context).copyWith(
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search categories or presets',
                hintStyle: AppTypography.secondary(context),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 0,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.storefront_outlined,
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
            tooltip: 'Preset shop',
            onPressed: widget.onOpenShop,
          ),
        ],
      ),
    );
  }
}

/// Solid Morning Garden card surface (replaces frosted glass on Presets).
class _CloudSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _CloudSection({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: AppColors.cloudDecoration(isDark: isDark),
      child: child,
    );
  }
}
