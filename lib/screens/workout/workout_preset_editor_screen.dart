import 'package:flutter/material.dart';

import '../../models/action_step_template.dart';
import '../../models/habit_action_step.dart';
import '../../utils/app_typography.dart';

/// Workout-specific preset editor.
///
/// Lets the user rename the plan and edit per-exercise details
/// (name, sets × reps label, rest, muscle group) without losing
/// the structured workout layout.
class WorkoutPresetEditorScreen extends StatefulWidget {
  final ActionStepTemplate template;

  const WorkoutPresetEditorScreen({super.key, required this.template});

  @override
  State<WorkoutPresetEditorScreen> createState() =>
      _WorkoutPresetEditorScreenState();
}

class _WorkoutPresetEditorScreenState extends State<WorkoutPresetEditorScreen> {
  static const int _allDaysFilter = 0;
  static const List<int> _weekdayOrder = <int>[
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  late final TextEditingController _nameCtrl;
  late List<_ExerciseEntry> _exercises;
  late Map<int, _DaypartSelection> _daypartByWeekday;
  late Map<int, Set<String>> _musclesByWeekday;
  int _selectedDayFilter = _allDaysFilter;
  static const List<String> _muscleGroups = <String>[
    'Chest',
    'Back',
    'Shoulders',
    'Legs',
    'Arms (Biceps & Triceps)',
    'Core',
    'Rest day',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template.name);
    final parsed = _parseTemplateSteps(widget.template.steps);
    _exercises = parsed.exercises;
    _daypartByWeekday = parsed.dayparts;
    _musclesByWeekday = parsed.muscles;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final e in _exercises) {
      e.dispose();
    }
    super.dispose();
  }

  void _addExercise() {
    final day = _selectedDayFilter;
    if (day == _allDaysFilter) return;
    final insertAt = _exercises.lastIndexWhere((e) => e.weekday == day);
    final order = insertAt >= 0 ? insertAt + 1 : _exercises.length;
    final plannerDay = _plannerDayKey(day);
    final entry = _ExerciseEntry.blank(
      order: order,
      weekday: day,
      plannerDay: plannerDay,
    );
    setState(() {
      if (insertAt >= 0) {
        _exercises.insert(order, entry);
      } else {
        _exercises.add(entry);
      }
      for (int i = 0; i < _exercises.length; i++) {
        _exercises[i] = _exercises[i].withOrder(i);
      }
    });
  }

  void _showMuscleSelector(int weekday) {
    final selected = {...(_musclesByWeekday[weekday] ?? <String>{})};
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Select Muscle Groups - ${_weekdayLabel(weekday)}',
                      style: AppTypography.heading3(context),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final option in _muscleGroups)
                          CheckboxListTile(
                            value: selected.contains(option),
                            title: Text(option),
                            onChanged: (checked) {
                              setSheetState(() {
                                if (checked == true) {
                                  if (option == 'Rest day') {
                                    selected
                                      ..clear()
                                      ..add(option);
                                  } else {
                                    selected
                                      ..remove('Rest day')
                                      ..add(option);
                                  }
                                } else {
                                  selected.remove(option);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _musclesByWeekday[weekday] = selected;
                          });
                          _normalizeExerciseMusclesForDay(weekday);
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  List<String> _muscleOptionsForDay(int weekday) {
    final selected = (_musclesByWeekday[weekday] ?? <String>{})
        .where((m) => m.trim().isNotEmpty && m != 'Rest day')
        .toList();
    selected.sort();
    return selected;
  }

  void _setExerciseMuscle(int index, String? value) {
    setState(() {
      _exercises[index] = _exercises[index].copyWith(selectedMuscle: value);
    });
  }

  bool _isSelectedMuscleValidForDay(_ExerciseEntry entry) {
    final weekday = entry.weekday;
    if (weekday == null) return true;
    final selected = (entry.selectedMuscle ?? '').trim();
    if (selected.isEmpty) return true;
    final options = _muscleOptionsForDay(weekday);
    return options.contains(selected);
  }

  void _normalizeExerciseMusclesForDay(int weekday) {
    final allowed = _muscleOptionsForDay(weekday).toSet();
    setState(() {
      for (int i = 0; i < _exercises.length; i++) {
        final entry = _exercises[i];
        if (entry.weekday != weekday) continue;
        final selected = (entry.selectedMuscle ?? '').trim();
        if (selected.isEmpty) continue;
        if (!allowed.contains(selected)) {
          _exercises[i] = entry.copyWith(selectedMuscle: null);
        }
      }
    });
  }

  void _removeExercise(int index) {
    final entry = _exercises[index];
    entry.dispose();
    setState(() {
      _exercises.removeAt(index);
      for (int i = 0; i < _exercises.length; i++) {
        _exercises[i] = _exercises[i].withOrder(i);
      }
    });
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preset name is required.')));
      return;
    }

    final cleaned = <_CompiledExercise>[];
    for (int i = 0; i < _exercises.length; i++) {
      final e = _exercises[i];
      final title = e.titleCtrl.text.trim();
      if (title.isEmpty) continue;
      final sets = e.setsCtrl.text.trim();
      final reps = e.repsCtrl.text.trim();
      if (sets.isNotEmpty && reps.isNotEmpty) {
        if (!RegExp(r'^\d+(?:-\d+)*$').hasMatch(reps)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Reps for "$title" must use hyphen format like 10-12-8.',
              ),
            ),
          );
          return;
        }
        final setCount = int.tryParse(sets);
        if (setCount != null) {
          final segmentCount = reps
              .split('-')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .length;
          if (segmentCount != setCount) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Reps for "$title" must have $setCount values separated by hyphens.',
                ),
              ),
            );
            return;
          }
        }
      }
      final dayOptions = e.weekday == null
          ? const <String>[]
          : _muscleOptionsForDay(e.weekday!);
      final selectedMuscle = (e.selectedMuscle ?? '').trim();
      final resolvedMuscle = selectedMuscle.isNotEmpty
          ? selectedMuscle
          : (dayOptions.isNotEmpty
                ? dayOptions.first
                : (e.step.productType ?? ''));
      cleaned.add(
        _CompiledExercise(
          weekday: e.weekday,
          step: HabitActionStep(
            id: e.step.id,
            title: title,
            iconCodePoint: e.step.iconCodePoint,
            order: i,
            stepLabel: _composeSetsRepsLabel(
              sets: sets,
              reps: reps,
              fallback: e.step.stepLabel,
            ),
            productType: resolvedMuscle,
            productName: e.step.productName,
            notes: e.step.notes,
            plannerDay: e.step.plannerDay,
            plannerWeek: e.step.plannerWeek,
          ),
        ),
      );
    }

    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
      );
      return;
    }

    final expanded = <HabitActionStep>[];
    for (final item in cleaned) {
      final weekday = item.weekday;
      if (weekday == null) {
        expanded.add(item.step.copyWith(order: expanded.length));
        continue;
      }
      final daypart = _daypartByWeekday[weekday] ?? const _DaypartSelection();
      final dayKey = _plannerDayKey(weekday);
      final baseId = _baseStepId(item.step.id);

      if (daypart.morning) {
        expanded.add(
          item.step.copyWith(
            id: '${baseId}_am',
            plannerDay: '${dayKey}_am',
            order: expanded.length,
          ),
        );
      }
      if (daypart.evening) {
        expanded.add(
          item.step.copyWith(
            id: '${baseId}_pm',
            plannerDay: '${dayKey}_pm',
            order: expanded.length,
          ),
        );
      }
    }

    if (expanded.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enable Morning and/or Evening for at least one workout day.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      ActionStepTemplate(
        id: widget.template.id,
        name: name,
        category: widget.template.category,
        schemaVersion: widget.template.schemaVersion,
        templateVersion: widget.template.templateVersion,
        setKey: widget.template.setKey,
        isOfficial: widget.template.isOfficial,
        status: widget.template.status,
        createdByUserId: widget.template.createdByUserId,
        steps: expanded,
        metadata: widget.template.metadata,
      ),
    );
  }

  String _composeSetsRepsLabel({
    required String sets,
    required String reps,
    String? fallback,
  }) {
    if (sets.isEmpty && reps.isEmpty) return fallback ?? '';
    if (sets.isEmpty) return reps;
    if (reps.isEmpty) return sets;
    return '$sets × $reps';
  }

  _ParsedWorkoutState _parseTemplateSteps(List<HabitActionStep> steps) {
    final dayparts = <int, _DaypartSelection>{
      for (final day in _weekdayOrder) day: const _DaypartSelection(),
    };
    final muscles = <int, Set<String>>{
      for (final day in _weekdayOrder) day: <String>{},
    };
    final exercises = <_ExerciseEntry>[];
    final seen = <String>{};

    for (final step in steps) {
      final weekdays = _extractWeekdaysFromPlannerKey(step.plannerDay);
      final part = _daypartFromPlannerKey(step.plannerDay);
      final effectiveDays = weekdays.isEmpty ? <int?>[null] : weekdays;

      for (final weekday in effectiveDays) {
        if (weekday != null) {
          final current = dayparts[weekday] ?? const _DaypartSelection();
          if (part == _WorkoutDaypart.morning) {
            dayparts[weekday] = current.copyWith(morning: true);
          } else if (part == _WorkoutDaypart.evening) {
            dayparts[weekday] = current.copyWith(evening: true);
          } else {
            // Legacy planner day without daypart maps to morning by default.
            dayparts[weekday] = current.copyWith(morning: true);
          }
          final muscle = (step.productType ?? '').trim();
          if (muscle.isNotEmpty) {
            muscles.putIfAbsent(weekday, () => <String>{}).add(muscle);
          }
        }
        final dayKey = weekday?.toString() ?? '';
        final dedupeKey = [
          dayKey,
          step.title.trim().toLowerCase(),
          (step.stepLabel ?? '').trim().toLowerCase(),
          (step.productType ?? '').trim().toLowerCase(),
          (step.productName ?? '').trim().toLowerCase(),
        ].join('|');
        if (!seen.add(dedupeKey)) continue;
        final resolvedPlannerDay = weekday == null
            ? step.plannerDay
            : _plannerDayKey(weekday);
        exercises.add(
          _ExerciseEntry.fromStep(
            step,
            assignedWeekday: weekday,
            plannerDay: resolvedPlannerDay,
          ),
        );
      }
    }

    if (steps.isNotEmpty && exercises.isEmpty) {
      exercises.addAll(steps.map(_ExerciseEntry.fromStep));
    }
    for (int i = 0; i < exercises.length; i++) {
      exercises[i].withOrder(i);
    }

    return _ParsedWorkoutState(
      exercises: exercises,
      dayparts: dayparts,
      muscles: muscles,
    );
  }

  _WorkoutDaypart? _daypartFromPlannerKey(String? rawValue) {
    final raw = (rawValue ?? '').trim().toLowerCase();
    if (raw.isEmpty) return null;
    if (RegExp(r'(^|[_\s-])am($|[_\s-])').hasMatch(raw)) {
      return _WorkoutDaypart.morning;
    }
    if (RegExp(r'(^|[_\s-])pm($|[_\s-])').hasMatch(raw)) {
      return _WorkoutDaypart.evening;
    }
    return null;
  }

  String _plannerDayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      case DateTime.saturday:
        return 'sat';
      case DateTime.sunday:
      default:
        return 'sun';
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
      default:
        return 'Sunday';
    }
  }

  String _muscleLabelForDay(int weekday) {
    final muscles = _muscleOptionsForDay(weekday);
    if (muscles.isNotEmpty) return muscles.join(', ');
    final selected = _musclesByWeekday[weekday] ?? <String>{};
    if (selected.contains('Rest day')) return 'Rest day';
    return 'Not selected';
  }

  List<int> _extractWeekdaysFromPlannerKey(String? rawValue) {
    final raw = (rawValue ?? '').trim().toLowerCase();
    if (raw.isEmpty) return const [];
    final tokenMap = <String, int>{
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
    final matches = RegExp(
      r'\b(mon(?:day)?|tue(?:s|sday)?|wed(?:nesday)?|thu(?:r|rs|rsday)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b',
    ).allMatches(raw);
    final days = <int>{};
    for (final match in matches) {
      final token = match.group(0);
      if (token == null) continue;
      final mapped = tokenMap[token];
      if (mapped != null) days.add(mapped);
    }
    if (days.isNotEmpty) {
      final sorted = days.toList()..sort();
      return sorted;
    }
    final weekday = HabitActionStep.weekdayFromPlannerKey(raw);
    if (weekday != null) return [weekday];
    return const [];
  }

  String _baseStepId(String rawId) {
    return rawId.replaceFirst(
      RegExp(r'([_-])(am|pm)$', caseSensitive: false),
      '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Workout Plan',
          style: AppTypography.heading3(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: _selectedDayFilter == _allDaysFilter
          ? null
          : FloatingActionButton.extended(
              onPressed: _addExercise,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Exercise'),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Plan name
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Plan name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Daypart Plan', style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Enable Morning and/or Evening for each muscle-group day.',
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox()),
                        SizedBox(
                          width: 56,
                          child: Text(
                            'AM',
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            'PM',
                            textAlign: TextAlign.center,
                            style: textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final weekday in _weekdayOrder)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _weekdayLabel(weekday),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () => _showMuscleSelector(weekday),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: cs.outline),
                                      borderRadius: BorderRadius.circular(8),
                                      color: cs.surface,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _muscleLabelForDay(weekday),
                                            style: textTheme.bodySmall
                                                ?.copyWith(color: cs.onSurface),
                                          ),
                                        ),
                                        Icon(
                                          Icons.checklist_rounded,
                                          size: 18,
                                          color: cs.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Switch(
                              value:
                                  _daypartByWeekday[weekday]?.morning ?? false,
                              onChanged: (value) {
                                setState(() {
                                  final current =
                                      _daypartByWeekday[weekday] ??
                                      const _DaypartSelection();
                                  _daypartByWeekday[weekday] = current.copyWith(
                                    morning: value,
                                  );
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Switch(
                              value:
                                  _daypartByWeekday[weekday]?.evening ?? false,
                              onChanged: (value) {
                                setState(() {
                                  final current =
                                      _daypartByWeekday[weekday] ??
                                      const _DaypartSelection();
                                  _daypartByWeekday[weekday] = current.copyWith(
                                    evening: value,
                                  );
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // "Default" notice
          if (widget.template.isOfficial)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 16, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is a Default preset. Your edits create a personal copy.',
                      style: textTheme.bodySmall?.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('Exercises', style: textTheme.titleMedium)),
              DropdownButton<int>(
                value: _selectedDayFilter,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedDayFilter = value);
                },
                items: [
                  const DropdownMenuItem<int>(
                    value: _allDaysFilter,
                    child: Text('All Days'),
                  ),
                  ..._weekdayOrder.map(
                    (day) => DropdownMenuItem<int>(
                      value: day,
                      child: Text(_weekdayLabel(day)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final day in _weekdayOrder) ...[
            if ((_selectedDayFilter == _allDaysFilter ||
                    _selectedDayFilter == day) &&
                _exercises.any((e) => e.weekday == day)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
                child: Row(
                  children: [
                    Text(
                      _weekdayLabel(day),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _muscleLabelForDay(day),
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < _exercises.length; i++)
                if (_exercises[i].weekday == day)
                  _ExerciseCard(
                    index: i,
                    entry: _exercises[i],
                    muscleOptions: _muscleOptionsForDay(day),
                    isSelectedMuscleValid: _isSelectedMuscleValidForDay(
                      _exercises[i],
                    ),
                    onMuscleChanged: (value) => _setExerciseMuscle(i, value),
                    onRemove: () => _removeExercise(i),
                  ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Data holder ───────────────────────────────────────────────────────────────

class _ExerciseEntry {
  final HabitActionStep step;
  final TextEditingController titleCtrl;
  final TextEditingController setsCtrl;
  final TextEditingController repsCtrl;
  final int? weekday;
  final String? selectedMuscle;
  int order;

  _ExerciseEntry({
    required this.step,
    required this.titleCtrl,
    required this.setsCtrl,
    required this.repsCtrl,
    required this.weekday,
    required this.selectedMuscle,
    required this.order,
  });

  factory _ExerciseEntry.fromStep(
    HabitActionStep step, {
    int? assignedWeekday,
    String? plannerDay,
  }) {
    final parsed = _parseStepLabel(step.stepLabel);
    return _ExerciseEntry(
      step: plannerDay == null ? step : step.copyWith(plannerDay: plannerDay),
      titleCtrl: TextEditingController(text: step.title),
      setsCtrl: TextEditingController(text: parsed.$1),
      repsCtrl: TextEditingController(text: parsed.$2),
      weekday:
          assignedWeekday ??
          HabitActionStep.weekdayFromPlannerKey(step.plannerDay ?? ''),
      selectedMuscle: (step.productType ?? '').trim().isEmpty
          ? null
          : step.productType?.trim(),
      order: step.order,
    );
  }

  factory _ExerciseEntry.blank({
    required int order,
    int? weekday,
    String? plannerDay,
  }) {
    final id = 'custom-ex-${DateTime.now().microsecondsSinceEpoch}';
    return _ExerciseEntry(
      step: HabitActionStep(
        id: id,
        title: '',
        iconCodePoint: 58728,
        order: order,
        plannerDay: plannerDay,
      ),
      titleCtrl: TextEditingController(),
      setsCtrl: TextEditingController(),
      repsCtrl: TextEditingController(),
      weekday: weekday,
      selectedMuscle: null,
      order: order,
    );
  }

  _ExerciseEntry withOrder(int newOrder) {
    order = newOrder;
    return this;
  }

  _ExerciseEntry copyWith({HabitActionStep? step, String? selectedMuscle}) {
    return _ExerciseEntry(
      step: step ?? this.step,
      titleCtrl: titleCtrl,
      setsCtrl: setsCtrl,
      repsCtrl: repsCtrl,
      weekday: weekday,
      selectedMuscle: selectedMuscle,
      order: order,
    );
  }

  void dispose() {
    titleCtrl.dispose();
    setsCtrl.dispose();
    repsCtrl.dispose();
  }

  static (String, String) _parseStepLabel(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return ('', '');
    final match = RegExp(r'^\s*(\d+)\s*[x×]\s*(.+)\s*$').firstMatch(text);
    if (match != null) {
      return (match.group(1)?.trim() ?? '', match.group(2)?.trim() ?? '');
    }
    return ('', text);
  }
}

class _ParsedWorkoutState {
  final List<_ExerciseEntry> exercises;
  final Map<int, _DaypartSelection> dayparts;
  final Map<int, Set<String>> muscles;

  const _ParsedWorkoutState({
    required this.exercises,
    required this.dayparts,
    required this.muscles,
  });
}

enum _WorkoutDaypart { morning, evening }

class _DaypartSelection {
  final bool morning;
  final bool evening;

  const _DaypartSelection({this.morning = false, this.evening = false});

  _DaypartSelection copyWith({bool? morning, bool? evening}) {
    return _DaypartSelection(
      morning: morning ?? this.morning,
      evening: evening ?? this.evening,
    );
  }
}

class _CompiledExercise {
  final HabitActionStep step;
  final int? weekday;

  const _CompiledExercise({required this.step, required this.weekday});
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final int index;
  final _ExerciseEntry entry;
  final List<String> muscleOptions;
  final bool isSelectedMuscleValid;
  final ValueChanged<String?> onMuscleChanged;
  final VoidCallback onRemove;

  const _ExerciseCard({
    required this.index,
    required this.entry,
    required this.muscleOptions,
    required this.isSelectedMuscleValid,
    required this.onMuscleChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: entry.titleCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Exercise name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: onRemove,
                  icon: Icon(
                    Icons.delete_outline,
                    color: cs.error.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: entry.setsCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Sets',
                      hintText: 'e.g. 3',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: entry.repsCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Reps',
                      hintText: 'e.g. 10-12',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (muscleOptions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  'Select day-level muscle groups first.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: isSelectedMuscleValid
                    ? entry.selectedMuscle
                    : null,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Muscle Group',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Select muscle group'),
                items: muscleOptions
                    .map(
                      (option) => DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: onMuscleChanged,
              ),
            if ((entry.step.plannerDay ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Day: ${_formatPlannerDayLabel(entry.step.plannerDay ?? '')}',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatPlannerDayLabel(String rawValue) {
    final raw = rawValue.trim().toLowerCase();
    if (raw.isEmpty) return rawValue;
    final weekday = HabitActionStep.weekdayFromPlannerKey(raw);
    if (weekday == null) return rawValue;
    String day;
    switch (weekday) {
      case DateTime.monday:
        day = 'Mon';
        break;
      case DateTime.tuesday:
        day = 'Tue';
        break;
      case DateTime.wednesday:
        day = 'Wed';
        break;
      case DateTime.thursday:
        day = 'Thu';
        break;
      case DateTime.friday:
        day = 'Fri';
        break;
      case DateTime.saturday:
        day = 'Sat';
        break;
      case DateTime.sunday:
        day = 'Sun';
        break;
      default:
        day = '';
    }
    if (RegExp(r'(^|[_\s-])am($|[_\s-])').hasMatch(raw)) {
      return '$day • Morning';
    }
    if (RegExp(r'(^|[_\s-])pm($|[_\s-])').hasMatch(raw)) {
      return '$day • Evening';
    }
    return day;
  }
}
