import 'package:flutter/material.dart';

import '../models/habit_item.dart';
import '../models/vision_components.dart';
import '../../services/utils/notifications_service.dart';
import '../../services/utils/logical_date_service.dart';
import '../../services/sync/sync_service.dart';
import '../../services/habits/habit_geofence_tracking_service.dart';
import 'habit_timer_screen.dart';
import '../utils/component_label_utils.dart';
import '../../widgets/common/dialogs/add_habit_dialog.dart';
import '../../widgets/common/dialogs/completion_feedback_sheet.dart';
import '../../widgets/common/dialogs/goal_picker_sheet.dart';

class HabitsListScreen extends StatefulWidget {
  final String? boardId;
  final List<VisionComponent> components;
  final ValueChanged<List<VisionComponent>> onComponentsUpdated;
  final bool showAppBar;
  /// Whether to show the "Due YYYY-MM-DD" chip/text in habit rows.
  ///
  /// Some contexts (e.g. VisionBoardEditorScreen's Habits tab) want a cleaner list.
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

  @override
  void initState() {
    super.initState();
    _components = widget.components;
  }

  @override
  void didUpdateWidget(covariant HabitsListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.components != widget.components) {
      _components = widget.components;
    }
  }

  static String _toIsoDate(DateTime d) {
    return LogicalDateService.toIsoDate(d);
  }

  static List<VisionComponent> _goalLikeComponents(List<VisionComponent> all) {
    return all.where((c) => c is ImageComponent || c is GoalOverlayComponent).toList();
  }

  Future<void> _addHabitFromGoalPicker() async {
    final selected = await showGoalPickerSheet(
      context,
      components: _goalLikeComponents(_components),
      title: 'Select goal for habit',
    );
    if (selected == null) return;

    final goalDeadline = selected is ImageComponent
        ? selected.goal?.deadline
        : (selected is GoalOverlayComponent ? selected.goal.deadline : null);

    final req = await showAddHabitDialog(
      context,
      initialName: null,
      suggestedGoalDeadline: goalDeadline,
      existingHabits: selected.habits,
    );
    if (req == null) return;

    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final newHabit = HabitItem(
      id: newId,
      name: req.name,
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
      completedDates: const [],
    );

    final nextComponents = _components.map((c) {
      if (c.id != selected.id) return c;
      return c.copyWithCommon(habits: [...c.habits, newHabit]);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);

    final boardId = widget.boardId;
    if (boardId != null && boardId.trim().isNotEmpty) {
      Future<void>(() async {
        // Keep location tracking in sync when new location-based habits are added.
        final updatedSelected = nextComponents
            .where((c) => c.id == selected.id)
            .cast<VisionComponent?>()
            .firstWhere((_) => true, orElse: () => null);
        if (updatedSelected == null) return;
        await HabitGeofenceTrackingService.instance.configureForComponent(
          boardId: boardId,
          componentId: selected.id,
          habits: updatedSelected.habits,
        );
      });
    }

    Future<void>(() async {
      if (!newHabit.reminderEnabled || newHabit.reminderMinutes == null) return;
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

    final goalDeadline = baseComponent is ImageComponent
        ? baseComponent.goal?.deadline
        : (baseComponent is GoalOverlayComponent ? baseComponent.goal.deadline : null);

    final req = await showEditHabitDialog(
      context,
      habit: baseHabit,
      suggestedGoalDeadline: goalDeadline,
      existingHabits: baseComponent.habits.where((h) => h.id != baseHabit.id).toList(),
    );
    if (req == null) return;
    if (!mounted) return;

    final updatedHabit = baseHabit.copyWith(
      name: req.name,
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
      if (!updatedHabit.reminderEnabled || updatedHabit.reminderMinutes == null) return;
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
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
            const Icon(Icons.list_alt, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No habits found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text('Add a habit to a goal to get started', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addHabitFromGoalPicker,
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
              onPressed: _addHabitFromGoalPicker,
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
                  return ListTile(
                    leading: Checkbox(
                      value: isCompleted,
                      onChanged: scheduledToday ? (_) => _toggleHabit(component, habit) : null,
                    ),
                    tileColor: (habit.locationBound?.enabled == true) ? Colors.green.shade200 : null,
                    title: Text(
                      habit.name,
                      style: TextStyle(
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!scheduledToday)
                          const Text('Not scheduled today', style: TextStyle(color: Colors.grey)),
                        if (habit.currentStreak > 0) ...[
                          const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                          Text(
                            '${habit.currentStreak} ${habit.isWeekly ? 'week' : 'day'} streak',
                          ),
                        ] else
                          const Text('No streak yet', style: TextStyle(color: Colors.grey)),
                        if (widget.showDueDate && (habit.deadline ?? '').trim().isNotEmpty)
                          Text('Due ${habit.deadline}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (habit.timeBound?.enabled == true || habit.locationBound?.enabled == true)
                          IconButton(
                            tooltip: 'Timer',
                            icon: const Icon(Icons.timer_outlined),
                            onPressed: () async {
                              final latestComponent = _components
                                  .where((c) => c.id == component.id)
                                  .cast<VisionComponent?>()
                                  .firstWhere((_) => true, orElse: () => null);
                              final latestHabit = (latestComponent?.habits ?? const <HabitItem>[])
                                  .where((h) => h.id == habit.id)
                                  .cast<HabitItem?>()
                                  .firstWhere((_) => true, orElse: () => null);

                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => HabitTimerScreen(
                                    habit: latestHabit ?? habit,
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
                        IconButton(
                          tooltip: 'Edit habit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editHabit(component, habit),
                        ),
                        IconButton(
                          tooltip: 'Delete habit',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteHabit(component, habit),
                        ),
                      ],
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
            onPressed: _addHabitFromGoalPicker,
          ),
        ],
      ),
      body: body,
    );
  }
}

