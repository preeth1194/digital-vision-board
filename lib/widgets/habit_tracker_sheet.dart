import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit_item.dart';
import '../models/cbt_enhancements.dart';
import '../models/goal_metadata.dart';
import '../models/vision_components.dart';
import '../models/task_item.dart';
import '../services/notifications_service.dart';
import '../services/completion_mutations.dart';
import '../services/logical_date_service.dart';
import '../services/sync_service.dart';
import 'habits/habit_tracker_header.dart';
import 'habits/habit_tracker_insights_tab.dart';
import 'habits/habit_tracker_tracker_tab.dart';
import 'dialogs/add_habit_dialog.dart';
import 'dialogs/add_task_dialog.dart';
import 'dialogs/add_checklist_item_dialog.dart';
import 'dialogs/completion_feedback_sheet.dart';
import 'tasks/task_tracker_tab.dart';

/// Modal bottom sheet for tracking habits associated with a canvas component.
class HabitTrackerSheet extends StatefulWidget {
  final String? boardId;
  final VisionComponent component;
  final ValueChanged<VisionComponent> onComponentUpdated;
  final bool fullScreen;

  const HabitTrackerSheet({
    super.key,
    this.boardId,
    required this.component,
    required this.onComponentUpdated,
    this.fullScreen = false,
  });

  @override
  State<HabitTrackerSheet> createState() => _HabitTrackerSheetState();
}

class _HabitTrackerSheetState extends State<HabitTrackerSheet> {
  late List<HabitItem> _habits;
  late List<TaskItem> _tasks;
  final TextEditingController _newHabitController = TextEditingController();
  DateTime _focusedDay = LogicalDateService.today();
  DateTime _selectedDay = LogicalDateService.today();
  bool _checkedMissed = false;

