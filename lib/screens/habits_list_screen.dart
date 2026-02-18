import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/vision_components.dart';
import '../models/goal_metadata.dart';
import '../models/image_component.dart';
import '../services/notifications_service.dart';
import '../services/logical_date_service.dart';
import '../services/sync_service.dart';
import '../services/habit_geofence_tracking_service.dart';
import '../services/micro_habit_storage_service.dart';
import 'habit_timer_screen.dart';
import 'rhythmic_timer_screen.dart';
import '../utils/component_label_utils.dart';
import '../widgets/dialogs/add_habit_dialog.dart';
import '../widgets/dialogs/completion_feedback_sheet.dart';
/// Habits list UI; reads habits from [components] (component.habits, backward compat)
/// and writes via [onComponentsUpdated]. Callers must sync to [HabitStorageService].
class HabitsListScreen extends StatefulWidget {
  final String? boardId;
  final List<VisionComponent> components;
  final ValueChanged<List<VisionComponent>> onComponentsUpdated;
  final bool showAppBar;
  /// Whether to show the "Due YYYY-MM-DD" chip/text in habit rows.
  ///
  /// Some contexts (e.g. embedded Habits tabs) want a cleaner list.
  final bool showDueDate;

  const HabitsListScreen({
    super.key,
    this.boardId,
    required this.components,
    required this.onComponentsUpdated,
    this.showAppBar = true,
    this.showDueDate = true,
  });

  @override
  State<HabitsListScreen> createState() => _HabitsListScreenState();
}

class _HabitsListScreenState extends State<HabitsListScreen> {
  late List<VisionComponent> _components;
  SharedPreferences? _prefs;
  // Cache for microhabit completion states: key = '${componentId}_${habitId}_${microhabitText}'
  Map<String, bool> _microhabitCompletions = {};

  @override
  void initState() {
    super.initState();
    _components = widget.components;
    _loadMicrohabitCompletions();
  }

