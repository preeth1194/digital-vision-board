import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit_item.dart';
import '../models/cbt_enhancements.dart';
import '../models/goal_metadata.dart';
import '../models/vision_components.dart';
import '../models/task_item.dart';
import '../services/notifications_service.dart';
import 'habits/habit_tracker_header.dart';
import 'habits/habit_tracker_insights_tab.dart';
import 'habits/habit_tracker_tracker_tab.dart';
import 'dialogs/add_habit_dialog.dart';
import 'tasks/task_tracker_tab.dart';

/// Modal bottom sheet for tracking habits associated with a canvas component.
class HabitTrackerSheet extends StatefulWidget {
  final VisionComponent component;
  final ValueChanged<VisionComponent> onComponentUpdated;
  final bool fullScreen;

  const HabitTrackerSheet({
    super.key,
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
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
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
    if (habit.hasWeeklySchedule && !habit.isScheduledOnDate(DateTime.now())) return;
    final now = DateTime.now();
    final wasDone = habit.isCompletedForCurrentPeriod(now);
    setState(() {
      final int index = _habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        _habits[index] = habit.toggleForDate(now);
        _updateComponent();
      }
    });
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

    final now = DateTime.now();
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
    final iso = normalized.toIso8601String().split('T')[0];
    if (!h.isCompletedForCurrentPeriod(date)) return;
    if (h.feedbackByDate.containsKey(iso)) return;
    if (!mounted) return;

    final res = await showModalBottomSheet<_CompletionFeedbackResult?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CompletionFeedbackSheet(habitName: h.name),
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
        note: (res.note ?? '').trim().isEmpty ? null : res.note!.trim(),
      );
      _habits[latestIdx] = latest.copyWith(feedbackByDate: next);
      _updateComponent();
    });
  }

  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final micro = TextEditingController();
    final obstacle = TextEditingController();
    final ifThen = TextEditingController();
    final reward = TextEditingController();
    double confidence = 8;
    bool addCbt = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final isCompact = MediaQuery.sizeOf(ctx).width < 600;
          // In fullscreen dialogs, the Scaffold resizes for the keyboard already.
          // Keep extra bottom padding only for the non-fullscreen dialog layout.
          final insetBottom = isCompact ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
          final body = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add CBT (optional)'),
                value: addCbt,
                onChanged: (v) => setLocal(() => addCbt = v),
              ),
              if (addCbt) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: micro,
                  decoration: const InputDecoration(
                    labelText: 'Micro version',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obstacle,
                  decoration: const InputDecoration(
                    labelText: 'Predicted obstacle',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ifThen,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'If-Then plan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Confidence: ${confidence.round()}/10',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Slider(
                  value: confidence,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: confidence.round().toString(),
                  onChanged: (v) => setLocal(() => confidence = v),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reward,
                  decoration: const InputDecoration(
                    labelText: 'Reward',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              ],
            ),
          );

          if (isCompact) {
            return Dialog.fullscreen(
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                appBar: AppBar(
                  title: const Text('Add task'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                body: SafeArea(child: body),
              ),
            );
          }

          return AlertDialog(
            scrollable: true,
            title: const Text('Add task'),
            content: body,
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
            ],
          );
        },
      ),
    );
    final title = controller.text.trim();
    final cbt = CbtEnhancements(
      microVersion: micro.text.trim().isEmpty ? null : micro.text.trim(),
      predictedObstacle: obstacle.text.trim().isEmpty ? null : obstacle.text.trim(),
      ifThenPlan: ifThen.text.trim().isEmpty ? null : ifThen.text.trim(),
      confidenceScore: confidence.round(),
      reward: reward.text.trim().isEmpty ? null : reward.text.trim(),
    );
    final hasCbt = (cbt.microVersion ?? '').isNotEmpty ||
        (cbt.predictedObstacle ?? '').isNotEmpty ||
        (cbt.ifThenPlan ?? '').isNotEmpty ||
        (cbt.reward ?? '').isNotEmpty;
    controller.dispose();
    micro.dispose();
    obstacle.dispose();
    ifThen.dispose();
    reward.dispose();
    if (ok != true || title.isEmpty) return;
    if (!mounted) return;

    setState(() {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      _tasks = [
        ..._tasks,
        TaskItem(
          id: id,
          title: title,
          checklist: const [],
          cbtEnhancements: (addCbt && hasCbt) ? cbt : null,
        ),
      ];
      _updateComponent();
    });
  }

  Future<void> _editTask(TaskItem task) async {
    final controller = TextEditingController(text: task.title);
    final micro = TextEditingController(text: task.cbtEnhancements?.microVersion ?? '');
    final obstacle = TextEditingController(text: task.cbtEnhancements?.predictedObstacle ?? '');
    final ifThen = TextEditingController(text: task.cbtEnhancements?.ifThenPlan ?? '');
    final reward = TextEditingController(text: task.cbtEnhancements?.reward ?? '');
    double confidence = (task.cbtEnhancements?.confidenceScore ?? 8).clamp(0, 10).toDouble();
    bool addCbt = task.cbtEnhancements != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final isCompact = MediaQuery.sizeOf(ctx).width < 600;
          // In fullscreen dialogs, the Scaffold resizes for the keyboard already.
          // Keep extra bottom padding only for the non-fullscreen dialog layout.
          final insetBottom = isCompact ? 0.0 : MediaQuery.viewInsetsOf(ctx).bottom;
          final body = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add CBT (optional)'),
                value: addCbt,
                onChanged: (v) => setLocal(() => addCbt = v),
              ),
              if (addCbt) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: micro,
                  decoration: const InputDecoration(
                    labelText: 'Micro version',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obstacle,
                  decoration: const InputDecoration(
                    labelText: 'Predicted obstacle',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ifThen,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'If-Then plan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Confidence: ${confidence.round()}/10',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Slider(
                  value: confidence,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: confidence.round().toString(),
                  onChanged: (v) => setLocal(() => confidence = v),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reward,
                  decoration: const InputDecoration(
                    labelText: 'Reward',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              ],
            ),
          );

          if (isCompact) {
            return Dialog.fullscreen(
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                appBar: AppBar(
                  title: const Text('Edit task'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
                body: SafeArea(child: body),
              ),
            );
          }

          return AlertDialog(
            scrollable: true,
            title: const Text('Edit task'),
            content: body,
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
            ],
          );
        },
      ),
    );

    final title = controller.text.trim();
    final cbt = CbtEnhancements(
      microVersion: micro.text.trim().isEmpty ? null : micro.text.trim(),
      predictedObstacle: obstacle.text.trim().isEmpty ? null : obstacle.text.trim(),
      ifThenPlan: ifThen.text.trim().isEmpty ? null : ifThen.text.trim(),
      confidenceScore: confidence.round(),
      reward: reward.text.trim().isEmpty ? null : reward.text.trim(),
    );
    final hasCbt = (cbt.microVersion ?? '').isNotEmpty ||
        (cbt.predictedObstacle ?? '').isNotEmpty ||
        (cbt.ifThenPlan ?? '').isNotEmpty ||
        (cbt.reward ?? '').isNotEmpty;
    controller.dispose();
    micro.dispose();
    obstacle.dispose();
    ifThen.dispose();
    reward.dispose();
    if (ok != true || title.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _tasks = _tasks.map((t) {
        if (t.id != task.id) return t;
        return t.copyWith(
          title: title,
          cbtEnhancements: (addCbt && hasCbt) ? cbt : null,
        );
      }).toList();
      _updateComponent();
    });
  }

  Future<void> _editChecklistItem(String taskId, ChecklistItem item) async {
    final text = TextEditingController(text: item.text);
    String? dueDate = (item.dueDate ?? '').trim().isEmpty ? null : item.dueDate;
    final micro = TextEditingController(text: item.cbtEnhancements?.microVersion ?? '');
    final obstacle = TextEditingController(text: item.cbtEnhancements?.predictedObstacle ?? '');
    final ifThen = TextEditingController(text: item.cbtEnhancements?.ifThenPlan ?? '');
    final reward = TextEditingController(text: item.cbtEnhancements?.reward ?? '');
    double confidence = (item.cbtEnhancements?.confidenceScore ?? 8).clamp(0, 10).toDouble();
    bool addCbt = item.cbtEnhancements != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final isCompact = MediaQuery.sizeOf(ctx).width < 600;
          final insetBottom = MediaQuery.viewInsetsOf(ctx).bottom;
          final body = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                controller: text,
                decoration: const InputDecoration(
                  labelText: 'Item',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (!ctx.mounted) return;
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: now,
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (picked == null) return;
                        if (!ctx.mounted) return;
                        setLocal(() => dueDate = _toIsoDate(picked));
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(dueDate == null ? 'Due date (optional)' : 'Due $dueDate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: dueDate == null ? null : () => setLocal(() => dueDate = null),
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add CBT (optional)'),
                value: addCbt,
                onChanged: (v) => setLocal(() => addCbt = v),
              ),
              if (addCbt) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: micro,
                  decoration: const InputDecoration(
                    labelText: 'Micro version',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obstacle,
                  decoration: const InputDecoration(
                    labelText: 'Predicted obstacle',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ifThen,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'If-Then plan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Confidence: ${confidence.round()}/10',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Slider(
                  value: confidence,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: confidence.round().toString(),
                  onChanged: (v) => setLocal(() => confidence = v),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reward,
                  decoration: const InputDecoration(
                    labelText: 'Reward',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              ],
            ),
          );

          if (isCompact) {
            return Dialog.fullscreen(
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                appBar: AppBar(
                  title: const Text('Edit checklist item'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
                body: SafeArea(child: body),
              ),
            );
          }

          return AlertDialog(
            scrollable: true,
            title: const Text('Edit checklist item'),
            content: body,
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
            ],
          );
        },
      ),
    );

    final label = text.text.trim();
    final cbt = CbtEnhancements(
      microVersion: micro.text.trim().isEmpty ? null : micro.text.trim(),
      predictedObstacle: obstacle.text.trim().isEmpty ? null : obstacle.text.trim(),
      ifThenPlan: ifThen.text.trim().isEmpty ? null : ifThen.text.trim(),
      confidenceScore: confidence.round(),
      reward: reward.text.trim().isEmpty ? null : reward.text.trim(),
    );
    final hasCbt = (cbt.microVersion ?? '').isNotEmpty ||
        (cbt.predictedObstacle ?? '').isNotEmpty ||
        (cbt.ifThenPlan ?? '').isNotEmpty ||
        (cbt.reward ?? '').isNotEmpty;
    text.dispose();
    micro.dispose();
    obstacle.dispose();
    ifThen.dispose();
    reward.dispose();
    if (ok != true || label.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _tasks = _tasks.map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(
          checklist: t.checklist.map((c) {
            if (c.id != item.id) return c;
            return c.copyWith(
              text: label,
              dueDate: dueDate,
              cbtEnhancements: (addCbt && hasCbt) ? cbt : null,
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
    final text = TextEditingController();
    String? dueDate;
    final micro = TextEditingController();
    final obstacle = TextEditingController();
    final ifThen = TextEditingController();
    final reward = TextEditingController();
    double confidence = 8;
    bool addCbt = false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final isCompact = MediaQuery.sizeOf(ctx).width < 600;
          final insetBottom = MediaQuery.viewInsetsOf(ctx).bottom;
          final body = SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + insetBottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              TextField(
                controller: text,
                decoration: const InputDecoration(
                  labelText: 'Item',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (!ctx.mounted) return;
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: now,
                          firstDate: now.subtract(const Duration(days: 1)),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (picked == null) return;
                        if (!ctx.mounted) return;
                        setLocal(() => dueDate = _toIsoDate(picked));
                      },
                      icon: const Icon(Icons.event_outlined),
                      label: Text(dueDate == null ? 'Due date (optional)' : 'Due $dueDate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: dueDate == null ? null : () => setLocal(() => dueDate = null),
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add CBT (optional)'),
                value: addCbt,
                onChanged: (v) => setLocal(() => addCbt = v),
              ),
              if (addCbt) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: micro,
                  decoration: const InputDecoration(
                    labelText: 'Micro version',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: obstacle,
                  decoration: const InputDecoration(
                    labelText: 'Predicted obstacle',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ifThen,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'If-Then plan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Confidence: ${confidence.round()}/10',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Slider(
                  value: confidence,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: confidence.round().toString(),
                  onChanged: (v) => setLocal(() => confidence = v),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reward,
                  decoration: const InputDecoration(
                    labelText: 'Reward',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              ],
            ),
          );

          if (isCompact) {
            return Dialog.fullscreen(
              child: Scaffold(
                resizeToAvoidBottomInset: true,
                appBar: AppBar(
                  title: const Text('Add checklist item'),
                  leading: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                body: SafeArea(child: body),
              ),
            );
          }

          return AlertDialog(
            scrollable: true,
            title: const Text('Add checklist item'),
            content: body,
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
            ],
          );
        },
      ),
    );

    final label = text.text.trim();
    final cbt = CbtEnhancements(
      microVersion: micro.text.trim().isEmpty ? null : micro.text.trim(),
      predictedObstacle: obstacle.text.trim().isEmpty ? null : obstacle.text.trim(),
      ifThenPlan: ifThen.text.trim().isEmpty ? null : ifThen.text.trim(),
      confidenceScore: confidence.round(),
      reward: reward.text.trim().isEmpty ? null : reward.text.trim(),
    );
    final hasCbt = (cbt.microVersion ?? '').isNotEmpty ||
        (cbt.predictedObstacle ?? '').isNotEmpty ||
        (cbt.ifThenPlan ?? '').isNotEmpty ||
        (cbt.reward ?? '').isNotEmpty;
    text.dispose();
    micro.dispose();
    obstacle.dispose();
    ifThen.dispose();
    reward.dispose();
    if (ok != true || label.isEmpty) return;
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
              text: label,
              dueDate: dueDate,
              completedOn: null,
              cbtEnhancements: (addCbt && hasCbt) ? cbt : null,
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
    final today = _toIsoDate(DateTime.now());
    setState(() {
      _tasks = _tasks.map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(
          checklist: t.checklist.map((c) {
            if (c.id != item.id) return c;
            final next = c.isCompleted ? null : today;
            return c.copyWith(completedOn: next);
          }).toList(),
        );
      }).toList();
      _updateComponent();
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
    final DateTime now = DateTime.now();
    
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

final class _CompletionFeedbackResult {
  final int rating;
  final String? note;
  const _CompletionFeedbackResult({required this.rating, required this.note});
}

class _CompletionFeedbackSheet extends StatefulWidget {
  final String habitName;
  const _CompletionFeedbackSheet({required this.habitName});

  @override
  State<_CompletionFeedbackSheet> createState() => _CompletionFeedbackSheetState();
}

class _CompletionFeedbackSheetState extends State<_CompletionFeedbackSheet> {
  int _rating = 5;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How did it go?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(widget.habitName, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Rating'),
              const SizedBox(width: 12),
              Expanded(
                child: Slider(
                  value: _rating.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _rating.toString(),
                  onChanged: (v) => setState(() => _rating = v.round()),
                ),
              ),
              SizedBox(width: 36, child: Text(_rating.toString(), textAlign: TextAlign.end)),
            ],
          ),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Skip')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _CompletionFeedbackResult(rating: _rating, note: _note.text),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
