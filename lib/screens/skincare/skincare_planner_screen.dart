import 'dart:ui';

import 'package:flutter/material.dart';

import '../../models/action_step_template.dart';
import '../../models/habit_action_step.dart';
import '../../models/skincare_planner.dart';
import '../../presets/services/skincare_preset_compiler.dart';
import '../../services/preset_habit_creation_service.dart';
import '../../services/skincare_planner_storage_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

class SkincarePlannerScreen extends StatefulWidget {
  final ActionStepTemplate? initialTemplate;

  const SkincarePlannerScreen({super.key, this.initialTemplate});

  @override
  State<SkincarePlannerScreen> createState() => _SkincarePlannerScreenState();
}

class _SkincarePlannerScreenState extends State<SkincarePlannerScreen> {
  static const double _previewActionButtonHeight = 52.0;
  bool _loading = true;
  SkincarePlanner? _planner;
  String? _morningRoutineSetInput;
  String? _eveningRoutineSetInput;
  String? _weeklyPlanInput;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stored = await SkincarePlannerStorageService.loadOrDefault();
    final activePlan = _activeWeeklyPlan(stored);
    final weeklySnapshot = <String, Map<String, Object?>>{};
    for (final day in SkincarePlanner.weekDays) {
      final dayPlan =
          activePlan.weeklyPlanByDay[day] ?? SkincareWeeklyDayPlan(dayKey: day);
      weeklySnapshot[day] = {
        'morningSourceId': dayPlan.morningSourceId,
        'eveningSourceId': dayPlan.eveningSourceId,
      };
    }
    if (!mounted) return;
    setState(() {
      _planner = stored;
      _loading = false;
    });
  }

  Future<void> _save(SkincarePlanner planner) async {
    setState(() => _planner = planner);
    await SkincarePlannerStorageService.save(planner);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updatePlanner(
    SkincarePlanner Function(SkincarePlanner current) updater,
  ) async {
    final current = _planner;
    if (current == null) return;
    final next = updater(current);
    await _save(next);
  }

  Future<void> _setRoutineEnabled({
    required bool isMorning,
    required bool enabled,
  }) async {
    final planner = _planner;
    if (planner == null) return;
    final currentMorning = planner.morningRoutineEnabled;
    final currentEvening = planner.eveningRoutineEnabled;
    final nextMorning = isMorning ? enabled : currentMorning;
    final nextEvening = isMorning ? currentEvening : enabled;
    if (!nextMorning && !nextEvening) {
      _showError('At least one routine must remain enabled.');
      return;
    }

    await _updatePlanner((current) {
      final nextWeeklyPlans = current.weeklyPlans.map((plan) {
        final nextMap = <String, SkincareWeeklyDayPlan>{};
        for (final day in SkincarePlanner.weekDays) {
          final dayPlan =
              plan.weeklyPlanByDay[day] ?? SkincareWeeklyDayPlan(dayKey: day);
          nextMap[day] = dayPlan.copyWith(
            morningSourceId: !nextMorning ? null : dayPlan.morningSourceId,
            clearMorningSourceId: !nextMorning,
            eveningSourceId: !nextEvening ? null : dayPlan.eveningSourceId,
            clearEveningSourceId: !nextEvening,
          );
        }
        return plan.copyWith(weeklyPlanByDay: nextMap);
      }).toList();
      return current.copyWith(
        morningRoutineEnabled: nextMorning,
        eveningRoutineEnabled: nextEvening,
        weeklyPlans: nextWeeklyPlans,
      );
    });
  }

  SkincareWeeklyPlan _activeWeeklyPlan(SkincarePlanner planner) {
    for (final plan in planner.weeklyPlans) {
      if (plan.id == planner.selectedWeeklyPlanId) return plan;
    }
    return planner.weeklyPlans.first;
  }

  Future<void> _selectOrCreateWeeklyPlanByName(String rawName) async {
    final planner = _planner;
    if (planner == null) return;
    final name = rawName.trim();
    if (name.isEmpty) return;
    SkincareWeeklyPlan? existing;
    for (final plan in planner.weeklyPlans) {
      if (plan.name.trim().toLowerCase() == name.toLowerCase()) {
        existing = plan;
        break;
      }
    }
    if (existing != null) {
      await _updatePlanner(
        (current) => current.copyWith(selectedWeeklyPlanId: existing!.id),
      );
      return;
    }
    if (planner.weeklyPlans.length >= 2) {
      _showError('Only one additional weekly plan is allowed.');
      return;
    }
    final newPlan = SkincareWeeklyPlan(
      id: 'weekly_plan_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      weeklyPlanByDay: SkincarePlanner.blankWeeklyDayMap(),
    );
    await _updatePlanner(
      (current) => current.copyWith(
        weeklyPlans: [...current.weeklyPlans, newPlan],
        selectedWeeklyPlanId: newPlan.id,
      ),
    );
  }

  Future<void> _submitWeeklyPlanInput({
    required String value,
    required String source,
  }) async {
    await _selectOrCreateWeeklyPlanByName(value);
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _addRoutineSet(bool isMorning) async {
    final planner = _planner;
    if (planner == null) return;
    final sets = isMorning
        ? planner.morningRoutineSets
        : planner.eveningRoutineSets;
    if (sets.length >= 2) {
      _showError(
        'Only one additional ${isMorning ? 'morning' : 'evening'} routine set is allowed.',
      );
      return;
    }
    final nextIdx = sets.length + 1;
    final prefix = isMorning ? 'morning_set_' : 'evening_set_';
    final newSet = SkincareRoutineSet(
      id: '$prefix$nextIdx',
      name: '${isMorning ? 'Morning' : 'Evening'} Set $nextIdx',
      rows: const [],
    );
    await _updatePlanner((current) {
      final nextSets = isMorning
          ? [...current.morningRoutineSets, newSet]
          : [...current.eveningRoutineSets, newSet];
      return isMorning
          ? current.copyWith(
              morningRoutineSets: nextSets,
              selectedMorningSetId: newSet.id,
            )
          : current.copyWith(
              eveningRoutineSets: nextSets,
              selectedEveningSetId: newSet.id,
            );
    });
  }

  Future<void> _selectOrCreateRoutineSetByName(
    bool isMorning,
    String rawName,
  ) async {
    final planner = _planner;
    if (planner == null) return;
    final name = rawName.trim();
    if (name.isEmpty) return;
    final sets = isMorning
        ? planner.morningRoutineSets
        : planner.eveningRoutineSets;
    SkincareRoutineSet? existing;
    for (final set in sets) {
      if (set.name.trim().toLowerCase() == name.toLowerCase()) {
        existing = set;
        break;
      }
    }
    if (existing != null) {
      await _updatePlanner(
        (current) => isMorning
            ? current.copyWith(selectedMorningSetId: existing!.id)
            : current.copyWith(selectedEveningSetId: existing!.id),
      );
      return;
    }
    if (sets.length >= 2) {
      _showError(
        'Only one additional ${isMorning ? 'morning' : 'evening'} routine set is allowed.',
      );
      return;
    }
    final prefix = isMorning ? 'morning_set_' : 'evening_set_';
    final newSet = SkincareRoutineSet(
      id: '$prefix${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      rows: const [],
    );
    await _updatePlanner((current) {
      final nextSets = isMorning
          ? [...current.morningRoutineSets, newSet]
          : [...current.eveningRoutineSets, newSet];
      return isMorning
          ? current.copyWith(
              morningRoutineSets: nextSets,
              selectedMorningSetId: newSet.id,
            )
          : current.copyWith(
              eveningRoutineSets: nextSets,
              selectedEveningSetId: newSet.id,
            );
    });
  }

  Future<void> _submitRoutineSetInput({
    required bool isMorning,
    required String value,
    required String source,
  }) async {
    await _selectOrCreateRoutineSetByName(isMorning, value);
    if (mounted) FocusManager.instance.primaryFocus?.unfocus();
  }

  SkincareWeeklyPlan _weeklyPlanForCurrentTrackerWeek(SkincarePlanner planner) {
    return SkincarePresetCompiler.weeklyPlanForCurrentTrackerWeek(planner);
  }

  ({List<HabitActionStep> steps, List<int> weekdays}) _buildHabitSteps({
    required SkincarePlanner planner,
    required SkincareWeeklyPlan weeklyPlan,
    required bool forMorning,
  }) {
    return SkincarePresetCompiler.buildHabitPartsFromPlanner(
      planner: planner,
      weeklyPlan: weeklyPlan,
      morning: forMorning,
    );
  }

  Future<void> _confirmAndCreateHabits() async {
    final planner = _planner;
    if (planner == null || planner.monthlyTracker.length < 3) return;
    final gate = await PresetHabitCreationService.checkGate();
    if (!mounted) return;
    if (!gate.canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Need ${gate.requiredCoins} coins to create habits from this preset.',
          ),
        ),
      );
      return;
    }
    final enabledHabitCount =
        (planner.morningRoutineEnabled ? 1 : 0) +
        (planner.eveningRoutineEnabled ? 1 : 0);
    if (enabledHabitCount == 0) {
      _showError('At least one routine must be enabled to create habits.');
      return;
    }
    final targetLabel = enabledHabitCount == 2
        ? 'Morning and Evening'
        : (planner.morningRoutineEnabled ? 'Morning' : 'Evening');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create habits?'),
        content: Text(
          'This will create $enabledHabitCount ${enabledHabitCount == 1 ? 'habit' : 'habits'} ($targetLabel) from the weekly plan associated with the current week of this month.',
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

    final weeklyPlan = _weeklyPlanForCurrentTrackerWeek(planner);
    final morning = planner.morningRoutineEnabled
        ? _buildHabitSteps(
            planner: planner,
            weeklyPlan: weeklyPlan,
            forMorning: true,
          )
        : (steps: <HabitActionStep>[], weekdays: <int>[]);
    final evening = planner.eveningRoutineEnabled
        ? _buildHabitSteps(
            planner: planner,
            weeklyPlan: weeklyPlan,
            forMorning: false,
          )
        : (steps: <HabitActionStep>[], weekdays: <int>[]);
    if (morning.steps.isEmpty && evening.steps.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No weekly plan steps found to create habits.'),
        ),
      );
      return;
    }

    final title = planner.title.trim().isEmpty
        ? 'Skincare Routine'
        : planner.title.trim();
    final createdNames = await SkincarePresetCompiler.createHabitsFromPlanner(
      planner: planner,
      baseTitle: title,
      morningEnabled: planner.morningRoutineEnabled,
      eveningEnabled: planner.eveningRoutineEnabled,
    );
    if (createdNames.isNotEmpty) {
      await PresetHabitCreationService.applyChargeForSuccessfulCreate();
    }

    if (!mounted) return;
    final createdLabel = createdNames.join(' and ');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Created ${createdNames.length == 1 ? 'habit' : 'habits'}: $createdLabel',
        ),
      ),
    );
  }

  Future<void> _manualSaveWithToast() async {
    await _commitPendingDraftInputs();
    final planner = _planner;
    if (planner == null) return;
    await SkincarePlannerStorageService.save(planner);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Skincare preset saved')));
  }

  Future<void> _commitPendingDraftInputs() async {
    final weeklyDraft = (_weeklyPlanInput ?? '').trim();
    final morningDraft = (_morningRoutineSetInput ?? '').trim();
    final eveningDraft = (_eveningRoutineSetInput ?? '').trim();
    if (weeklyDraft.isNotEmpty) {
      await _submitWeeklyPlanInput(value: weeklyDraft, source: 'manual-save');
    }
    if (morningDraft.isNotEmpty) {
      await _submitRoutineSetInput(
        isMorning: true,
        value: morningDraft,
        source: 'manual-save',
      );
    }
    if (eveningDraft.isNotEmpty) {
      await _submitRoutineSetInput(
        isMorning: false,
        value: eveningDraft,
        source: 'manual-save',
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset presets?'),
        content: const Text(
          'This will replace current values with the default image-1 template.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final defaults = SkincarePlanner.defaultSeed();
    await _save(defaults);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reset to default skincare template')),
    );
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  List<String> _allProductSuggestions(SkincarePlanner planner) {
    final values = <String>[];
    void addValue(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      values.add(trimmed);
    }

    for (final product in planner.productsToBuy) {
      addValue(product);
    }

    for (final set in planner.morningRoutineSets) {
      for (final row in set.rows) {
        addValue(row.productUsed);
      }
    }
    for (final set in planner.eveningRoutineSets) {
      for (final row in set.rows) {
        addValue(row.productUsed);
      }
    }

    final seen = <String>{};
    final unique = <String>[];
    for (final value in values) {
      final key = value.toLowerCase();
      if (seen.add(key)) unique.add(value);
    }
    unique.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return unique;
  }

  Future<void> _editRow({required bool isMorning, required int index}) async {
    final planner = _planner;
    if (planner == null) return;
    final rows = isMorning
        ? planner.selectedMorningSet.rows
        : planner.selectedEveningSet.rows;
    final row = rows[index];
    final taskCtrl = TextEditingController(text: row.task);
    final productCtrl = TextEditingController(text: row.productUsed);
    final noteCtrl = TextEditingController(text: row.note ?? '');
    final suggestions = _allProductSuggestions(planner);
    String? pickedSuggestion;

    final result = await showDialog<SkincarePlannerRow>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text(isMorning ? 'Edit Morning Row' : 'Edit Evening Row'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: taskCtrl,
                      decoration: const InputDecoration(labelText: 'Task'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: productCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Product Used (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: pickedSuggestion,
                      decoration: const InputDecoration(
                        labelText: 'Choose from products',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('None'),
                        ),
                        ...suggestions.map(
                          (s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setLocalState(() => pickedSuggestion = value);
                        if (value != null && value.isNotEmpty) {
                          productCtrl.text = value;
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      minLines: 1,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Row Note (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      row.copyWith(
                        task: taskCtrl.text.trim(),
                        productUsed: productCtrl.text.trim(),
                        note: noteCtrl.text.trim(),
                        clearNote: noteCtrl.text.trim().isEmpty,
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    await _updatePlanner((current) {
      final sets = isMorning
          ? [...current.morningRoutineSets]
          : [...current.eveningRoutineSets];
      final selectedId = isMorning
          ? current.selectedMorningSetId
          : current.selectedEveningSetId;
      final setIdx = sets.indexWhere((s) => s.id == selectedId);
      if (setIdx < 0) return current;
      final updated = [...sets[setIdx].rows];
      if (index < 0 || index >= updated.length) return current;
      updated[index] = result;
      sets[setIdx] = sets[setIdx].copyWith(rows: updated);
      return isMorning
          ? current.copyWith(morningRoutineSets: sets)
          : current.copyWith(eveningRoutineSets: sets);
    });
  }

  Future<void> _addRow(bool isMorning) async {
    final planner = _planner;
    if (planner == null) return;
    final newRow = SkincarePlannerRow(
      id: _newId(isMorning ? 'am' : 'pm'),
      task: '',
      productUsed: '',
    );
    await _updatePlanner((current) {
      final sets = isMorning
          ? [...current.morningRoutineSets]
          : [...current.eveningRoutineSets];
      final selectedId = isMorning
          ? current.selectedMorningSetId
          : current.selectedEveningSetId;
      final setIdx = sets.indexWhere((s) => s.id == selectedId);
      if (setIdx < 0) return current;
      sets[setIdx] = sets[setIdx].copyWith(
        rows: [...sets[setIdx].rows, newRow],
      );
      return isMorning
          ? current.copyWith(morningRoutineSets: sets)
          : current.copyWith(eveningRoutineSets: sets);
    });
  }

  Future<void> _removeRow({required bool isMorning, required int index}) async {
    final planner = _planner;
    if (planner == null) return;
    await _updatePlanner((current) {
      final sets = isMorning
          ? [...current.morningRoutineSets]
          : [...current.eveningRoutineSets];
      final selectedId = isMorning
          ? current.selectedMorningSetId
          : current.selectedEveningSetId;
      final setIdx = sets.indexWhere((s) => s.id == selectedId);
      if (setIdx < 0) return current;
      final rows = [...sets[setIdx].rows];
      if (index < 0 || index >= rows.length) return current;
      rows.removeAt(index);
      sets[setIdx] = sets[setIdx].copyWith(rows: rows);
      return isMorning
          ? current.copyWith(morningRoutineSets: sets)
          : current.copyWith(eveningRoutineSets: sets);
    });
  }

  Future<void> _reorderRows({
    required bool isMorning,
    required int oldIndex,
    required int newIndex,
  }) async {
    final planner = _planner;
    if (planner == null) return;
    await _updatePlanner((current) {
      final sets = isMorning
          ? [...current.morningRoutineSets]
          : [...current.eveningRoutineSets];
      final selectedId = isMorning
          ? current.selectedMorningSetId
          : current.selectedEveningSetId;
      final setIdx = sets.indexWhere((s) => s.id == selectedId);
      if (setIdx < 0) return current;
      final rows = [...sets[setIdx].rows];
      if (oldIndex < 0 || oldIndex >= rows.length) return current;
      var targetIndex = newIndex;
      if (targetIndex > oldIndex) targetIndex -= 1;
      if (targetIndex < 0 || targetIndex > rows.length) return current;
      final moved = rows.removeAt(oldIndex);
      rows.insert(targetIndex, moved);
      sets[setIdx] = sets[setIdx].copyWith(rows: rows);
      return isMorning
          ? current.copyWith(morningRoutineSets: sets)
          : current.copyWith(eveningRoutineSets: sets);
    });
  }

  List<DropdownMenuItem<String>> _weeklyMorningSourceItems(
    SkincarePlanner planner,
  ) {
    final entries = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: '', child: Text('None')),
    ];
    if (planner.morningRoutineEnabled) {
      for (final set in planner.morningRoutineSets) {
        entries.add(
          DropdownMenuItem<String>(
            value: set.id,
            child: Text(set.name.trim().isEmpty ? 'Unnamed' : set.name),
          ),
        );
      }
    }
    return entries;
  }

  List<DropdownMenuItem<String>> _weeklyEveningSourceItems(
    SkincarePlanner planner,
  ) {
    final entries = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: '', child: Text('None')),
    ];
    if (planner.eveningRoutineEnabled) {
      for (final set in planner.eveningRoutineSets) {
        entries.add(
          DropdownMenuItem<String>(
            value: set.id,
            child: Text(set.name.trim().isEmpty ? 'Unnamed' : set.name),
          ),
        );
      }
    }
    return entries;
  }

  Future<void> _updateProductsToBuy(List<String> next) async {
    final planner = _planner;
    if (planner == null) return;
    final clean = <String>[];
    final seen = <String>{};
    for (final value in next) {
      final v = value.trim();
      if (v.isEmpty) continue;
      if (seen.add(v.toLowerCase())) clean.add(v);
    }
    await _updatePlanner((current) => current.copyWith(productsToBuy: clean));
  }

  Future<void> _addProductToBuy() async {
    final planner = _planner;
    if (planner == null) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add product used'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Product name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final value = ctrl.text.trim();
    if (value.isEmpty) return;
    await _updateProductsToBuy([...planner.productsToBuy, value]);
  }

  @override
  Widget build(BuildContext context) {
    final planner = _planner;
    if (_loading || planner == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (planner.weeklyPlans.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final morningSourceItems = _weeklyMorningSourceItems(planner);
    final eveningSourceItems = _weeklyEveningSourceItems(planner);
    final activeWeeklyPlan = _activeWeeklyPlan(planner);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedScreenTitle = planner.title.trim().isEmpty
        ? 'Skincare Presets'
        : planner.title.trim();
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          resolvedScreenTitle,
          style: AppTypography.heading3(context),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: 'Reset to defaults',
            onPressed: _resetToDefaults,
            icon: const Icon(Icons.restart_alt),
          ),
          TextButton.icon(
            onPressed: _manualSaveWithToast,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      _previewActionButtonHeight,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _confirmAndCreateHabits,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(
                      _previewActionButtonHeight,
                    ),
                  ),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Create habits'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: AppColors.skyDecoration(isDark: isDark),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _GlassSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: planner.title,
                    decoration: const InputDecoration(
                      labelText: 'Routine title',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _updatePlanner(
                        (current) => current.copyWith(title: value.trim()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This routine title is generated using AI. Review and customize as needed.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _routineSection(
              title: 'Morning',
              planner: planner,
              isMorning: true,
            ),
            const SizedBox(height: 12),
            _routineSection(
              title: 'Evening',
              planner: planner,
              isMorning: false,
            ),
            const SizedBox(height: 12),
            _expandableSection(
              title: 'Weekly Plan',
              initiallyExpanded: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Autocomplete<SkincareWeeklyPlan>(
                    initialValue: TextEditingValue(
                      text: _weeklyPlanInput ?? activeWeeklyPlan.name,
                    ),
                    displayStringForOption: (option) => option.name,
                    optionsBuilder: (value) {
                      final q = value.text.trim().toLowerCase();
                      if (q.isEmpty) return planner.weeklyPlans;
                      return planner.weeklyPlans.where(
                        (plan) => plan.name.toLowerCase().contains(q),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final list = options.toList();
                      if (list.isEmpty) return const SizedBox.shrink();
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final scheme = Theme.of(context).colorScheme;
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            margin: const EdgeInsets.only(top: 4),
                            constraints: const BoxConstraints(
                              maxHeight: 220,
                              minWidth: 260,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? scheme.surfaceContainerLow.withValues(
                                            alpha: 0.62,
                                          )
                                        : AppColors.cloudWhite.withValues(alpha: 0.74),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.cloudWhite.withValues(alpha: 0.16)
                                          : AppColors.cloudWhite.withValues(
                                              alpha: 0.72,
                                            ),
                                    ),
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: list.length,
                                    itemBuilder: (context, index) {
                                      final option = list[index];
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          child: Text(option.name),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (option) {
                      setState(() => _weeklyPlanInput = option.name);
                      _updatePlanner(
                        (current) =>
                            current.copyWith(selectedWeeklyPlanId: option.id),
                      );
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            textInputAction: TextInputAction.done,
                            onChanged: (value) {
                              setState(() => _weeklyPlanInput = value);
                            },
                            onFieldSubmitted: (value) async {
                              await _submitWeeklyPlanInput(
                                value: value,
                                source: 'keyboard-enter',
                              );
                            },
                            onEditingComplete: () async {
                              await _submitWeeklyPlanInput(
                                value: controller.text,
                                source: 'editing-complete',
                              );
                            },
                            onTapOutside: (_) {
                              FocusManager.instance.primaryFocus?.unfocus();
                            },
                            decoration: InputDecoration(
                              labelText: 'Weekly plan',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: IconButton(
                                tooltip: 'Confirm weekly plan',
                                onPressed: () async {
                                  await _submitWeeklyPlanInput(
                                    value: controller.text,
                                    source: 'tick-icon',
                                  );
                                },
                                icon: const Icon(Icons.check_circle_outline),
                              ),
                            ),
                          );
                        },
                  ),
                  const SizedBox(height: 12),
                  _weeklyPlanTable(
                    weeklyPlan: activeWeeklyPlan,
                    morningSourceItems: morningSourceItems,
                    eveningSourceItems: eveningSourceItems,
                    morningEnabled: planner.morningRoutineEnabled,
                    eveningEnabled: planner.eveningRoutineEnabled,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _expandableSection(
              title: 'Products Used',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final product in planner.productsToBuy)
                        InputChip(
                          label: Text(product),
                          onDeleted: () => _updateProductsToBuy(
                            planner.productsToBuy
                                .where((e) => e != product)
                                .toList(),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _addProductToBuy,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: const VisualDensity(
                            horizontal: -1,
                            vertical: -1,
                          ),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                          ),
                          foregroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _expandableSection(
              title: 'Monthly Tracker',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < planner.monthlyTracker.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 68,
                            child: Text(planner.monthlyTracker[i].weekLabel),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue:
                                  planner.weeklyPlans.any(
                                    (p) =>
                                        p.id ==
                                        planner.monthlyTracker[i].weeklyPlanId,
                                  )
                                  ? planner.monthlyTracker[i].weeklyPlanId
                                  : planner.weeklyPlans.first.id,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Plan',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: planner.weeklyPlans
                                  .map(
                                    (plan) => DropdownMenuItem<String>(
                                      value: plan.id,
                                      child: Text(plan.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                _updatePlanner((current) {
                                  final next = [...current.monthlyTracker];
                                  if (i < 0 || i >= next.length) return current;
                                  next[i] = next[i].copyWith(
                                    weeklyPlanId: value,
                                  );
                                  return current.copyWith(monthlyTracker: next);
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
          ],
        ),
      ),
    );
  }

  Widget _routineSection({
    required String title,
    required SkincarePlanner planner,
    required bool isMorning,
  }) {
    final sets = isMorning
        ? planner.morningRoutineSets
        : planner.eveningRoutineSets;
    if (sets.isEmpty) {
      return _expandableSection(
        title: '$title Routine',
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _addRoutineSet(isMorning),
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Add routine set'),
          ),
        ),
      );
    }
    final selectedSetId = isMorning
        ? planner.selectedMorningSetId
        : planner.selectedEveningSetId;
    SkincareRoutineSet selectedSet = sets.first;
    for (final set in sets) {
      if (set.id == selectedSetId) {
        selectedSet = set;
        break;
      }
    }
    final rows = selectedSet.rows;
    final routineEnabled = isMorning
        ? planner.morningRoutineEnabled
        : planner.eveningRoutineEnabled;
    final activeInput = isMorning
        ? (_morningRoutineSetInput ?? selectedSet.name)
        : (_eveningRoutineSetInput ?? selectedSet.name);
    return _expandableSection(
      title: '$title Routine',
      trailing: Switch(
        value: routineEnabled,
        onChanged: (value) =>
            _setRoutineEnabled(isMorning: isMorning, enabled: value),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!routineEnabled)
            Text(
              '${isMorning ? 'Morning' : 'Evening'} routine is disabled.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (!routineEnabled) const SizedBox(height: 4),
          if (!routineEnabled)
            Text(
              'Enable it from the header switch to view and edit details.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (!routineEnabled) const SizedBox(height: 8),
          if (routineEnabled)
            Autocomplete<SkincareRoutineSet>(
              initialValue: TextEditingValue(text: activeInput),
              displayStringForOption: (option) => option.name,
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return sets;
                return sets.where((set) => set.name.toLowerCase().contains(q));
              },
              optionsViewBuilder: (context, onSelected, options) {
                final list = options.toList();
                if (list.isEmpty) return const SizedBox.shrink();
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final scheme = Theme.of(context).colorScheme;
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(
                        maxHeight: 220,
                        minWidth: 260,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? scheme.surfaceContainerLow.withValues(
                                      alpha: 0.62,
                                    )
                                  : AppColors.cloudWhite.withValues(alpha: 0.74),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.cloudWhite.withValues(alpha: 0.16)
                                    : AppColors.cloudWhite.withValues(alpha: 0.72),
                              ),
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                final option = list[index];
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    child: Text(option.name),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
              onSelected: (option) {
                setState(() {
                  if (isMorning) {
                    _morningRoutineSetInput = option.name;
                  } else {
                    _eveningRoutineSetInput = option.name;
                  }
                });
                _updatePlanner(
                  (current) => isMorning
                      ? current.copyWith(selectedMorningSetId: option.id)
                      : current.copyWith(selectedEveningSetId: option.id),
                );
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (value) {
                        setState(() {
                          if (isMorning) {
                            _morningRoutineSetInput = value;
                          } else {
                            _eveningRoutineSetInput = value;
                          }
                        });
                      },
                      onFieldSubmitted: (value) async {
                        await _submitRoutineSetInput(
                          isMorning: isMorning,
                          value: value,
                          source: 'keyboard-enter',
                        );
                      },
                      onTap: () {},
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () async {
                        await _submitRoutineSetInput(
                          isMorning: isMorning,
                          value: controller.text,
                          source: 'editing-complete',
                        );
                      },
                      decoration: InputDecoration(
                        labelText: 'Routine set',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          tooltip: 'Confirm routine set',
                          onPressed: () async {
                            await _submitRoutineSetInput(
                              isMorning: isMorning,
                              value: controller.text,
                              source: 'tick-icon',
                            );
                          },
                          icon: const Icon(Icons.check_circle_outline),
                        ),
                      ),
                    );
                  },
            ),
          if (routineEnabled) const SizedBox(height: 12),
          if (routineEnabled)
            Text(
              '${rows.length} ${rows.length == 1 ? 'step' : 'steps'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          if (routineEnabled) const SizedBox(height: 8),
          if (routineEnabled)
            ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              onReorder: (oldIndex, newIndex) {
                _reorderRows(
                  isMorning: isMorning,
                  oldIndex: oldIndex,
                  newIndex: newIndex,
                );
              },
              itemBuilder: (context, i) {
                return Padding(
                  key: ValueKey('${selectedSet.id}-${rows[i].id}'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: Icon(
                            Icons.drag_indicator,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: Text('${i + 1}'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rows[i].task.trim().isEmpty
                                    ? 'Untitled step'
                                    : rows[i].task,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                rows[i].productUsed.trim().isEmpty
                                    ? 'No product selected'
                                    : rows[i].productUsed,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.75),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _editRow(isMorning: isMorning, index: i),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          onPressed: () =>
                              _removeRow(isMorning: isMorning, index: i),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (routineEnabled) const SizedBox(height: 12),
          if (routineEnabled)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _addRow(isMorning),
                icon: const Icon(Icons.add),
                label: const Text('Add Step'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _expandableSection({
    required String title,
    required Widget child,
    bool initiallyExpanded = false,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return _GlassSection(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 8),
        trailing: trailing,
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
        shape: const Border(),
        collapsedShape: const Border(),
        backgroundColor: Colors.transparent,
        collapsedBackgroundColor: Colors.transparent,
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        children: [child],
      ),
    );
  }

  Widget _weeklyPlanTable({
    required SkincareWeeklyPlan weeklyPlan,
    required List<DropdownMenuItem<String>> morningSourceItems,
    required List<DropdownMenuItem<String>> eveningSourceItems,
    required bool morningEnabled,
    required bool eveningEnabled,
  }) {
    const displayWeekDays = <String>[
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    String shortDayLabel(String day) {
      if (day.length < 3) return day;
      final base = day.substring(0, 3).toLowerCase();
      return '${base[0].toUpperCase()}${base.substring(1)}';
    }

    final morningItemValues = morningSourceItems
        .map((e) => e.value)
        .whereType<String>()
        .toSet();
    final eveningItemValues = eveningSourceItems
        .map((e) => e.value)
        .whereType<String>()
        .toSet();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Header row
    Widget headerRow = Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              'Day',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (morningEnabled)
            Expanded(
              child: Text(
                'AM',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
          if (morningEnabled && eveningEnabled) const SizedBox(width: 8),
          if (eveningEnabled)
            Expanded(
              child: Text(
                'PM',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );

    Widget buildDropdown({
      required String value,
      required List<DropdownMenuItem<String>> items,
      required Future<void> Function(String?) onChanged,
    }) {
      return DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        isDense: true,
        borderRadius: BorderRadius.circular(10),
        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurface),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        items: items,
        onChanged: (v) => onChanged(v),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerRow,
        Divider(
          height: 1,
          thickness: 0.5,
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        for (int i = 0; i < displayWeekDays.length; i++) ...[
          () {
            final day = displayWeekDays[i];
            final plan =
                weeklyPlan.weeklyPlanByDay[day] ??
                SkincareWeeklyDayPlan(dayKey: day);
            final safeMorningValue =
                morningEnabled &&
                    morningItemValues.contains(plan.morningSourceId)
                ? (plan.morningSourceId ?? '')
                : '';
            final safeEveningValue =
                eveningEnabled &&
                    eveningItemValues.contains(plan.eveningSourceId)
                ? (plan.eveningSourceId ?? '')
                : '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      shortDayLabel(day),
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (morningEnabled)
                    Expanded(
                      child: buildDropdown(
                        value: safeMorningValue,
                        items: morningSourceItems,
                        onChanged: (value) async {
                          await _updatePlanner((current) {
                            final idx = current.weeklyPlans.indexWhere(
                              (p) => p.id == current.selectedWeeklyPlanId,
                            );
                            if (idx < 0) return current;
                            final active = current.weeklyPlans[idx];
                            final nextMap = <String, SkincareWeeklyDayPlan>{
                              ...active.weeklyPlanByDay,
                            };
                            final currentDayPlan =
                                nextMap[day] ??
                                SkincareWeeklyDayPlan(dayKey: day);
                            nextMap[day] = currentDayPlan.copyWith(
                              morningSourceId: value,
                              clearMorningSourceId: (value ?? '').isEmpty,
                            );
                            final nextWeeklyPlans = [...current.weeklyPlans];
                            nextWeeklyPlans[idx] = active.copyWith(
                              weeklyPlanByDay: nextMap,
                            );
                            return current.copyWith(
                              weeklyPlans: nextWeeklyPlans,
                            );
                          });
                        },
                      ),
                    ),
                  if (morningEnabled && eveningEnabled)
                    const SizedBox(width: 8),
                  if (eveningEnabled)
                    Expanded(
                      child: buildDropdown(
                        value: safeEveningValue,
                        items: eveningSourceItems,
                        onChanged: (value) async {
                          await _updatePlanner((current) {
                            final idx = current.weeklyPlans.indexWhere(
                              (p) => p.id == current.selectedWeeklyPlanId,
                            );
                            if (idx < 0) return current;
                            final active = current.weeklyPlans[idx];
                            final nextMap = <String, SkincareWeeklyDayPlan>{
                              ...active.weeklyPlanByDay,
                            };
                            final currentDayPlan =
                                nextMap[day] ??
                                SkincareWeeklyDayPlan(dayKey: day);
                            nextMap[day] = currentDayPlan.copyWith(
                              eveningSourceId: value,
                              clearEveningSourceId: (value ?? '').isEmpty,
                            );
                            final nextWeeklyPlans = [...current.weeklyPlans];
                            nextWeeklyPlans[idx] = active.copyWith(
                              weeklyPlanByDay: nextMap,
                            );
                            return current.copyWith(
                              weeklyPlans: nextWeeklyPlans,
                            );
                          });
                        },
                      ),
                    ),
                ],
              ),
            );
          }(),
          if (i < displayWeekDays.length - 1)
            Divider(
              height: 1,
              thickness: 0.5,
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
        ],
      ],
    );
  }
}

class _GlassSection extends StatelessWidget {
  final Widget child;

  const _GlassSection({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: AppColors.cloudDecoration(isDark: isDark),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
