import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/routine.dart';
import '../models/routine_todo_item.dart';
import '../services/boards_storage_service.dart';
import '../services/routine_storage_service.dart';
import '../services/icon_service.dart';
import '../services/vision_board_components_storage_service.dart';
import '../utils/app_typography.dart';
import '../widgets/rituals/habit_form_constants.dart';
import '../widgets/rituals/habit_form_pacing_section.dart';

class RoutineEditorScreen extends StatefulWidget {
  final Routine? routine; // null for new routine
  final List<HabitItem>? existingHabits;

  const RoutineEditorScreen({
    super.key,
    this.routine,
    this.existingHabits,
  });

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  late final TextEditingController _titleController;
  late final SharedPreferences _prefs;
  bool _loading = true;

  String _title = '';
  int _iconCodePoint = Icons.list.codePoint;
  int _tileColorValue = const Color(0xFFE8F5E9).value;
  List<RoutineTodoItem> _todos = [];

  // Schedule fields (weekday chips like habit creation)
  final Set<int> _weekdays = {0, 1, 2, 3, 4, 5, 6};

  // Duration fields
  int _overallDurationMinutes = 30;
  TimeOfDay? _routineStartTime;
  int _durationValue = 30;
  String _durationUnit = 'minutes';

  int get _durationMinutes {
    return _durationUnit == 'hours' ? _durationValue * 60 : _durationValue;
  }

  // Track which todo is expanded for inline editing
  String? _expandedTodoId;

  // Linked habit (single select)
  List<HabitItem> _allHabits = [];
  String? _linkedHabitId;
  bool _linkHabitEnabled = false;
  final TextEditingController _habitSearchController = TextEditingController();
  String _habitSearchQuery = '';

  // Inline validation errors
  String? _titleError;
  String? _stepsError;
  String? _timeConflictError;
  TimeOfDay? _suggestedStartTime;

  // Cached routines for real-time conflict checking
  List<Routine> _existingRoutines = [];
  // Slot availability info (shown when no conflict)
  String? _slotAvailableInfo;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _titleController.addListener(() {
      if (_titleError != null) setState(() => _titleError = null);
    });
    _habitSearchController.addListener(() {
      setState(() => _habitSearchQuery = _habitSearchController.text.trim().toLowerCase());
    });
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load existing habits
    if (widget.existingHabits != null) {
      _allHabits = widget.existingHabits!;
    } else {
      _allHabits = await _loadAllHabitsFromStorage();
    }

    if (widget.routine != null) {
      _title = widget.routine!.title;
      _iconCodePoint = widget.routine!.iconCodePoint;
      _tileColorValue = widget.routine!.tileColorValue;
      _todos = List.from(widget.routine!.todos);
      _titleController.text = _title;
      // Populate weekdays from routine
      _weekdays.clear();
      if (widget.routine!.occurrenceType == 'daily') {
        _weekdays.addAll({0, 1, 2, 3, 4, 5, 6});
      } else if (widget.routine!.weekdays != null) {
        _weekdays.addAll(widget.routine!.weekdays!);
      }
      _overallDurationMinutes = widget.routine!.overallDurationMinutes ?? 30;
      _durationValue = _overallDurationMinutes;
      _durationUnit = 'minutes';
      if (_overallDurationMinutes >= 60 && _overallDurationMinutes % 60 == 0) {
        _durationValue = _overallDurationMinutes ~/ 60;
        _durationUnit = 'hours';
      }
      // Load start time from first todo's scheduled time
      final startMins = widget.routine!.getStartTimeMinutes();
      if (startMins != null) {
        _routineStartTime = TimeOfDay(hour: startMins ~/ 60, minute: startMins % 60);
      }
      _linkedHabitId = widget.routine!.linkedHabitIds.isNotEmpty
          ? widget.routine!.linkedHabitIds.first
          : null;
      _linkHabitEnabled = _linkedHabitId != null;
    } else {
      // New routine: default start time to current time
      _routineStartTime = TimeOfDay.now();
    }

    // Load existing routines for real-time conflict checking
    _existingRoutines = await RoutineStorageService.loadRoutines(prefs: _prefs);

