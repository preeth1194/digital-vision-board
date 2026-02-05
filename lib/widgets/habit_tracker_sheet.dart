import 'package:flutter/material.dart';
import '../models/habit_item.dart';
import '../models/goal_metadata.dart';
import '../models/vision_components.dart';
import '../services/habit_geofence_tracking_service.dart';
import '../services/notifications_service.dart';
import '../services/logical_date_service.dart';
import '../services/sync_service.dart';
import 'habits/habit_tracker_header.dart';
import 'habits/habit_tracker_tracker_tab.dart';
import 'dialogs/add_habit_dialog.dart';
import 'dialogs/completion_feedback_sheet.dart';
import 'todos/goal_todo_tab.dart';

/// Modal bottom sheet for tracking habits associated with a canvas component.
class HabitTrackerSheet extends StatefulWidget {
  final String? boardId;
  final VisionComponent component;
  final ValueChanged<VisionComponent> onComponentUpdated;
  final bool fullScreen;
  /// 0: Tracker, 1: Todo
  final int initialTabIndex;

  const HabitTrackerSheet({
    super.key,
    this.boardId,
    required this.component,
    required this.onComponentUpdated,
    this.fullScreen = false,
    this.initialTabIndex = 0,
  });

  @override
  State<HabitTrackerSheet> createState() => _HabitTrackerSheetState();
}

class _HabitTrackerSheetState extends State<HabitTrackerSheet> {
  late List<HabitItem> _habits;
  late List<GoalTodoItem> _todos;
  final TextEditingController _newHabitController = TextEditingController();
  bool _checkedMissed = false;