  @override
  void initState() {
    super.initState();
    _habits = List<HabitItem>.from(widget.component.habits);
    _tasks = List<TaskItem>.from(widget.component.tasks);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptMissedReschedule());
  }

  @override
  void dispose() {
    _newHabitController.dispose();
    super.dispose();
  }

  void _emitComponent(VisionComponent base) {
    final updatedComponent = base.copyWithCommon(habits: _habits, tasks: _tasks);
    widget.onComponentUpdated(updatedComponent);
  }

  void _updateComponent() {
    _emitComponent(widget.component);
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
    final goalDeadline = c is ImageComponent
        ? c.goal?.deadline
        : (c is GoalOverlayComponent ? c.goal.deadline : null);
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
    final goalDeadline = c is ImageComponent
        ? c.goal?.deadline
        : (c is GoalOverlayComponent ? c.goal.deadline : null);

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
    } else if (c is GoalOverlayComponent) {
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

  Future<void> _addTask() async {
    final res = await showAddTaskDialog(
      context,
      dialogTitle: 'Add task',
      primaryActionText: 'Add',
    );
    if (res == null) return;
    if (!mounted) return;

    setState(() {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _tasks = [
        ..._tasks,
        TaskItem(
          id: id,
          title: res.title,
          checklist: const [],
          cbtEnhancements: res.cbtEnhancements,
        ),
      ];
      _updateComponent();
    });
  }

  Future<void> _editTask(TaskItem task) async {
    final res = await showEditTaskDialog(
      context,
      dialogTitle: 'Edit task',
      primaryActionText: 'Save',
      initialTitle: task.title,
      initialCbt: task.cbtEnhancements,
    );
    if (res == null) return;
    if (!mounted) return;

    setState(() {
      _tasks = _tasks.map((t) {
        if (t.id != task.id) return t;
        return t.copyWith(
          title: res.title,
          cbtEnhancements: res.cbtEnhancements,
        );
      }).toList();
      _updateComponent();
    });
  }

  Future<void> _editChecklistItem(String taskId, ChecklistItem item) async {
    final res = await showEditChecklistItemDialog(
      context,
      dialogTitle: 'Edit checklist item',
      primaryActionText: 'Save',
      initialText: item.text,
      initialDueDate: (item.dueDate ?? '').trim().isEmpty ? null : item.dueDate,
      initialCbt: item.cbtEnhancements,
    );
    if (res == null) return;
    if (!mounted) return;

    setState(() {
      _tasks = _tasks.map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(
          checklist: t.checklist.map((c) {
            if (c.id != item.id) return c;
            return c.copyWith(
              text: res.text,
              dueDate: res.dueDate,
              cbtEnhancements: res.cbtEnhancements,
            );
          }).toList(),
        );
      }).toList();
      _updateComponent();
    });
  }

  void _deleteTask(String taskId) {
    setState(() {
      _tasks = _tasks.where((t) => t.id != taskId).toList();
      _updateComponent();
    });
  }

  Future<void> _addChecklistItem(String taskId) async {
    final res = await showAddChecklistItemDialog(
      context,
      dialogTitle: 'Add checklist item',
      primaryActionText: 'Add',
    );
    if (res == null) return;
    if (!mounted) return;

    setState(() {
      _tasks = _tasks.map((t) {
        if (t.id != taskId) return t;
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        return t.copyWith(
          checklist: [
            ...t.checklist,
            ChecklistItem(
              id: id,
              text: res.text,
              dueDate: res.dueDate,
              completedOn: null,
              cbtEnhancements: res.cbtEnhancements,
            ),
          ],
        );
      }).toList();
      _updateComponent();
    });
  }

  void _deleteChecklistItem(String taskId, String itemId) {
    setState(() {
      _tasks = _tasks.map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(checklist: t.checklist.where((c) => c.id != itemId).toList());
      }).toList();
      _updateComponent();
    });
  }

  void _toggleChecklistItem(String taskId, ChecklistItem item) {
    Future<void>(() async {
      final now = LogicalDateService.now();
      final idx = _tasks.indexWhere((t) => t.id == taskId);
      if (idx == -1) return;
      final task = _tasks[idx];

      final toggle = CompletionMutations.toggleChecklistItemForToday(task, item, now: now);
      if (!mounted) return;
      setState(() {
        _tasks = _tasks.map((t) => t.id == taskId ? toggle.updatedTask : t).toList();
        _updateComponent();
      });

      final boardId = widget.boardId;
      if (boardId != null && boardId.isNotEmpty) {
        Future<void>(() async {
          await SyncService.enqueueChecklistEvent(
            boardId: boardId,
            componentId: widget.component.id,
            taskId: taskId,
            itemId: item.id,
            logicalDate: toggle.isoDate,
            deleted: toggle.wasItemCompleted && !toggle.isItemCompleted,
          );
          if (toggle.wasTaskComplete && !toggle.isTaskComplete) {
            await SyncService.enqueueChecklistEvent(
              boardId: boardId,
              componentId: widget.component.id,
              taskId: taskId,
              itemId: '__task__',
              logicalDate: toggle.isoDate,
              deleted: true,
            );
          }
        });
      }

      // Checklist item completion feedback.
      if (!toggle.wasItemCompleted && toggle.isItemCompleted) {
        var currentTask = toggle.updatedTask;

        final updatedItem = currentTask.checklist.firstWhere((c) => c.id == item.id);
        final isSingleItemTask = currentTask.checklist.length == 1;
        final shouldSkipItemFeedback = isSingleItemTask && !toggle.wasTaskComplete && toggle.isTaskComplete;

        if (!shouldSkipItemFeedback && !updatedItem.feedbackByDate.containsKey(toggle.isoDate)) {
          final res = await showCompletionFeedbackSheet(
            context,
            title: 'How did it go?',
            subtitle: '${task.title}: ${updatedItem.text}',
          );
          if (res != null) {
            currentTask = CompletionMutations.applyChecklistItemFeedback(
              currentTask,
              itemId: updatedItem.id,
              isoDate: toggle.isoDate,
              feedback: CompletionFeedback(rating: res.rating, note: res.note),
            );
            if (!mounted) return;
            setState(() {
              _tasks = _tasks.map((t) => t.id == taskId ? currentTask : t).toList();
              _updateComponent();
            });

            final boardId2 = widget.boardId;
            if (boardId2 != null && boardId2.isNotEmpty) {
              Future<void>(() async {
                await SyncService.enqueueChecklistEvent(
                  boardId: boardId2,
                  componentId: widget.component.id,
                  taskId: taskId,
                  itemId: updatedItem.id,
                  logicalDate: toggle.isoDate,
                  rating: res.rating,
                  note: res.note,
                  deleted: false,
                );
              });
            }
          }
        }

        // Task-level completion feedback (when task becomes fully complete).
        if (!toggle.wasTaskComplete && toggle.isTaskComplete) {
          if (!currentTask.completionFeedbackByDate.containsKey(toggle.isoDate)) {
            final res = await showCompletionFeedbackSheet(
              context,
              title: 'Task completed',
              subtitle: task.title,
            );
            if (res != null) {
              currentTask = CompletionMutations.applyTaskCompletionFeedback(
                currentTask,
                isoDate: toggle.isoDate,
                feedback: CompletionFeedback(rating: res.rating, note: res.note),
              );
              if (!mounted) return;
              setState(() {
                _tasks = _tasks.map((t) => t.id == taskId ? currentTask : t).toList();
                _updateComponent();
              });

              final boardId3 = widget.boardId;
              if (boardId3 != null && boardId3.isNotEmpty) {
                Future<void>(() async {
                  await SyncService.enqueueChecklistEvent(
                    boardId: boardId3,
                    componentId: widget.component.id,
                    taskId: taskId,
                    itemId: '__task__',
                    logicalDate: toggle.isoDate,
                    rating: res.rating,
                    note: res.note,
                    deleted: false,
                  );
                });
              }
            }
          }
        }
      }
    });
  }

  /// Check if any habit was completed on a specific date
  bool _isAnyHabitCompletedOnDate(DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final anyHabit = _habits.any((habit) => habit.isCompletedOnDate(normalizedDate));
    final iso = _toIsoDate(normalizedDate);
    final anyChecklist = _tasks.any((t) => t.checklist.any((c) => c.completedOn == iso));
    return anyHabit || anyChecklist;
  }

  /// Get the total number of habits completed on a specific date
  int _getCompletionCountForDate(DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    int count = 0;
    for (final habit in _habits) {
      if (habit.isCompletedOnDate(normalizedDate)) {
        count++;
      }
    }
    final iso = _toIsoDate(normalizedDate);
    for (final t in _tasks) {
      for (final c in t.checklist) {
        if (c.completedOn == iso) count++;
      }
    }
    return count;
  }

  /// Get completion data for the last 7 days
  List<Map<String, dynamic>> _getLast7DaysData() {
    final List<Map<String, dynamic>> data = [];
    final DateTime now = LogicalDateService.now();
    
    for (int i = 6; i >= 0; i--) {
      final DateTime date = now.subtract(Duration(days: i));
      final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
      final int count = _getCompletionCountForDate(normalizedDate);
      final String dayName = DateFormat('EEE').format(date);
      
      data.add({
        'date': normalizedDate,
        'count': count,
        'dayName': dayName,
      });
    }
    
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final last7DaysData = _getLast7DaysData();
    final maxCount = last7DaysData.isEmpty
        ? 1
        : last7DaysData.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);

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
        length: 3,
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
                  Tab(text: 'Tasks', icon: Icon(Icons.checklist)),
                  Tab(text: 'Insights', icon: Icon(Icons.insights)),
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
                    TaskTrackerTab(
                      tasks: _tasks,
                      onAddTask: _addTask,
                      onEditTask: _editTask,
                      onDeleteTask: _deleteTask,
                      onAddChecklistItem: _addChecklistItem,
                      onToggleChecklistItem: _toggleChecklistItem,
                      onDeleteChecklistItem: _deleteChecklistItem,
                      onEditChecklistItem: _editChecklistItem,
                    ),
                    HabitInsightsTab(
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      onFocusedDayChanged: (d) => setState(() => _focusedDay = d),
                      onSelectedDayChanged: (d) => setState(() => _selectedDay = d),
                      isAnyHabitCompletedOnDate: _isAnyHabitCompletedOnDate,
                      last7DaysData: last7DaysData,
                      maxCount: maxCount,
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
