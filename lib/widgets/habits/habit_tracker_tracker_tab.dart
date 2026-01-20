import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/habit_item.dart';
import '../../screens/habit_timer_screen.dart';
import '../../screens/rhythmic_timer_screen.dart';
import '../../services/habit_timer_state_service.dart';
import '../../services/logical_date_service.dart';

class HabitTrackerTab extends StatefulWidget {
  final List<HabitItem> habits;
  final TextEditingController newHabitController;
  final VoidCallback onAddHabit;
  final ValueChanged<HabitItem> onToggleHabit;
  final ValueChanged<HabitItem> onDeleteHabit;
  final ValueChanged<HabitItem> onEditHabit;

  const HabitTrackerTab({
    super.key,
    required this.habits,
    required this.newHabitController,
    required this.onAddHabit,
    required this.onToggleHabit,
    required this.onDeleteHabit,
    required this.onEditHabit,
  });

  @override
  State<HabitTrackerTab> createState() => _HabitTrackerTabState();
}

class _HabitTrackerTabState extends State<HabitTrackerTab> {
  SharedPreferences? _prefs;
  Timer? _tick;

  // Cached for today (logical date).
  final Map<String, int> _accumulatedMs = <String, int>{};
  final Map<String, bool> _isRunning = <String, bool>{};
  final Set<String> _autoCompleting = <String>{};

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  @override
  void didUpdateWidget(covariant HabitTrackerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.habits != widget.habits) {
      _refreshAll();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _prefs = p);
    await _refreshAll();
  }

  bool _isTimerOrLocationHabit(HabitItem h) {
    final tb = h.timeBound;
    final lb = h.locationBound;
    return (tb != null && tb.enabled) || (lb != null && lb.enabled);
  }

  Future<void> _refreshAll() async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    for (final h in widget.habits) {
      if (!_isTimerOrLocationHabit(h)) continue;
      final acc = await HabitTimerStateService.accumulatedMsNow(
        prefs: p,
        habitId: h.id,
        logicalDate: today,
      );
      final running = await HabitTimerStateService.isRunning(prefs: p, habitId: h.id, logicalDate: today);
      _accumulatedMs[h.id] = acc;
      _isRunning[h.id] = running;
    }
    if (!mounted) return;
    setState(() {});
    _updateTicker();
    await _maybeAutoCompleteTick();
  }

  void _updateTicker() {
    final anyRunning = _isRunning.values.any((v) => v == true);
    if (!anyRunning) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    _tick ??= Timer.periodic(const Duration(seconds: 2), (_) => _onTick());
  }

  Future<void> _onTick() async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    bool changed = false;

    for (final h in widget.habits) {
      if (!_isTimerOrLocationHabit(h)) continue;
      if (_isRunning[h.id] != true) continue;
      final acc = await HabitTimerStateService.accumulatedMsNow(
        prefs: p,
        habitId: h.id,
        logicalDate: today,
      );
      _accumulatedMs[h.id] = acc;
      changed = true;
    }

    if (!mounted) return;
    if (changed) setState(() {});
    await _maybeAutoCompleteTick();
  }

  static String _fmt(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}m';
    }
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
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

  Future<void> _startOrResume(HabitItem habit) async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    await HabitTimerStateService.start(prefs: p, habitId: habit.id, logicalDate: today);
    _isRunning[habit.id] = true;
    _accumulatedMs[habit.id] = await HabitTimerStateService.accumulatedMsNow(
      prefs: p,
      habitId: habit.id,
      logicalDate: today,
    );
    if (!mounted) return;
    setState(() {});
    _updateTicker();
    await _maybeAutoCompleteTick();
  }

  Future<void> _pause(HabitItem habit) async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    await HabitTimerStateService.pause(prefs: p, habitId: habit.id, logicalDate: today);
    _isRunning[habit.id] = false;
    _accumulatedMs[habit.id] = await HabitTimerStateService.accumulatedMsNow(
      prefs: p,
      habitId: habit.id,
      logicalDate: today,
    );
    if (!mounted) return;
    setState(() {});
    _updateTicker();
  }

  Future<void> _maybeAutoCompleteTick() async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    final now = LogicalDateService.now();

    for (final h in widget.habits) {
      if (!_isTimerOrLocationHabit(h)) continue;

      final scheduledToday = h.isScheduledOnDate(now);
      if (!scheduledToday) continue;
      if (h.isCompletedForCurrentPeriod(now)) continue;
      if (_autoCompleting.contains(h.id)) continue;

      final reached = await HabitTimerStateService.markCompletedIfReachedTarget(
        prefs: p,
        habit: h,
        logicalDate: today,
      );
      if (!reached) continue;

      _autoCompleting.add(h.id);
      if (!mounted) return;
      widget.onToggleHabit(h);
      _autoCompleting.remove(h.id);
    }

    // Refresh cached running flags (markCompletedIfReachedTarget pauses).
    for (final h in widget.habits) {
      if (!_isTimerOrLocationHabit(h)) continue;
      _isRunning[h.id] = await HabitTimerStateService.isRunning(prefs: p, habitId: h.id, logicalDate: today);
    }
    _updateTicker();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.newHabitController,
                    decoration: const InputDecoration(
                      hintText: 'Enter habit name (optional)',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => widget.onAddHabit(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: widget.onAddHabit,
                  tooltip: 'Add habit',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (widget.habits.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                'No habits yet. Add one above!',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...widget.habits.map((habit) {
            final now = LogicalDateService.now();
            final scheduledToday = habit.isScheduledOnDate(now);
            final isTodayCompleted = scheduledToday && habit.isCompletedForCurrentPeriod(now);
            final streak = habit.currentStreak;
            final unit = habit.isWeekly ? 'week' : 'day';
            final weeklyDays = habit.hasWeeklySchedule
                ? habit.weeklyDays
                    .map((d) => const {
                          DateTime.monday: 'Mon',
                          DateTime.tuesday: 'Tue',
                          DateTime.wednesday: 'Wed',
                          DateTime.thursday: 'Thu',
                          DateTime.friday: 'Fri',
                          DateTime.saturday: 'Sat',
                          DateTime.sunday: 'Sun',
                        }[d])
                    .whereType<String>()
                    .join(', ')
                : null;

            final isTimerHabit = _isTimerOrLocationHabit(habit);
            final targetMs = isTimerHabit ? HabitTimerStateService.targetMsForHabit(habit) : 0;
            final accMs = isTimerHabit ? (_accumulatedMs[habit.id] ?? 0) : 0;
            final running = isTimerHabit ? (_isRunning[habit.id] ?? false) : false;
            final remainingMs = (targetMs <= 0) ? 0 : (targetMs - accMs).clamp(0, targetMs);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: (habit.locationBound?.enabled == true)
                  ? Theme.of(context).colorScheme.tertiaryContainer
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: isTodayCompleted,
                      onChanged: scheduledToday ? (_) => widget.onToggleHabit(habit) : null,
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            habit.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (!scheduledToday)
                                Text(
                                  'Not scheduled today',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              if (streak > 0) ...[
                                Icon(
                                  Icons.local_fire_department,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                                Text(
                                  '$streak $unit${streak != 1 ? 's' : ''} streak',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ] else
                                Text(
                                  'No streak yet',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              if ((weeklyDays ?? '').trim().isNotEmpty)
                                Text(
                                  'Days $weeklyDays',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              if ((habit.deadline ?? '').trim().isNotEmpty)
                                Text(
                                  'Due ${habit.deadline}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                          if (isTimerHabit) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (targetMs > 0)
                                  Text(
                                    '${_fmt(accMs)} / ${_fmt(targetMs)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                if (targetMs > 0 && !isTodayCompleted)
                                  Text(
                                    '• ${_fmt(remainingMs)} left',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                              ],
                            ),
                            if (scheduledToday && !isTodayCompleted && targetMs > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!running)
                                    FilledButton.tonalIcon(
                                      onPressed: () => _startOrResume(habit),
                                      icon: const Icon(Icons.play_arrow),
                                      label: Text(accMs > 0 ? 'Resume' : 'Start'),
                                    )
                                  else
                                    FilledButton.tonalIcon(
                                      onPressed: () => _pause(habit),
                                      icon: const Icon(Icons.pause),
                                      label: const Text('Pause'),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _getHabitTypeIcon(habit),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (habit.timeBound?.enabled == true || habit.locationBound?.enabled == true)
                          IconButton(
                            tooltip: 'Timer',
                            icon: const Icon(Icons.timer_outlined),
                            onPressed: () async {
                              final isSongBased = habit.timeBound?.isSongBased ?? false;
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => isSongBased
                                      ? RhythmicTimerScreen(
                                          habit: habit,
                                          onMarkCompleted: () async {
                                            final now = LogicalDateService.now();
                                            final current = widget.habits
                                                .where((h) => h.id == habit.id)
                                                .cast<HabitItem?>()
                                                .firstWhere((_) => true, orElse: () => null);
                                            final h = current ?? habit;
                                            if (!h.isScheduledOnDate(now)) return;
                                            if (h.isCompletedForCurrentPeriod(now)) return;
                                            // Toggle habit completion - this will trigger _maybeAskCompletionFeedback
                                            widget.onToggleHabit(h);
                                          },
                                        )
                                      : HabitTimerScreen(
                                          habit: habit,
                                          onMarkCompleted: () async {
                                            final now = LogicalDateService.now();
                                            final current = widget.habits
                                                .where((h) => h.id == habit.id)
                                                .cast<HabitItem?>()
                                                .firstWhere((_) => true, orElse: () => null);
                                            final h = current ?? habit;
                                            if (!h.isScheduledOnDate(now)) return;
                                            if (h.isCompletedForCurrentPeriod(now)) return;
                                            widget.onToggleHabit(h);
                                          },
                                        ),
                                ),
                              );
                            },
                          ),
                        IconButton(
                          tooltip: 'Edit habit',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => widget.onEditHabit(habit),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Habit'),
                                content: Text('Delete "${habit.name}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      widget.onDeleteHabit(habit);
                                    },
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

