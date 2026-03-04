import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/action_step_template.dart';
import '../models/habit_action_step.dart';
import '../models/habit_item.dart';
import '../models/skincare_planner.dart';
import '../screens/meal_prep/meal_prep_week_screen.dart';
import '../screens/presets/preset_shop_screen.dart';
import '../screens/skincare/skincare_planner_screen.dart';
import '../services/action_templates_service.dart';
import '../services/dv_auth_service.dart';
import '../services/habit_storage_service.dart';
import '../services/skincare_planner_storage_service.dart';
import '../widgets/rituals/add_habit_modal.dart';

class PlannerGuideScreen extends StatefulWidget {
  final ValueNotifier<int>? dataVersion;

  const PlannerGuideScreen({super.key, this.dataVersion});

  @override
  State<PlannerGuideScreen> createState() => _PlannerGuideScreenState();
}

class _PlannerGuideScreenState extends State<PlannerGuideScreen> {
  bool _loading = true;
  String? _error;
  List<ActionStepTemplate> _templates = const [];
  List<HabitItem> _existingHabits = const [];
  double _scrollOffset = 0;
  String _categorySearchQuery = '';
  String? _expandedCategory;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final habits = await HabitStorageService.loadAll();
    try {
      final token = await DvAuthService.getDvToken();
      List<ActionStepTemplate> templates;
      if (token == null) {
        templates = _fallbackTemplates();
      } else {
        templates = await ActionTemplatesService.listApproved(dvToken: token);
        if (templates.isEmpty) templates = _fallbackTemplates();
      }
      if (!mounted) return;
      setState(() {
        _existingHabits = habits;
        _templates = templates;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _existingHabits = habits;
        _templates = _fallbackTemplates();
        _loading = false;
        _error = 'Could not load cloud templates. Showing defaults.';
      });
    }
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
    }) {
      final resolvedSteps = structuredSteps ??
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
        schemaVersion: 1,
        templateVersion: 1,
        setKey: setKey,
        isOfficial: true,
        status: ActionTemplateStatus.approved,
        createdByUserId: null,
        steps: resolvedSteps,
        metadata: {
          'habitCategory': habitCategory,
          ...metadata,
        },
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
        name: 'Beginner Full Body Split',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Fitness',
        setKey: 'default_set_beginner',
        steps: [
          'Warm-up',
          'Compound lift',
          'Accessory work',
          'Cooldown stretch',
        ],
      ),
      t(
        id: 'default_set_structured_workout',
        name: 'Structured Muscle Group Split',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Fitness',
        setKey: 'default_set_structured',
        steps: [
          'Primary muscle focus',
          'Secondary muscle focus',
          'Core finisher',
          'Mobility',
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
        name: 'Productivity Daily Focus Preset',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Productivity',
        setKey: 'default_set_beginner',
        steps: [
          'Pick top 3 priorities',
          'Deep work block',
          'Inbox cleanup',
          'Plan tomorrow',
        ],
      ),
      t(
        id: 'default_mindfulness_guide',
        name: 'Mindfulness Reset Preset',
        category: ActionTemplateCategory.skincare,
        habitCategory: 'Mindfulness',
        setKey: 'default_set_beginner',
        steps: [
          'Breathing reset',
          'Meditation',
          'Gratitude note',
          'End-of-day reflection',
        ],
      ),
      t(
        id: 'default_learning_guide',
        name: 'Learning Sprint Preset',
        category: ActionTemplateCategory.workout,
        habitCategory: 'Learning',
        setKey: 'default_set_beginner',
        steps: [
          'Choose learning topic',
          'Study session',
          'Practice/revision',
          'Capture insights',
        ],
      ),
      t(
        id: 'default_relationships_guide',
        name: 'Relationship Care Preset',
        category: ActionTemplateCategory.mealPrep,
        habitCategory: 'Relationships',
        setKey: 'default_set_beginner',
        steps: [
          'Reach out',
          'Meaningful conversation',
          'Follow-up action',
          'Express appreciation',
        ],
      ),
      t(
        id: 'default_finance_guide',
        name: 'Finance Check-in Preset',
        category: ActionTemplateCategory.mealPrep,
        habitCategory: 'Finance',
        setKey: 'default_set_beginner',
        steps: [
          'Review expenses',
          'Check budget',
          'Transfer to savings',
          'Track goal progress',
        ],
      ),
      t(
        id: 'default_creativity_guide',
        name: 'Creativity Flow Preset',
        category: ActionTemplateCategory.recipe,
        habitCategory: 'Creativity',
        setKey: 'default_set_beginner',
        steps: [
          'Collect inspiration',
          'Create first draft',
          'Refine one section',
          'Publish/share',
        ],
      ),
      t(
        id: 'default_other_guide',
        name: 'General Habit Preset',
        category: ActionTemplateCategory.recipe,
        habitCategory: 'Other',
        setKey: 'default_set_beginner',
        steps: [
          'Define tiny action',
          'Do it immediately',
          'Track completion',
          'Improve next step',
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
        return 'Health';
      case ActionTemplateCategory.workout:
        return 'Fitness';
      case ActionTemplateCategory.mealPrep:
      case ActionTemplateCategory.recipe:
        return 'Health';
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

    final categoryTemplates = _sortedTemplatesByPriority(_byHabitCategory(category));
    return categoryTemplates.isEmpty ? null : categoryTemplates.first;
  }

  Future<void> _createHabitFromTemplate(ActionStepTemplate template) async {
    if (template.category == ActionTemplateCategory.skincare) {
      await _createSkincareHabitsFromTemplate(template);
      return;
    }
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

    final newHabit = _buildHabitFromRequest(request);
    await HabitStorageService.addHabit(newHabit);
    widget.dataVersion?.value = (widget.dataVersion?.value ?? 0) + 1;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Habit created from "${template.name}"')),
    );
    await _load();
  }

  String _uniqueHabitName(String base, Set<String> takenLower) {
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

  int? _weekdayFromPlannerDay(String plannerDay) {
    final key = plannerDay.trim().toLowerCase();
    if (key.contains('mon')) return DateTime.monday;
    if (key.contains('tue')) return DateTime.tuesday;
    if (key.contains('wed')) return DateTime.wednesday;
    if (key.contains('thu')) return DateTime.thursday;
    if (key.contains('fri')) return DateTime.friday;
    if (key.contains('sat')) return DateTime.saturday;
    if (key.contains('sun')) return DateTime.sunday;
    return null;
  }

  ({List<HabitActionStep> steps, List<int> weekdays}) _buildSkincareHabitParts({
    required List<HabitActionStep> source,
    required String prefix,
  }) {
    final steps = <HabitActionStep>[];
    final weekdays = <int>{};
    for (int i = 0; i < source.length; i++) {
      final s = source[i];
      final weekday = _weekdayFromPlannerDay(s.plannerDay ?? '');
      if ((s.plannerDay ?? '').toLowerCase().contains('daily')) {
        weekdays.addAll(const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
          DateTime.saturday,
          DateTime.sunday,
        ]);
      } else if (weekday != null) {
        weekdays.add(weekday);
      }
      steps.add(
        s.copyWith(
          id: '$prefix-${DateTime.now().microsecondsSinceEpoch}-$i',
          order: i,
        ),
      );
    }
    return (
      steps: steps,
      weekdays: weekdays.isEmpty
          ? const [
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
              DateTime.saturday,
              DateTime.sunday,
            ]
          : (weekdays.toList()..sort()),
    );
  }

  Future<void> _createSkincareHabitsFromTemplate(ActionStepTemplate template) async {
    final planner = await SkincarePlannerStorageService.loadOrDefault();
    final morningEnabled = planner.morningRoutineEnabled;
    final eveningEnabled = planner.eveningRoutineEnabled;
    if (!morningEnabled && !eveningEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one routine must be enabled.')),
      );
      return;
    }

    final morningSource = template.steps
        .where((s) => (s.plannerDay ?? '').trim().toLowerCase().startsWith('am'))
        .toList();
    final eveningSource = template.steps
        .where((s) => (s.plannerDay ?? '').trim().toLowerCase().startsWith('pm'))
        .toList();
    final morning = _buildSkincareHabitParts(
      source: morningSource,
      prefix: 'skincare-am',
    );
    final evening = _buildSkincareHabitParts(
      source: eveningSource,
      prefix: 'skincare-pm',
    );

    final existing = await HabitStorageService.loadAll();
    final taken = existing.map((h) => h.name.toLowerCase()).toSet();
    final createdNames = <String>[];

    if (morningEnabled && morning.steps.isNotEmpty) {
      final name = _uniqueHabitName('${template.name} Morning', taken);
      await HabitStorageService.addHabit(
        HabitItem(
          id: 'skincare-am-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          category: 'Health',
          frequency: 'Weekly',
          weeklyDays: morning.weekdays,
          actionSteps: morning.steps,
          completedDates: const [],
        ),
      );
      createdNames.add(name);
    }

    if (eveningEnabled && evening.steps.isNotEmpty) {
      final name = _uniqueHabitName('${template.name} Evening', taken);
      await HabitStorageService.addHabit(
        HabitItem(
          id: 'skincare-pm-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
          category: 'Health',
          frequency: 'Weekly',
          weeklyDays: evening.weekdays,
          actionSteps: evening.steps,
          completedDates: const [],
        ),
      );
      createdNames.add(name);
    }

    if (createdNames.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No skincare steps available to create habits.')),
      );
      return;
    }

    widget.dataVersion?.value = (widget.dataVersion?.value ?? 0) + 1;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Created ${createdNames.length == 1 ? 'habit' : 'habits'}: ${createdNames.join(' and ')}',
        ),
      ),
    );
    await _load();
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

  Future<void> _openGuidePreview(ActionStepTemplate template) async {
    var confirmMessage = 'This will create habits from the selected preset.';
    if (template.category == ActionTemplateCategory.skincare) {
      final planner = await SkincarePlannerStorageService.loadOrDefault();
      final enabledCount =
          (planner.morningRoutineEnabled ? 1 : 0) +
          (planner.eveningRoutineEnabled ? 1 : 0);
      final targetLabel = enabledCount == 2
          ? 'Morning and Evening'
          : (planner.morningRoutineEnabled ? 'Morning' : 'Evening');
      confirmMessage =
          'This will create $enabledCount ${enabledCount == 1 ? 'habit' : 'habits'} ($targetLabel) from the weekly plan associated with the current week of this month.';
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final habitCategory = _habitCategoryForTemplate(template);
        final morningSteps = template.steps
            .where(
              (s) => (s.plannerDay ?? '').trim().toLowerCase().startsWith('am'),
            )
            .toList();
        final eveningSteps = template.steps
            .where(
              (s) => (s.plannerDay ?? '').trim().toLowerCase().startsWith('pm'),
            )
            .toList();

        Widget buildRoutinePreview({
          required String title,
          required IconData icon,
          required List<HabitActionStep> steps,
        }) {
          return Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${steps.length} ${steps.length == 1 ? 'step' : 'steps'}',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (steps.isEmpty)
                  Text(
                    'No steps',
                    style: Theme.of(
                      ctx,
                    ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                for (int i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
                          child: Text(
                            '${i + 1}',
                            style: Theme.of(ctx).textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            steps[i].displayTitle.isEmpty
                                ? 'Step ${i + 1}'
                                : steps[i].displayTitle,
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          child: _GlassSection(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          template.name,
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit preset',
                        onPressed: () => Navigator.of(ctx).pop('edit'),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(habitCategory),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      Chip(
                        label: Text('${template.steps.length} steps'),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          buildRoutinePreview(
                            title: 'Morning Routine',
                            icon: Icons.wb_sunny_outlined,
                            steps: morningSteps,
                          ),
                          const SizedBox(height: 8),
                          buildRoutinePreview(
                            title: 'Evening Routine',
                            icon: Icons.nights_stay_outlined,
                            steps: eveningSteps,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop('close'),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop('create'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Create habits'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || action == null || action == 'close') return;
    if (action == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SkincarePlannerScreen(initialTemplate: template),
        ),
      );
      return;
    }
    if (action == 'create') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Create habits?'),
          content: Text(
            confirmMessage,
          ),
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
  static const String _mealPrepGuideCategory = 'Weekly Meal Prep';
  static const double _categoryDeckCardHeight = 156;
  static const double _categoryDeckPeekHeight = 66;

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
      case _mealPrepGuideCategory:
        return Icons.calendar_month_outlined;
      case 'Other':
      default:
        return Icons.grid_view_rounded;
    }
  }

  List<String> get _plannerGuideCategories => [
    ..._habitCategoriesInOrder,
    _mealPrepGuideCategory,
  ];

  List<String> get _filteredPlannerGuideCategories {
    final q = _categorySearchQuery.trim().toLowerCase();
    if (q.isEmpty) return _plannerGuideCategories;
    return _plannerGuideCategories
        .where((category) {
          if (category.toLowerCase().contains(q)) return true;
          final presetName =
              _primaryGuideForPlannerCategory(category)?.name.toLowerCase() ??
              '';
          return presetName.contains(q);
        })
        .toList();
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
      case _mealPrepGuideCategory:
        return 'Plan weekly meal prep and connect recipes to habits.';
      default:
        return 'Explore category-specific action-step presets.';
    }
  }

  int _guideCountForPlannerCategory(String category) {
    return _primaryGuideForPlannerCategory(category) == null ? 0 : 1;
  }

  Future<void> _onPlannerCategoryTap(String category) async {
    setState(() {
      _expandedCategory = _expandedCategory == category ? null : category;
    });
  }

  Future<void> _onPlannerGuideTap(String category) async {
    if (category == _mealPrepGuideCategory) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MealPrepWeekScreen()));
      return;
    }
    final guide = _primaryGuideForPlannerCategory(category);
    if (guide == null) return;
    await _openGuidePreview(guide);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewportHeight = MediaQuery.of(context).size.height;
    final visibleCategories = _filteredPlannerGuideCategories;
    final estimatedDeckHeight = visibleCategories.isEmpty
        ? 0.0
        : _categoryDeckCardHeight +
              ((visibleCategories.length - 1) * _categoryDeckPeekHeight);
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.axis == Axis.vertical) {
                    setState(() {
                      _scrollOffset = notification.metrics.pixels;
                    });
                  }
                  return false;
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    if (_error != null)
                      _GlassSection(
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!)),
                          ],
                        ),
                      ),
                    _GlassSection(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _categorySearchQuery = value);
                        },
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Search categories or presets',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: IconButton(
                            tooltip: 'Preset shop',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PresetShopScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.storefront_outlined),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (visibleCategories.isEmpty)
                      _GlassSection(
                        child: Text(
                          'No category or preset matches your search.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      _CategoryDeck(
                        categories: visibleCategories,
                        cardHeight: _categoryDeckCardHeight,
                        peekHeight: _categoryDeckPeekHeight,
                        scrollOffset: _scrollOffset,
                        expandedCategory: _expandedCategory,
                        iconForCategory: _iconForCategory,
                        subtitleForCategory: _categoryDescription,
                        guideCountForCategory: _guideCountForPlannerCategory,
                        guideForCategory: _primaryGuideForPlannerCategory,
                        onTapCategory: _onPlannerCategoryTap,
                        onTapGuide: _onPlannerGuideTap,
                      ),
                  ],
                ),
              ),
            ),
    );
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
    return _GlassSection(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
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

class _CategoryDeck extends StatelessWidget {
  final List<String> categories;
  final double cardHeight;
  final double peekHeight;
  final double scrollOffset;
  final String? expandedCategory;
  final IconData Function(String) iconForCategory;
  final String Function(String) subtitleForCategory;
  final int Function(String) guideCountForCategory;
  final ActionStepTemplate? Function(String) guideForCategory;
  final Future<void> Function(String category) onTapCategory;
  final Future<void> Function(String category) onTapGuide;

  const _CategoryDeck({
    required this.categories,
    required this.cardHeight,
    required this.peekHeight,
    required this.scrollOffset,
    required this.expandedCategory,
    required this.iconForCategory,
    required this.subtitleForCategory,
    required this.guideCountForCategory,
    required this.guideForCategory,
    required this.onTapCategory,
    required this.onTapGuide,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    const expandedPanelHeight = 86.0;
    final expandedIndex = expandedCategory == null
        ? -1
        : categories.indexOf(expandedCategory!);
    final totalHeight =
        cardHeight +
        ((categories.length - 1) * peekHeight) +
        (expandedIndex >= 0 ? expandedPanelHeight : 0);
    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < categories.length; i++)
            Positioned(
              left: 0,
              right: 0,
              top: (i * peekHeight) +
                  (expandedIndex >= 0 && i > expandedIndex
                      ? expandedPanelHeight
                      : 0),
              child: _CategoryGuideCard(
                index: i,
                title: categories[i],
                subtitle: subtitleForCategory(categories[i]),
                icon: iconForCategory(categories[i]),
                guideCount: guideCountForCategory(categories[i]),
                scrollOffset: scrollOffset,
                cardHeight: cardHeight,
                expandedPanelHeight: expandedPanelHeight,
                isExpanded: categories[i] == expandedCategory,
                guide: guideForCategory(categories[i]),
                zDepth: (i + 1).toDouble(),
                onTap: () => onTapCategory(categories[i]),
                onTapGuide: () => onTapGuide(categories[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryGuideCard extends StatefulWidget {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final int guideCount;
  final double scrollOffset;
  final double cardHeight;
  final double expandedPanelHeight;
  final bool isExpanded;
  final ActionStepTemplate? guide;
  final double zDepth;
  final VoidCallback onTap;
  final VoidCallback onTapGuide;

  const _CategoryGuideCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.guideCount,
    required this.scrollOffset,
    required this.cardHeight,
    required this.expandedPanelHeight,
    required this.isExpanded,
    required this.guide,
    required this.zDepth,
    required this.onTap,
    required this.onTapGuide,
  });

  @override
  State<_CategoryGuideCard> createState() => _CategoryGuideCardState();
}

class _CategoryGuideCardState extends State<_CategoryGuideCard> {
  bool _pressed = false;
  bool _pulse = false;

  @override
  void didUpdateWidget(covariant _CategoryGuideCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isExpanded == widget.isExpanded) return;
    setState(() => _pulse = true);
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => _pulse = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scrollDrift =
        math.sin((widget.scrollOffset / 68) + (widget.index * 0.48)) * 2.4;
    final guide = widget.guide;
    final expanded = widget.isExpanded;
    return SizedBox(
      height: widget.cardHeight + (expanded ? widget.expandedPanelHeight : 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(0.0, scrollDrift + (_pressed ? -3.0 : 0.0))
          ..scale(_pressed ? 0.992 : (_pulse ? 1.012 : 1.0)),
        child: _GlassSection(
          zDepth: widget.zDepth,
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            children: [
              InkWell(
                onTap: widget.onTap,
                onHighlightChanged: (highlighted) {
                  if (_pressed == highlighted) return;
                  setState(() {
                    _pressed = highlighted;
                  });
                },
                borderRadius: BorderRadius.circular(28),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(alpha: 0.14),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.86,
                            ),
                          ),
                        ),
                        child: Icon(
                          widget.icon,
                          size: 21,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.titleMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant.withValues(
                                        alpha: 0.75,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '${widget.guideCount} preset${widget.guideCount == 1 ? '' : 's'}',
                                    style: Theme.of(context).textTheme.labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 130),
                        curve: Curves.easeOut,
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary.withValues(
                            alpha: _pressed ? 0.26 : 0.18,
                          ),
                        ),
                        child: AnimatedRotation(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          turns: expanded ? 0.25 : 0,
                          child: Icon(
                            Icons.keyboard_arrow_right_rounded,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            Divider(
                              height: 1,
                              color: colorScheme.outlineVariant.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        guide?.name ?? 'No preset available',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        guide == null
                                            ? 'Try again after refresh.'
                                            : '${guide.steps.length} action steps',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  onPressed: guide == null ? null : widget.onTapGuide,
                                  child: const Text('View'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  final Widget child;
  final double zDepth;
  final double radius;
  final EdgeInsetsGeometry padding;

  const _GlassSection({
    super.key,
    required this.child,
    this.zDepth = 0,
    this.radius = 18,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.60),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isDark
                      ? (0.20 + (zDepth * 0.008)).clamp(0.20, 0.30)
                      : (0.08 + (zDepth * 0.006)).clamp(0.08, 0.16),
                ),
                blurRadius: 16 + (zDepth * 1.8),
                offset: Offset(0, 6 + (zDepth * 0.6)),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
