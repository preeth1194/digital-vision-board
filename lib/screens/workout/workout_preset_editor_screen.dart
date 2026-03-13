import 'package:flutter/material.dart';

import '../../models/action_step_template.dart';
import '../../models/habit_action_step.dart';

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

class _WorkoutPresetEditorScreenState
    extends State<WorkoutPresetEditorScreen> {
  late final TextEditingController _nameCtrl;
  late List<_ExerciseEntry> _exercises;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.template.name);
    _exercises = widget.template.steps
        .map((s) => _ExerciseEntry.fromStep(s))
        .toList();
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
    setState(() {
      _exercises.add(_ExerciseEntry.blank(order: _exercises.length));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preset name is required.')),
      );
      return;
    }

    final cleaned = <HabitActionStep>[];
    for (int i = 0; i < _exercises.length; i++) {
      final e = _exercises[i];
      final title = e.titleCtrl.text.trim();
      if (title.isEmpty) continue;
      cleaned.add(
        HabitActionStep(
          id: e.step.id,
          title: title,
          iconCodePoint: e.step.iconCodePoint,
          order: i,
          stepLabel: e.setsRepsCtrl.text.trim().isEmpty
              ? e.step.stepLabel
              : e.setsRepsCtrl.text.trim(),
          productType: e.muscleCtrl.text.trim().isEmpty
              ? e.step.productType
              : e.muscleCtrl.text.trim(),
          productName: e.step.productName,
          notes: e.step.notes,
          plannerDay: e.step.plannerDay,
          plannerWeek: e.step.plannerWeek,
        ),
      );
    }

    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise.')),
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
        steps: cleaned,
        metadata: widget.template.metadata,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Workout Plan'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
          // "Default" notice
          if (widget.template.isOfficial)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.3),
                ),
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
          Text('Exercises', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          for (int i = 0; i < _exercises.length; i++)
            _ExerciseCard(
              index: i,
              entry: _exercises[i],
              onRemove: () => _removeExercise(i),
            ),
        ],
      ),
    );
  }
}

// ── Data holder ───────────────────────────────────────────────────────────────

class _ExerciseEntry {
  final HabitActionStep step;
  final TextEditingController titleCtrl;
  final TextEditingController setsRepsCtrl;
  final TextEditingController muscleCtrl;
  int order;

  _ExerciseEntry({
    required this.step,
    required this.titleCtrl,
    required this.setsRepsCtrl,
    required this.muscleCtrl,
    required this.order,
  });

  factory _ExerciseEntry.fromStep(HabitActionStep step) {
    return _ExerciseEntry(
      step: step,
      titleCtrl: TextEditingController(text: step.title),
      setsRepsCtrl: TextEditingController(text: step.stepLabel ?? ''),
      muscleCtrl: TextEditingController(text: step.productType ?? ''),
      order: step.order,
    );
  }

  factory _ExerciseEntry.blank({required int order}) {
    final id =
        'custom-ex-${DateTime.now().microsecondsSinceEpoch}';
    return _ExerciseEntry(
      step: HabitActionStep(
        id: id,
        title: '',
        iconCodePoint: 58728,
        order: order,
      ),
      titleCtrl: TextEditingController(),
      setsRepsCtrl: TextEditingController(),
      muscleCtrl: TextEditingController(),
      order: order,
    );
  }

  _ExerciseEntry withOrder(int newOrder) {
    order = newOrder;
    return this;
  }

  void dispose() {
    titleCtrl.dispose();
    setsRepsCtrl.dispose();
    muscleCtrl.dispose();
  }
}

// ── Exercise card ─────────────────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final int index;
  final _ExerciseEntry entry;
  final VoidCallback onRemove;

  const _ExerciseCard({
    required this.index,
    required this.entry,
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
                    controller: entry.setsRepsCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Sets × Reps',
                      hintText: 'e.g. 3 × 10',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: entry.muscleCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Muscle group',
                      hintText: 'e.g. Chest',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if ((entry.step.plannerDay ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Day: ${entry.step.plannerDay}',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
