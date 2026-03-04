import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/action_step_template.dart';
import '../models/habit_action_step.dart';
import '../models/habit_item.dart';
import '../screens/meal_prep/meal_prep_week_screen.dart';
import '../services/action_templates_service.dart';
import '../services/dv_auth_service.dart';
import '../services/habit_storage_service.dart';
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
      required List<String> steps,
      required String setKey,
    }) {
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
        steps: [
          for (int i = 0; i < steps.length; i++)
            HabitActionStep(
              id: '$id-step-$i',
              title: steps[i],
              iconCodePoint: Icons.check_circle_outline.codePoint,
              order: i,
            ),
        ],
        metadata: {'habitCategory': habitCategory},
      );
    }

    return [
      t(
        id: 'default_set_beginner_skincare',
        name: 'Beginner AM/PM Skincare',
        category: ActionTemplateCategory.skincare,
        habitCategory: 'Health',
        setKey: 'default_set_beginner',
        steps: ['Cleanser', 'Toner', 'Serum', 'Moisturizer', 'Sunscreen'],
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
        name: 'Productivity Daily Focus Guide',
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
        name: 'Mindfulness Reset Guide',
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
        name: 'Learning Sprint Guide',
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
        name: 'Relationship Care Guide',
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
        name: 'Finance Check-in Guide',
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
        name: 'Creativity Flow Guide',
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
        name: 'General Habit Guide',
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

  Future<void> _createHabitFromTemplate(ActionStepTemplate template) async {
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

    final newHabit = HabitItem(
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
    await HabitStorageService.addHabit(newHabit);
    widget.dataVersion?.value = (widget.dataVersion?.value ?? 0) + 1;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Habit created from "${template.name}"')),
    );
    await _load();
  }

  Future<void> _openGuidePreview(ActionStepTemplate template) async {
    final useGuide = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final habitCategory = _habitCategoryForTemplate(template);
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
                  for (int i = 0; i < template.steps.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: Theme.of(ctx).textTheme.labelSmall,
                        ),
                      ),
                      title: Text(template.steps[i].title),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Use guide'),
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
    if (useGuide == true && mounted) {
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
        .where((category) => category.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openCategoryGuides(String category, {Rect? sourceRect}) async {
    final guides = _byHabitCategory(category);
    final description = _categoryDescription(category);
    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final sourceCenterY = sourceRect?.center.dy ?? (screenHeight * 0.42);
    final targetCenterY = screenHeight * 0.42;
    final dyFactor = ((sourceCenterY - targetCenterY) / screenHeight).clamp(
      -0.24,
      0.24,
    );
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.30),
      pageBuilder: (ctx, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
              child: _GlassSection(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.74,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$category Guides',
                              style: Theme.of(ctx).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (guides.isEmpty)
                        const Text('No guides available for this category yet.')
                      else
                        Expanded(
                          child: ListView.separated(
                            itemCount: guides.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final guide = guides[index];
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            guide.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${guide.steps.length} action steps',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.tonal(
                                      onPressed: () {
                                        Navigator.of(ctx).pop();
                                        Future.microtask(
                                          () => _openGuidePreview(guide),
                                        );
                                      },
                                      child: const Text('View'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 230),
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, dyFactor),
              end: Offset.zero,
            ).animate(curved),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          ),
        );
      },
    );
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
        return 'Explore category-specific action-step guides.';
    }
  }

  int _guideCountForPlannerCategory(String category) {
    if (category == _mealPrepGuideCategory) {
      return _templates
          .where((t) => t.category == ActionTemplateCategory.mealPrep)
          .length;
    }
    return _byHabitCategory(category).length;
  }

  Future<void> _onPlannerCategoryTap(String category, Rect sourceRect) async {
    if (category == _mealPrepGuideCategory) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MealPrepWeekScreen()));
      return;
    }
    await _openCategoryGuides(category, sourceRect: sourceRect);
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
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: 'Search guide categories',
                          prefixIcon: Icon(Icons.search_rounded),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (visibleCategories.isEmpty)
                      _GlassSection(
                        child: Text(
                          'No guide category matches your search.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      _CategoryDeck(
                        categories: visibleCategories,
                        cardHeight: _categoryDeckCardHeight,
                        peekHeight: _categoryDeckPeekHeight,
                        scrollOffset: _scrollOffset,
                        iconForCategory: _iconForCategory,
                        subtitleForCategory: _categoryDescription,
                        guideCountForCategory: _guideCountForPlannerCategory,
                        onTapCategory: _onPlannerCategoryTap,
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
  final IconData Function(String) iconForCategory;
  final String Function(String) subtitleForCategory;
  final int Function(String) guideCountForCategory;
  final void Function(String category, Rect sourceRect) onTapCategory;

  const _CategoryDeck({
    required this.categories,
    required this.cardHeight,
    required this.peekHeight,
    required this.scrollOffset,
    required this.iconForCategory,
    required this.subtitleForCategory,
    required this.guideCountForCategory,
    required this.onTapCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final totalHeight = cardHeight + ((categories.length - 1) * peekHeight);
    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < categories.length; i++)
            Positioned(
              left: 0,
              right: 0,
              top: i * peekHeight,
              child: _CategoryGuideCard(
                index: i,
                title: categories[i],
                subtitle: subtitleForCategory(categories[i]),
                icon: iconForCategory(categories[i]),
                guideCount: guideCountForCategory(categories[i]),
                scrollOffset: scrollOffset,
                cardHeight: cardHeight,
                zDepth: (i + 1).toDouble(),
                onTap: (sourceRect) => onTapCategory(categories[i], sourceRect),
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
  final double zDepth;
  final ValueChanged<Rect> onTap;

  const _CategoryGuideCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.guideCount,
    required this.scrollOffset,
    required this.cardHeight,
    required this.zDepth,
    required this.onTap,
  });

  @override
  State<_CategoryGuideCard> createState() => _CategoryGuideCardState();
}

class _CategoryGuideCardState extends State<_CategoryGuideCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scrollDrift =
        math.sin((widget.scrollOffset / 68) + (widget.index * 0.48)) * 2.4;
    return SizedBox(
      height: widget.cardHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, scrollDrift + (_pressed ? -3.0 : 0.0))
          ..scale(_pressed ? 0.992 : 1.0),
        child: _GlassSection(
          zDepth: widget.zDepth,
          radius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: InkWell(
            onTap: () {
              final render = context.findRenderObject();
              if (render is RenderBox) {
                final topLeft = render.localToGlobal(Offset.zero);
                widget.onTap(topLeft & render.size);
              } else {
                widget.onTap(Rect.zero);
              }
            },
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
                                '${widget.guideCount} guide${widget.guideCount == 1 ? '' : 's'}',
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
                      duration: const Duration(milliseconds: 130),
                      turns: _pressed ? 0.015 : 0,
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