  @override
  void didUpdateWidget(covariant HabitsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.components != widget.components) {
      _components = widget.components;
      _loadMicrohabitCompletions();
    }
  }

  /// Helper to get goal from a component
  GoalMetadata? _getGoalFromComponent(VisionComponent component) {
    if (component is ImageComponent) {
      return component.goal;
    }
    return null;
  }

  Future<void> _loadMicrohabitCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _prefs = prefs;
    
    final now = LogicalDateService.now();
    final todayIso = _toIsoDate(now);
    
    // Load all microhabit completions for today
    final completions = <String, bool>{};
    for (final c in _components) {
      final goal = _getGoalFromComponent(c);
      final microhabit = goal?.actionPlan?.microHabit?.trim();
      if (microhabit != null && microhabit.isNotEmpty) {
        for (final h in c.habits) {
          if (h.isScheduledOnDate(now)) {
            final key = '${c.id}_${h.id}_$microhabit';
            final isCompleted = await MicroHabitStorageService.isMicroHabitCompletedForHabit(
              todayIso,
              c.id,
              h.id,
              microhabit,
              prefs: prefs,
            );
            completions[key] = isCompleted;
          }
        }
      }
    }
    
    if (!mounted) return;
    setState(() {
      _microhabitCompletions = completions;
    });
  }

  Future<void> _toggleMicroHabitCompletionForHabit(
    String componentId,
    String habitId,
    String microhabitText,
  ) async {
    final now = LogicalDateService.now();
    final todayIso = _toIsoDate(now);
    final key = '${componentId}_${habitId}_$microhabitText';
    final isCompleted = _microhabitCompletions[key] ?? false;
    
    if (isCompleted) {
      await MicroHabitStorageService.unmarkMicroHabitCompletedForHabit(
        todayIso,
        componentId,
        habitId,
        microhabitText,
        prefs: _prefs,
      );
    } else {
      await MicroHabitStorageService.markMicroHabitCompletedForHabit(
        todayIso,
        componentId,
        habitId,
        microhabitText,
        prefs: _prefs,
      );
    }
    
    if (!mounted) return;
    setState(() {
      _microhabitCompletions[key] = !isCompleted;
    });
  }

  static String _toIsoDate(DateTime d) {
    return LogicalDateService.toIsoDate(d);
  }

  /// Helper function to get the appropriate icon for a habit type
  static Widget _getHabitTypeIcon(HabitItem habit) {
    if (habit.timeBound?.isSongBased == true) {
      return const Icon(Icons.music_note, size: 24);
    }
    if (habit.timeBound?.enabled == true) {
      return const Icon(Icons.timer_outlined, size: 24);
    }
    if (habit.locationBound?.enabled == true) {
      return const Icon(Icons.location_on_outlined, size: 24);
    }
    return const SizedBox.shrink(); // No icon for regular habits
  }

  Future<void> _addHabit() async {
    if (_components.isEmpty) {
      final placeholder = TextComponent(
        id: 'habits_holder_${DateTime.now().millisecondsSinceEpoch}',
        position: Offset.zero,
        size: const Size(100, 50),
        text: '',
        style: const TextStyle(),
      );
      setState(() => _components = [placeholder]);
      widget.onComponentsUpdated(_components);
    }

    final target = _components.first;

    final allHabits = _components.expand((c) => c.habits).toList();
    final req = await showAddHabitDialog(
      context,
      initialName: null,
      existingHabits: allHabits,
    );
    if (req == null) return;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newHabit = HabitItem(
      id: newId,
      name: req.name,
      category: req.category,
      frequency: req.frequency,
      weeklyDays: req.weeklyDays,
      deadline: req.deadline,
      afterHabitId: req.afterHabitId,
      timeOfDay: req.timeOfDay,
      reminderMinutes: req.reminderMinutes,
      reminderEnabled: req.reminderEnabled,
      chaining: req.chaining,
      cbtEnhancements: req.cbtEnhancements,
      timeBound: req.timeBound,
      locationBound: req.locationBound,
      iconIndex: req.iconIndex,
      actionSteps: req.actionSteps,
      startTimeMinutes: req.startTimeMinutes,
      completedDates: const [],
    );

    final nextComponents = _components.map((c) {
      if (c.id != target.id) return c;
      return c.copyWithCommon(habits: [...c.habits, newHabit]);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);

    final boardId = widget.boardId;
    if (boardId != null && boardId.trim().isNotEmpty) {
      Future<void>(() async {
        final updatedTarget = nextComponents
            .where((c) => c.id == target.id)
            .cast<VisionComponent?>()
            .firstWhere((_) => true, orElse: () => null);
        if (updatedTarget == null) return;
        await HabitGeofenceTrackingService.instance.configureForComponent(
          boardId: boardId,
          componentId: target.id,
          habits: updatedTarget.habits,
        );
      });
    }

    Future<void>(() async {
      if (!NotificationsService.shouldSchedule(newHabit)) return;
      final ok = await NotificationsService.requestPermissionsIfNeeded();
      if (!ok) return;
      await NotificationsService.scheduleHabitReminders(newHabit);
    });
  }

  Future<void> _toggleHabit(VisionComponent component, HabitItem habit) async {
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return;
    final wasDone = habit.isCompletedForCurrentPeriod(now);
    final toggled = habit.toggleForDate(now);

    List<VisionComponent> updatedComponents = _components.map((c) {
      if (c.id != component.id) return c;
      final updatedHabits = c.habits.map((h) => h.id == habit.id ? toggled : h).toList();
      return c.copyWithCommon(habits: updatedHabits);
    }).toList();

    setState(() => _components = updatedComponents);
    widget.onComponentsUpdated(updatedComponents);

    final boardId = widget.boardId;
    if (boardId != null && boardId.isNotEmpty) {
      final iso = _toIsoDate(now);
      Future<void>(() async {
        await SyncService.enqueueHabitCompletion(
          boardId: boardId,
          componentId: component.id,
          habitId: habit.id,
          logicalDate: iso,
          deleted: wasDone,
        );
      });
    }

    // Prompt for completion feedback (same semantics as HabitTrackerSheet._maybeAskCompletionFeedback).
    if (!wasDone) {
      final iso = _toIsoDate(now);
      if (!toggled.feedbackByDate.containsKey(iso)) {
        final res = await showCompletionFeedbackSheet(
          context,
          title: 'How did it go?',
          subtitle: habit.name,
        );
        if (res == null) return;

        final nextFeedback = Map<String, HabitCompletionFeedback>.from(toggled.feedbackByDate);
        nextFeedback[iso] = HabitCompletionFeedback(rating: res.rating, note: res.note);
        final withFeedback = toggled.copyWith(feedbackByDate: nextFeedback);

        updatedComponents = updatedComponents.map((c) {
          if (c.id != component.id) return c;
          final updatedHabits = c.habits.map((h) => h.id == habit.id ? withFeedback : h).toList();
          return c.copyWithCommon(habits: updatedHabits);
        }).toList();

        if (mounted) setState(() => _components = updatedComponents);
        widget.onComponentsUpdated(updatedComponents);

        final boardId2 = widget.boardId;
        if (boardId2 != null && boardId2.isNotEmpty) {
          Future<void>(() async {
            await SyncService.enqueueHabitCompletion(
              boardId: boardId2,
              componentId: component.id,
              habitId: habit.id,
              logicalDate: iso,
              rating: res.rating,
              note: res.note,
              deleted: false,
            );
          });
        }
      }
    }
  }

  Future<void> _editHabit(VisionComponent component, HabitItem habit) async {
    final cNow = _components
        .where((c) => c.id == component.id)
        .cast<VisionComponent?>()
        .firstWhere((_) => true, orElse: () => null);
    final baseComponent = cNow ?? component;
    final hNow = baseComponent.habits
        .where((h) => h.id == habit.id)
        .cast<HabitItem?>()
        .firstWhere((_) => true, orElse: () => null);
    final baseHabit = hNow ?? habit;

    final req = await showEditHabitDialog(
      context,
      habit: baseHabit,
      existingHabits: baseComponent.habits.where((h) => h.id != baseHabit.id).toList(),
    );
    if (req == null) return;
    if (!mounted) return;

    final updatedHabit = baseHabit.copyWith(
      name: req.name,
      category: req.category,
      frequency: req.frequency,
      weeklyDays: req.weeklyDays,
      deadline: req.deadline,
      afterHabitId: req.afterHabitId,
      timeOfDay: req.timeOfDay,
      reminderMinutes: req.reminderMinutes,
      reminderEnabled: req.reminderEnabled,
      chaining: req.chaining,
      cbtEnhancements: req.cbtEnhancements,
      timeBound: req.timeBound,
      locationBound: req.locationBound,
      iconIndex: req.iconIndex,
      actionSteps: req.actionSteps,
      startTimeMinutes: req.startTimeMinutes,
    );

    final nextComponents = _components.map((c) {
      if (c.id != baseComponent.id) return c;
      final nextHabits = c.habits.map((h) => h.id == baseHabit.id ? updatedHabit : h).toList();
      return c.copyWithCommon(habits: nextHabits);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);

    final boardId = widget.boardId;
    if (boardId != null && boardId.trim().isNotEmpty) {
      Future<void>(() async {
        await HabitGeofenceTrackingService.instance.configureForComponent(
          boardId: boardId,
          componentId: baseComponent.id,
          habits: nextComponents.where((c) => c.id == baseComponent.id).first.habits,
        );
      });
    }

    // Best-effort: re-schedule notifications for the updated habit.
    Future<void>(() async {
      await NotificationsService.cancelHabitReminders(updatedHabit);
      if (!NotificationsService.shouldSchedule(updatedHabit)) return;
      final ok = await NotificationsService.requestPermissionsIfNeeded();
      if (!ok) return;
      await NotificationsService.scheduleHabitReminders(updatedHabit);
    });
  }

  Future<void> _deleteHabit(VisionComponent component, HabitItem habit) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete habit?'),
            content: Text('Delete "${habit.name}"?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    if (!mounted) return;

    final cNow = _components
        .where((c) => c.id == component.id)
        .cast<VisionComponent?>()
        .firstWhere((_) => true, orElse: () => null);
    final baseComponent = cNow ?? component;

    final nextComponents = _components.map((c) {
      if (c.id != baseComponent.id) return c;
      final nextHabits = c.habits.where((h) => h.id != habit.id).toList();
      return c.copyWithCommon(habits: nextHabits);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);

    // Best-effort: cancel reminders for this habit.
    Future<void>(() async {
      await NotificationsService.cancelHabitReminders(habit);
    });

    // Keep geofence tracking in sync after deletion.
    final boardId = widget.boardId;
    if (boardId != null && boardId.trim().isNotEmpty) {
      Future<void>(() async {
        final updatedComponent = nextComponents
            .where((c) => c.id == baseComponent.id)
            .cast<VisionComponent?>()
            .firstWhere((_) => true, orElse: () => null);
        if (updatedComponent == null) return;
        await HabitGeofenceTrackingService.instance.configureForComponent(
          boardId: boardId,
          componentId: baseComponent.id,
          habits: updatedComponent.habits,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final componentsWithHabits =
        _components.where((c) => c.habits.isNotEmpty).toList();

    if (componentsWithHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.list_alt,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No habits found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a habit to a goal to get started',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addHabit,
              icon: const Icon(Icons.add),
              label: const Text('Add habit'),
            ),
          ],
        ),
      );
    }

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FilledButton.icon(
              onPressed: _addHabit,
              icon: const Icon(Icons.add),
              label: const Text('Add habit'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...componentsWithHabits.map((component) {
          final displayTitle = ComponentLabelUtils.categoryOrTitleOrId(component);
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  width: double.infinity,
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                ...component.habits.map((habit) {
                  final now = LogicalDateService.now();
                  final scheduledToday = habit.isScheduledOnDate(now);
                  final isCompleted = scheduledToday && habit.isCompletedForCurrentPeriod(now);
                  final goal = _getGoalFromComponent(component);
                  final microhabit = goal?.actionPlan?.microHabit?.trim();
                  final hasMicrohabit = microhabit != null && microhabit.isNotEmpty;
                  final microhabitKey = hasMicrohabit
                      ? '${component.id}_${habit.id}_$microhabit'
                      : null;
                  final microhabitCompleted = microhabitKey != null
                      ? (_microhabitCompletions[microhabitKey] ?? false)
                      : false;
                  
                  return Container(
                    color: (habit.locationBound?.enabled == true)
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          // Habit Column
                          Expanded(
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isCompleted,
                                  onChanged: scheduledToday ? (_) => _toggleHabit(component, habit) : null,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              habit.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                color: isCompleted
                                                    ? Theme.of(context).colorScheme.surfaceVariant
                                                    : null,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ),
                                          if (habit.timeBound?.enabled == true || habit.locationBound?.enabled == true)
                                            IconButton(
                                              tooltip: 'Timer',
                                              icon: Icon(
                                                habit.timeBound?.isSongBased == true
                                                    ? Icons.music_note
                                                    : Icons.timer_outlined,
                                                size: 18,
                                              ),
                                              onPressed: () async {
                                                final latestComponent = _components
                                                    .where((c) => c.id == component.id)
                                                    .cast<VisionComponent?>()
                                                    .firstWhere((_) => true, orElse: () => null);
                                                final latestHabit = (latestComponent?.habits ?? const <HabitItem>[])
                                                    .where((h) => h.id == habit.id)
                                                    .cast<HabitItem?>()
                                                    .firstWhere((_) => true, orElse: () => null);
                                                final habitToUse = latestHabit ?? habit;
                                                final isSongBased = habitToUse.timeBound?.isSongBased ?? false;

                                                await Navigator.of(context).push(
                                                  MaterialPageRoute<void>(
                                                    builder: (_) => isSongBased
                                                        ? RhythmicTimerScreen(
                                                            habit: habitToUse,
                                                            onMarkCompleted: () async {
                                                              final cNow = _components
                                                                  .where((c) => c.id == component.id)
                                                                  .cast<VisionComponent?>()
                                                                  .firstWhere((_) => true, orElse: () => null);
                                                              if (cNow == null) return;
                                                              final hNow = cNow.habits
                                                                  .where((h) => h.id == habit.id)
                                                                  .cast<HabitItem?>()
                                                                  .firstWhere((_) => true, orElse: () => null);
                                                              if (hNow == null) return;
                                                              final now = LogicalDateService.now();
                                                              if (!hNow.isScheduledOnDate(now)) return;
                                                              if (hNow.isCompletedForCurrentPeriod(now)) return;
                                                              await _toggleHabit(cNow, hNow);
                                                            },
                                                          )
                                                        : HabitTimerScreen(
                                                            habit: habitToUse,
                                                            onMarkCompleted: () async {
                                                              final cNow = _components
                                                                  .where((c) => c.id == component.id)
                                                                  .cast<VisionComponent?>()
                                                                  .firstWhere((_) => true, orElse: () => null);
                                                              if (cNow == null) return;
                                                              final hNow = cNow.habits
                                                                  .where((h) => h.id == habit.id)
                                                                  .cast<HabitItem?>()
                                                                  .firstWhere((_) => true, orElse: () => null);
                                                              if (hNow == null) return;
                                                              final now = LogicalDateService.now();
                                                              if (!hNow.isScheduledOnDate(now)) return;
                                                              if (hNow.isCompletedForCurrentPeriod(now)) return;
                                                              await _toggleHabit(cNow, hNow);
                                                            },
                                                          ),
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          if (!scheduledToday)
                                            Text(
                                              'Not scheduled today',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            ),
                                          if (habit.currentStreak > 0) ...[
                                            Icon(
                                              Icons.local_fire_department,
                                              size: 14,
                                              color: Theme.of(context).colorScheme.tertiary,
                                            ),
                                            Text(
                                              '${habit.currentStreak} ${habit.isWeekly ? 'week' : 'day'} streak',
                                              style: const TextStyle(fontSize: 12),
                                            ),
                                          ] else
                                            Text(
                                              'No streak yet',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            ),
                                          if (widget.showDueDate && (habit.deadline ?? '').trim().isNotEmpty)
                                            Text(
                                              'Due ${habit.deadline}',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit habit',
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _editHabit(component, habit),
                                ),
                                IconButton(
                                  tooltip: 'Delete habit',
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  onPressed: () => _deleteHabit(component, habit),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );

    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Habits'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Add habit',
            icon: const Icon(Icons.add),
            onPressed: _addHabit,
          ),
        ],
      ),
      body: body,
    );
  }
}