    setState(() => _loading = false);

    // Run initial conflict check after the frame so context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkTimeConflict();
    });
  }

  Future<List<HabitItem>> _loadAllHabitsFromStorage() async {
    final boards = await BoardsStorageService.loadBoards(prefs: _prefs);
    final List<HabitItem> habits = [];
    for (final board in boards) {
      final components = await VisionBoardComponentsStorageService.loadComponents(
        board.id,
        prefs: _prefs,
      );
      for (final comp in components) {
        habits.addAll(comp.habits);
      }
    }
    return habits;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _habitSearchController.dispose();
    super.dispose();
  }

  Future<void> _saveRoutine() async {
    // Clear previous non-time errors
    setState(() {
      _titleError = null;
      _stepsError = null;
    });

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Please enter a routine title');
      return;
    }

    // Filter out empty/blank steps before saving
    _todos.removeWhere((t) => t.title.trim().isEmpty);
    for (int i = 0; i < _todos.length; i++) {
      _todos[i] = _todos[i].copyWith(order: i);
    }

    if (_todos.isEmpty) {
      setState(() => _stepsError = 'Please add at least one step with a title');
      return;
    }

    // Re-check time conflict (in case routines changed externally)
    _checkTimeConflict();
    if (_timeConflictError != null) return;

    // Convert TimeOfDay to minutes since midnight for persistence
    final int? startTimeMins = _routineStartTime != null
        ? _routineStartTime!.hour * 60 + _routineStartTime!.minute
        : null;

    final routine = Routine(
      id: widget.routine?.id ?? 'routine_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      createdAtMs: widget.routine?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      iconCodePoint: _iconCodePoint,
      tileColorValue: _tileColorValue,
      todos: _todos,
      occurrenceType: _weekdays.length == 7 ? 'daily' : 'weekdays',
      weekdays: _weekdays.length < 7 ? _weekdays.toList() : null,
      timeMode: 'overall',
      overallDurationMinutes: _durationMinutes,
      linkedHabitIds: _linkedHabitId != null ? [_linkedHabitId!] : [],
      startTimeMinutes: startTimeMins,
    );

    final routines = await RoutineStorageService.loadRoutines(prefs: _prefs);
    final updated = widget.routine == null
        ? [routine, ...routines]
        : routines.map((r) => r.id == routine.id ? routine : r).toList();

    await RoutineStorageService.saveRoutines(updated, prefs: _prefs);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// Real-time conflict check against cached routines.
  /// Called whenever start time, duration, or weekdays change.
  void _checkTimeConflict() {
    if (_routineStartTime == null) {
      setState(() {
        _timeConflictError = null;
        _suggestedStartTime = null;
        _slotAvailableInfo = null;
      });
      return;
    }

    final startTimeMins = _routineStartTime!.hour * 60 + _routineStartTime!.minute;
    final duration = _durationMinutes;
    final newEndMins = startTimeMins + duration;
    final editingId = widget.routine?.id;

    final List<(int, int, String)> occupiedRanges = [];
    String? conflictTitle;

    for (final existing in _existingRoutines) {
      if (existing.id == editingId) continue;

      final existingStart = existing.getStartTimeMinutes();
      if (existingStart == null) continue;

      final existingWeekdays = existing.occurrenceType == 'daily'
          ? {0, 1, 2, 3, 4, 5, 6}
          : (existing.weekdays?.toSet() ?? {0, 1, 2, 3, 4, 5, 6});
      final sharesWeekday = _weekdays.intersection(existingWeekdays).isNotEmpty;
      if (!sharesWeekday) continue;

      final existingEnd = existingStart + existing.getTotalDurationMinutes();
      occupiedRanges.add((existingStart, existingEnd, existing.title));

      if (startTimeMins < existingEnd && existingStart < newEndMins) {
        conflictTitle = existing.title;
      }
    }

    // Format time range for display
    final endTime = TimeOfDay(hour: (newEndMins ~/ 60) % 24, minute: newEndMins % 60);

    if (conflictTitle != null) {
      occupiedRanges.sort((a, b) => a.$1.compareTo(b.$1));
      final suggested = _findNearestAvailableTime(
        startTimeMins, duration, occupiedRanges,
      );
      setState(() {
        _timeConflictError = 'Conflicts with "$conflictTitle"';
        _suggestedStartTime = suggested;
        _slotAvailableInfo = null;
      });
    } else {
      final startStr = _formatTime(_routineStartTime!);
      final endStr = _formatTime(endTime);
      setState(() {
        _timeConflictError = null;
        _suggestedStartTime = null;
        _slotAvailableInfo = '$startStr – $endStr is available';
      });
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }

  /// Find the nearest time slot that fits [duration] minutes, avoiding [occupied] ranges.
  /// Returns a TimeOfDay or null if no slot fits in a 24-hour day.
  TimeOfDay? _findNearestAvailableTime(
    int preferredStart, int duration, List<(int, int, String)> occupied,
  ) {
    const maxMins = 24 * 60;
    int? bestStart;
    int bestDist = maxMins;

    // Candidate: start of day (0)
    bool fits(int candidateStart) {
      if (candidateStart < 0 || candidateStart + duration > maxMins) return false;
      final candidateEnd = candidateStart + duration;
      for (final (s, e, _) in occupied) {
        if (candidateStart < e && s < candidateEnd) return false;
      }
      return true;
    }

    void tryCandidate(int c) {
      if (!fits(c)) return;
      final dist = (c - preferredStart).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestStart = c;
      }
    }

    // Try slot at start of day
    tryCandidate(0);
    // Try slot right after each occupied range
    for (final (_, e, _) in occupied) {
      tryCandidate(e);
    }
    // Try slot right before each occupied range
    for (final (s, _, _) in occupied) {
      tryCandidate(s - duration);
    }

    if (bestStart == null) return null;
    return TimeOfDay(hour: bestStart! ~/ 60, minute: bestStart! % 60);
  }

  void _addTodo() {
    final newTodo = RoutineTodoItem(
      id: 'todo_${DateTime.now().millisecondsSinceEpoch}',
      title: '',
      iconCodePoint: Icons.check_circle_outline.codePoint,
      order: _todos.length,
    );
    setState(() {
      _todos.add(newTodo);
      _expandedTodoId = newTodo.id;
      _stepsError = null;
    });
  }

  void _deleteTodo(RoutineTodoItem todo) {
    setState(() {
      _todos.removeWhere((t) => t.id == todo.id);
      for (int i = 0; i < _todos.length; i++) {
        _todos[i] = _todos[i].copyWith(order: i);
      }
    });
  }

  void _toggleLinkedHabit(HabitItem habit) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_linkedHabitId == habit.id) {
        // Deselecting -- do not clear time/duration (user may have customized)
        _linkedHabitId = null;
      } else {
        _linkedHabitId = habit.id;

        // Auto-fill start time from habit's reminderMinutes
        if (habit.reminderMinutes != null && habit.reminderMinutes! > 0) {
          _routineStartTime = TimeOfDay(
            hour: habit.reminderMinutes! ~/ 60,
            minute: habit.reminderMinutes! % 60,
          );
        }

        // Auto-fill duration from habit's timeBound
        if (habit.timeBound != null && habit.timeBound!.enabled && habit.timeBound!.durationMinutes > 0) {
          final totalMins = habit.timeBound!.durationMinutes;
          if (totalMins >= 60 && totalMins % 60 == 0) {
            _durationValue = totalMins ~/ 60;
            _durationUnit = 'hours';
          } else {
            _durationValue = totalMins;
            _durationUnit = 'minutes';
          }
        }
      }
    });
  }

  List<HabitItem> get _filteredHabits {
    if (_habitSearchQuery.isEmpty) return _allHabits;
    return _allHabits.where((h) {
      return h.name.toLowerCase().contains(_habitSearchQuery) ||
          (h.category?.toLowerCase().contains(_habitSearchQuery) ?? false);
    }).toList();
  }

  // ============================================================================
  // Build
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, topPadding + 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Title Section
                  _buildTitleSection(colorScheme),
                  const SizedBox(height: kSectionSpacing),

                  // 2. Schedule & Duration Section
                  _buildScheduleSection(colorScheme),
                  const SizedBox(height: kSectionSpacing),

                  // 4. Link Habits Section
                  if (_allHabits.isNotEmpty) ...[
                    _buildLinkHabitsSection(colorScheme),
                    const SizedBox(height: kSectionSpacing),
                  ],

                  // 5. Steps Section
                  _buildStepsSection(colorScheme),

                  // Bottom action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const Text('Cancel'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _saveRoutine,
                          icon: const Icon(Icons.check_rounded, size: 20),
                          label: Text(
                            widget.routine != null ? 'Save Routine' : 'Create Routine',
                            style: AppTypography.button(context).copyWith(fontWeight: FontWeight.w600),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: bottomPadding > 0 ? bottomPadding : 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Section Builders
  // ============================================================================

  Widget _buildTitleSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoListSection.insetGrouped(
          header: Text(
            'Title',
            style: AppTypography.caption(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          margin: EdgeInsets.zero,
          backgroundColor: colorScheme.surface,
          decoration: habitSectionDecoration(colorScheme),
          separatorColor: habitSectionSeparatorColor(colorScheme),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g., Morning Routine',
                  hintStyle: AppTypography.body(context).copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: AppTypography.body(context).copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (_titleError != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Text(
              _titleError!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildScheduleSection(ColorScheme colorScheme) {
    final displayStart = _routineStartTime ?? TimeOfDay.now();

    return CupertinoListSection.insetGrouped(
      header: Text(
        'Schedule & Duration',
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        // Weekday chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final selected = _weekdays.contains(index);
              return AnimatedDayChip(
                label: days[index],
                isSelected: selected,
                accentColor: colorScheme.onSurface,
                onTap: () {
                  setState(() {
                    if (_weekdays.contains(index)) {
                      _weekdays.remove(index);
                    } else {
                      _weekdays.add(index);
                    }
                  });
                  _checkTimeConflict();
                },
              );
            }),
          ),
        ),
        // Start time row
        _DurationStartTimeRow(
          displayStart: displayStart,
          errorText: _timeConflictError,
          suggestedTime: _suggestedStartTime,
          slotAvailableInfo: _slotAvailableInfo,
          onStartTimeChanged: (t) {
            setState(() => _routineStartTime = t);
            _checkTimeConflict();
          },
          onSuggestionTap: _suggestedStartTime != null ? () {
            setState(() => _routineStartTime = _suggestedStartTime);
            _checkTimeConflict();
          } : null,
        ),
        // Duration row
        _DurationValueRow(
          durationValue: _durationValue,
          durationUnit: _durationUnit,
          onDurationChanged: (value, unit) {
            setState(() {
              _durationValue = value;
              _durationUnit = unit;
            });
            _checkTimeConflict();
          },
        ),
      ],
    );
  }

  void _onLinkHabitToggle(bool value) {
    setState(() {
      _linkHabitEnabled = value;
      if (!value) {
        _linkedHabitId = null;
        _habitSearchController.clear();
        _habitSearchQuery = '';
      }
    });
  }

  Widget _buildLinkHabitsSection(ColorScheme colorScheme) {
    final filtered = _filteredHabits;
    final linkedHabit = _linkedHabitId != null
        ? _allHabits.where((h) => h.id == _linkedHabitId).firstOrNull
        : null;

    return CupertinoListSection.insetGrouped(
      header: Text(
        'Link Habit',
        style: AppTypography.caption(context).copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),
      margin: EdgeInsets.zero,
      backgroundColor: colorScheme.surface,
      decoration: habitSectionDecoration(colorScheme),
      separatorColor: habitSectionSeparatorColor(colorScheme),
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CupertinoListTile.notched(
              leading: Icon(
                Icons.link_rounded,
                color: colorScheme.onSurfaceVariant,
                size: 28,
              ),
              title: Text(
                'Link to an existing habit',
                style: AppTypography.body(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: CupertinoSwitch(
                value: _linkHabitEnabled,
                onChanged: _onLinkHabitToggle,
                activeTrackColor: colorScheme.primary,
              ),
            ),
            if (_linkHabitEnabled)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search field
                    TextField(
                      controller: _habitSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search habits...',
                        hintStyle: AppTypography.body(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        suffixIcon: _habitSearchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () => _habitSearchController.clear(),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 18,
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: colorScheme.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                      ),
                      style: AppTypography.body(context).copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    // Habit list
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: filtered.length > 4 ? 220 : filtered.length * 56.0,
                      ),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  _habitSearchQuery.isNotEmpty
                                      ? 'No habits match your search'
                                      : 'No habits available',
                                  style: AppTypography.bodySmall(context).copyWith(
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final habit = filtered[index];
                                final isLinked = _linkedHabitId == habit.id;
                                final iconIndex = habit.iconIndex;
                                final iconData = iconIndex != null && iconIndex < habitIcons.length
                                    ? habitIcons[iconIndex].$1
                                    : Icons.check_circle_outline;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _toggleLinkedHabit(habit),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isLinked
                                            ? colorScheme.primaryContainer.withValues(alpha: 0.2)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: isLinked
                                                  ? colorScheme.primary
                                                  : colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              iconData,
                                              size: 18,
                                              color: isLinked
                                                  ? colorScheme.onPrimary
                                                  : colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  habit.name,
                                                  style: AppTypography.body(context).copyWith(
                                                    fontWeight: isLinked ? FontWeight.w600 : FontWeight.w400,
                                                    color: isLinked
                                                        ? colorScheme.primary
                                                        : colorScheme.onSurface,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (habit.category != null)
                                                  Text(
                                                    habit.category!,
                                                    style: AppTypography.caption(context).copyWith(
                                                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 200),
                                            transitionBuilder: (child, animation) =>
                                                ScaleTransition(scale: animation, child: child),
                                            child: isLinked
                                                ? Container(
                                                    key: const ValueKey('linked'),
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: colorScheme.primary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      Icons.check_rounded,
                                                      size: 16,
                                                      color: colorScheme.onPrimary,
                                                    ),
                                                  )
                                                : Container(
                                                    key: const ValueKey('unlinked'),
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: colorScheme.outlineVariant,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                  ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepsSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header row
        Row(
          children: [
            Text(
              'Steps',
              style: AppTypography.caption(context).copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _addTodo,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: colorScheme.onPrimary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_stepsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _stepsError!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ),
        const SizedBox(height: 12),

        if (_todos.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.playlist_add_rounded,
                    size: 32,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No steps yet',
                  style: AppTypography.body(context).copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Add steps or link habits to build your routine',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: List.generate(_todos.length, (index) {
              final todo = _todos[index];
              return _InlineEditableTodoItem(
                key: ValueKey(todo.id),
                todo: todo,
                stepNumber: index + 1,
                isExpanded: _expandedTodoId == todo.id,
                showDurationStepper: false,
                onToggleExpand: () {
                  setState(() {
                    _expandedTodoId = _expandedTodoId == todo.id ? null : todo.id;
                  });
                },
                onUpdate: (updatedTodo) {
                  setState(() {
                    final idx = _todos.indexWhere((t) => t.id == updatedTodo.id);
                    if (idx >= 0) {
                      _todos[idx] = updatedTodo;
                    }
                  });
                },
                onDelete: () => _deleteTodo(todo),
              );
            }),
          ),
      ],
    );
  }

}

// ============================================================================
// Duration Section Helper Widgets
// ============================================================================

class _DurationStartTimeRow extends StatefulWidget {
  final TimeOfDay displayStart;
  final ValueChanged<TimeOfDay?> onStartTimeChanged;
  final String? errorText;
  final TimeOfDay? suggestedTime;
  final VoidCallback? onSuggestionTap;
  final String? slotAvailableInfo;

  const _DurationStartTimeRow({
    required this.displayStart,
    required this.onStartTimeChanged,
    this.errorText,
    this.suggestedTime,
    this.onSuggestionTap,
    this.slotAvailableInfo,
  });

  @override
  State<_DurationStartTimeRow> createState() => _DurationStartTimeRowState();
}

class _DurationStartTimeRowState extends State<_DurationStartTimeRow> {
  bool _expanded = false;
  late DateTime _pendingDateTime;

  void _syncPending() {
    final now = DateTime.now();
    _pendingDateTime = DateTime(
      now.year, now.month, now.day,
      widget.displayStart.hour, widget.displayStart.minute,
    );
  }

  @override
  void initState() {
    super.initState();
    _syncPending();
  }

  @override
  void didUpdateWidget(_DurationStartTimeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_expanded) _syncPending();
  }

  void _confirm() {
    widget.onStartTimeChanged(TimeOfDay.fromDateTime(_pendingDateTime));
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                if (_expanded) {
                  _confirm();
                } else {
                  _syncPending();
                  _expanded = true;
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 20, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Start time',
                          style: AppTypography.bodySmall(context).copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          widget.displayStart.format(context),
                          style: AppTypography.body(context).copyWith(
                            color: widget.errorText != null ? colorScheme.error : colorScheme.onSurface,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.errorText != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.errorText!,
                            style: TextStyle(color: colorScheme.error, fontSize: 12),
                          ),
                          if (widget.suggestedTime != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: GestureDetector(
                                onTap: widget.onSuggestionTap,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Try ${widget.suggestedTime!.format(context)}',
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ] else if (widget.slotAvailableInfo != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 14, color: colorScheme.primary),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.slotAvailableInfo!,
                                  style: TextStyle(
                                    color: colorScheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
          CupertinoTheme(
            data: CupertinoThemeData(
              brightness: theme.brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
            ),
            child: SizedBox(
              height: 180,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: _pendingDateTime,
                use24hFormat: MediaQuery.of(context).alwaysUse24HourFormat,
                minuteInterval: 1,
                onDateTimeChanged: (v) => setState(() => _pendingDateTime = v),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _confirm,
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DurationValueRow extends StatefulWidget {
  final int durationValue;
  final String durationUnit;
  final void Function(int value, String unit) onDurationChanged;

  const _DurationValueRow({
    required this.durationValue,
    required this.durationUnit,
    required this.onDurationChanged,
  });

  @override
  State<_DurationValueRow> createState() => _DurationValueRowState();
}

class _DurationValueRowState extends State<_DurationValueRow> {
  bool _expanded = false;
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.durationValue.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        setState(() => _expanded = false);
      }
    });
  }

  @override
  void didUpdateWidget(_DurationValueRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.durationValue != widget.durationValue &&
        _controller.text != widget.durationValue.toString()) {
      _controller.text = widget.durationValue.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final parsed = int.tryParse(text);
    final value = parsed ?? 0;
    final maxVal = widget.durationUnit == 'hours' ? 24 : 1440;
    widget.onDurationChanged(value.clamp(0, maxVal), widget.durationUnit);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _expanded = true);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Duration',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      _expanded
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 48,
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    autofocus: true,
                                    style: AppTypography.body(context).copyWith(
                                      fontSize: 18,
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '15',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(color: colorScheme.primary, width: 1),
                                      ),
                                    ),
                                    onChanged: _onTextChanged,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: widget.durationUnit,
                                    isExpanded: false,
                                    style: AppTypography.body(context).copyWith(
                                      fontSize: 18,
                                      color: colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 'minutes', child: Text('min')),
                                      DropdownMenuItem(value: 'hours', child: Text('hr')),
                                    ],
                                    onChanged: (unit) {
                                      if (unit != null) {
                                        widget.onDurationChanged(widget.durationValue, unit);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              '${widget.durationValue} ${widget.durationUnit == 'hours' ? 'hr' : 'min'}',
                              style: AppTypography.body(context).copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Inline Editable Todo Item (with linked habit indicator)
// ============================================================================

class _InlineEditableTodoItem extends StatefulWidget {
  final RoutineTodoItem todo;
  final int stepNumber;
  final bool isExpanded;
  final bool showDurationStepper;
  final VoidCallback onToggleExpand;
  final ValueChanged<RoutineTodoItem> onUpdate;
  final VoidCallback onDelete;

  const _InlineEditableTodoItem({
    super.key,
    required this.todo,
    required this.stepNumber,
    required this.isExpanded,
    required this.showDurationStepper,
    required this.onToggleExpand,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  State<_InlineEditableTodoItem> createState() => _InlineEditableTodoItemState();
}

class _InlineEditableTodoItemState extends State<_InlineEditableTodoItem> {
  late TextEditingController _titleController;
  late int _iconCodePoint;
  late int _durationMinutes;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.todo.title);
    _iconCodePoint = widget.todo.iconCodePoint;
    _durationMinutes = widget.todo.durationMinutes ?? 5;
  }

  @override
  void didUpdateWidget(_InlineEditableTodoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.id != widget.todo.id) {
      _titleController.text = widget.todo.title;
      _iconCodePoint = widget.todo.iconCodePoint;
      _durationMinutes = widget.todo.durationMinutes ?? 5;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _updateTodo() {
    final title = _titleController.text.trim();
    widget.onUpdate(widget.todo.copyWith(
      title: title,
      iconCodePoint: _iconCodePoint,
      durationMinutes: widget.showDurationStepper ? _durationMinutes : null,
    ));
  }

  void _onTitleChanged(String value) {
    final title = value.trim();
    if (title.isNotEmpty) {
      final newIcon = IconService.getIconCodePointForTitle(title);
      if (newIcon != _iconCodePoint) {
        setState(() => _iconCodePoint = newIcon);
      }
    }
    _updateTodo();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = IconService.iconFromCodePoint(_iconCodePoint);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: widget.isExpanded
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isExpanded ? colorScheme.primary.withValues(alpha: 0.3) : colorScheme.outlineVariant,
          width: widget.isExpanded ? 1.5 : 1,
        ),
        boxShadow: widget.isExpanded
            ? [BoxShadow(color: colorScheme.primary.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onToggleExpand,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: widget.isExpanded ? colorScheme.primary : colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: widget.isExpanded ? colorScheme.onPrimary : colorScheme.onPrimaryContainer,
                          size: 22,
                        ),
                      ),
                      Positioned(
                        top: -6,
                        left: -6,
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.surface, width: 2),
                          ),
                          child: Text(
                            '${widget.stepNumber}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onPrimary,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Step title...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w500),
                    onChanged: _onTitleChanged,
                    onTap: () { if (!widget.isExpanded) widget.onToggleExpand(); },
                  ),
                ),
                if (widget.isExpanded)
                  IconButton(
                    icon: Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 24),
                    onPressed: widget.onToggleExpand,
                    tooltip: 'Done',
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error.withValues(alpha: 0.7), size: 20),
                  onPressed: widget.onDelete,
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: widget.isExpanded ? _buildExpandedControls(colorScheme) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedControls(ColorScheme colorScheme) {
    if (widget.showDurationStepper) {
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          children: [
            Container(
              height: 1,
              margin: const EdgeInsets.only(bottom: 12),
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _buildDurationStepper(colorScheme),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDurationStepper(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colorScheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: colorScheme.outlineVariant)),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.hourglass_empty_rounded, color: colorScheme.onSurfaceVariant, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Timer', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text('$_durationMinutes min', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
        ])),
        Container(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8), border: Border.all(color: colorScheme.outlineVariant)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Material(color: Colors.transparent, child: InkWell(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
              onTap: () { if (_durationMinutes > 1) { setState(() => _durationMinutes--); _updateTodo(); } },
              child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.remove_rounded, size: 16, color: _durationMinutes > 1 ? colorScheme.onSurface : colorScheme.outlineVariant)),
            )),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Container(key: ValueKey(_durationMinutes), width: 32, alignment: Alignment.center, child: Text('$_durationMinutes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.primary))),
            ),
            Material(color: Colors.transparent, child: InkWell(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
              onTap: () { setState(() => _durationMinutes++); _updateTodo(); },
              child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.add_rounded, size: 16, color: colorScheme.onSurface)),
            )),
          ]),
        ),
      ]),
    );
  }
}