  @override
  void initState() {
    super.initState();
    _habits = List<HabitItem>.from(widget.component.habits);
    final meta = _goalMetadataOrNull(widget.component);
    _todos = List<GoalTodoItem>.from(meta?.todoItems ?? const []);
    // Tasks are removed across the app; ensure any legacy todo links are cleared.
    _todos = _todos.map((t) => t.copyWith(taskId: null)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptMissedReschedule());
    // Start/refresh geofence tracking for any location-bound habits in this component.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>(() async {
        final boardId = widget.boardId;
        if (boardId == null || boardId.trim().isEmpty) return;
        await HabitGeofenceTrackingService.instance.configureForComponent(
          boardId: boardId,
          componentId: widget.component.id,
          habits: _habits,
        );
      });
    });
  }

  @override
  void dispose() {
    _newHabitController.dispose();
    super.dispose();
  }

  void _emitComponent(VisionComponent base) {
    // Tasks are removed; always clear tasks on update.
    final updatedComponent = base.copyWithCommon(habits: _habits, tasks: const []);
    widget.onComponentUpdated(updatedComponent);
  }

  static GoalMetadata? _goalMetadataOrNull(VisionComponent c) {
    if (c is ImageComponent) return c.goal;
    return null;
  }

  void _emitGoalMetadata(GoalMetadata nextGoal) {
    final c = widget.component;
    final VisionComponent updated;
    if (c is ImageComponent) {
      updated = c.copyWith(goal: nextGoal);
    } else {
      return;
    }
    _emitComponent(updated);
  }

  void _updateTodos(List<GoalTodoItem> next) {
    setState(() {
      _todos = next;
    });
    final current = _goalMetadataOrNull(widget.component);
    final updated = (current ?? const GoalMetadata()).copyWith(todoItems: next);
    _emitGoalMetadata(updated);
  }

  void _updateComponent() {
    _emitComponent(widget.component);
    // Keep geofence tracking in sync with the latest habit list.
    Future<void>(() async {
      final boardId = widget.boardId;
      if (boardId == null || boardId.trim().isEmpty) return;
      await HabitGeofenceTrackingService.instance.configureForComponent(
        boardId: boardId,
        componentId: widget.component.id,
        habits: _habits,
      );
    });
  }

  void _toggleHabitCompletion(HabitItem habit) {
    // If this is a scheduled weekly habit and today is not scheduled, ignore toggles.
    final now = LogicalDateService.now();
    if (habit.hasWeeklySchedule && !habit.isScheduledOnDate(now)) return;
    final wasDone = habit.isCompletedForCurrentPeriod(now);
    setState(() {
      final int index = _habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        _habits[index] = habit.toggleForDate(now);
        _updateComponent();
      }
    });

    final boardId = widget.boardId;
    if (boardId != null && boardId.isNotEmpty) {
      final logicalDate = LogicalDateService.toIsoDate(now);
      Future<void>(() async {
        await SyncService.enqueueHabitCompletion(
          boardId: boardId,
          componentId: widget.component.id,
          habitId: habit.id,
          logicalDate: logicalDate,
          deleted: wasDone,
        );
      });
    }

    if (!wasDone) {
      Future<void>(() async => _maybeAskCompletionFeedback(habitId: habit.id, date: now));
    }
  }

  Future<void> _editHabit(HabitItem habit) async {
    final c = widget.component;
    final goalDeadline = c is ImageComponent ? c.goal?.deadline : null;
    final req = await showEditHabitDialog(
      context,
      habit: habit,
      suggestedGoalDeadline: goalDeadline,
      existingHabits: _habits.where((h) => h.id != habit.id).toList(),
    );
    if (req == null) return;
    if (!mounted) return;
    setState(() {
      final idx = _habits.indexWhere((h) => h.id == habit.id);
      if (idx == -1) return;
      _habits[idx] = habit.copyWith(
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
      _updateComponent();
    });

    final updated = _habits.firstWhere((h) => h.id == habit.id);
    Future<void>(() async {
      final ok = await NotificationsService.requestPermissionsIfNeeded();
      if (!ok) return;
      await NotificationsService.scheduleHabitReminders(updated);
    });
  }

  Future<void> _addNewHabit() async {
    final habitName = _newHabitController.text.trim();
    final c = widget.component;
    final goalDeadline = c is ImageComponent ? c.goal?.deadline : null;

    final req = await showAddHabitDialog(
      context,
      initialName: habitName.isEmpty ? null : habitName,
      suggestedGoalDeadline: goalDeadline,
      existingHabits: _habits,
    );
    if (req == null) return;

    setState(() {
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      _habits.add(
        HabitItem(
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
        ),
      );
      _newHabitController.clear();
      _updateComponent();
    });

    final created = _habits.last;
    Future<void>(() async {
      if (!created.reminderEnabled || created.reminderMinutes == null) return;
      final ok = await NotificationsService.requestPermissionsIfNeeded();
      if (!ok) return;
      await NotificationsService.scheduleHabitReminders(created);
    });
  }

  Future<void> _createHabitFromActionPlan(String microHabit, String? frequency, List<int> weeklyDays) async {
    final base = microHabit.trim();
    if (base.isEmpty) return;
    final freqLower = (frequency ?? '').trim().toLowerCase();
    final freqNorm = (freqLower == 'weekly')
        ? 'Weekly'
        : (freqLower == 'daily')
            ? 'Daily'
            : null;
    final days = (freqNorm == 'Weekly')
        ? (weeklyDays.isNotEmpty ? (weeklyDays.toList()..sort()) : <int>[DateTime.now().weekday])
        : const <int>[];

    final exists = _habits.any((h) => h.name.trim().toLowerCase() == base.toLowerCase());
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Habit already exists: $base')),
        );
      }
      return;
    }

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create habit from action plan?'),
        content: Text('Add this habit?\n\n$base'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (shouldAdd != true) return;

    setState(() {
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      _habits.add(
        HabitItem(
          id: newId,
          name: base,
          frequency: freqNorm,
          weeklyDays: days,
          completedDates: const [],
        ),
      );
      _updateComponent();
    });
  }

  void _updateGoalDetails(GoalMetadata goal) {
    final c = widget.component;
    final VisionComponent updated;
    if (c is ImageComponent) {
      updated = c.copyWith(goal: goal);
    } else {
      return;
    }
    // Only apply goal deadline to habits that don't already have an explicit due date.
    final nextDeadline = goal.deadline?.trim();
    if (nextDeadline != null && nextDeadline.isNotEmpty) {
      setState(() {
        _habits = _habits
            .map(
              (h) => ((h.deadline ?? '').trim().isEmpty)
                  ? h.copyWith(deadline: nextDeadline)
                  : h,
            )
            .toList();
      });
    }
    _emitComponent(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved goal details.')),
      );
    }
  }

  void _deleteHabit(HabitItem habit) {
    setState(() {
      _habits.removeWhere((h) => h.id == habit.id);
      _updateComponent();
    });
    Future<void>(() async {
      await NotificationsService.cancelHabitReminders(habit);
    });
  }

  Future<void> _maybePromptMissedReschedule() async {
    if (_checkedMissed) return;
    _checkedMissed = true;
    if (!mounted) return;
    if (_habits.isEmpty) return;

    final now = LogicalDateService.now();
    final nowMinutes = (now.hour * 60) + now.minute;
    HabitItem? missed;
    for (final h in _habits) {
      if (!h.reminderEnabled || h.reminderMinutes == null) continue;
      if (h.hasWeeklySchedule && !h.isScheduledOnDate(now)) continue;
      if (h.isCompletedForCurrentPeriod(now)) continue;
      if (nowMinutes <= h.reminderMinutes!) continue;
      missed = h;
      break;
    }
    if (missed == null) return;

    final m = missed;

    final doReschedule = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reschedule reminder?'),
            content: Text('You missed the reminder for "${m.name}". Reschedule it later today?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Reschedule')),
            ],
          ),
        ) ??
        false;
    if (!doReschedule) return;
    if (!mounted) return;

    final initial = TimeOfDay(hour: now.hour, minute: now.minute);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    if (!mounted) return;
    final ok = await NotificationsService.requestPermissionsIfNeeded();
    if (!ok) return;
    await NotificationsService.scheduleSnoozeForToday(m, picked);
  }

  Future<void> _maybeAskCompletionFeedback({required String habitId, required DateTime date}) async {
    final idx = _habits.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;
    final h = _habits[idx];
    final normalized = DateTime(date.year, date.month, date.day);
    final iso = LogicalDateService.toIsoDate(normalized);
    if (!h.isCompletedForCurrentPeriod(date)) return;
    if (h.feedbackByDate.containsKey(iso)) return;
    if (!mounted) return;

    final res = await showCompletionFeedbackSheet(
      context,
      title: 'How did it go?',
      subtitle: h.name,
    );
    if (res == null) return;
    if (!mounted) return;

    setState(() {
      final latestIdx = _habits.indexWhere((x) => x.id == habitId);
      if (latestIdx == -1) return;
      final latest = _habits[latestIdx];
      final next = Map<String, HabitCompletionFeedback>.from(latest.feedbackByDate);
      next[iso] = HabitCompletionFeedback(
        rating: res.rating,
        note: res.note,
      );
      _habits[latestIdx] = latest.copyWith(feedbackByDate: next);
      _updateComponent();
    });

    final boardId = widget.boardId;
    if (boardId != null && boardId.isNotEmpty) {
      Future<void>(() async {
        await SyncService.enqueueHabitCompletion(
          boardId: boardId,
          componentId: widget.component.id,
          habitId: habitId,
          logicalDate: iso,
          rating: res.rating,
          note: res.note,
          deleted: false,
        );
      });
    }
  }

  static String _toIsoDate(DateTime d) {
    return LogicalDateService.toIsoDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final insetBottom = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.of(context).size.height;
    final baseHeight = widget.fullScreen ? screenH : screenH * 0.9;
    // Keep overall footprint stable while shifting content above the keyboard.
    final height = (baseHeight - insetBottom).clamp(320.0, baseHeight);

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: insetBottom),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: DefaultTabController(
        length: 2,
        initialIndex: widget.initialTabIndex.clamp(0, 1),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: widget.fullScreen ? null : const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              if (!widget.fullScreen)
                // Drag Handle (visual only)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              HabitTrackerHeader(
                component: widget.component,
                onEditGoalDetails: _updateGoalDetails,
                onCreateHabitFromActionPlan: _createHabitFromActionPlan,
                onClose: () => Navigator.of(context).pop(),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Tracker', icon: Icon(Icons.check_circle_outline)),
                  Tab(text: 'Todo', icon: Icon(Icons.playlist_add_check)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    HabitTrackerTab(
                      habits: _habits,
                      newHabitController: _newHabitController,
                      onAddHabit: _addNewHabit,
                      onToggleHabit: _toggleHabitCompletion,
                      onDeleteHabit: _deleteHabit,
                      onEditHabit: _editHabit,
                    ),
                    GoalTodoTab(
                      todos: _todos,
                      habits: _habits,
                      onTodosChanged: _updateTodos,
                      onHabitsChanged: (next) {
                        setState(() {
                          _habits = next;
                          _updateComponent();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
