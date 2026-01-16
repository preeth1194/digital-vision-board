import 'package:flutter/material.dart';

import '../../models/goal_metadata.dart';

Future<GoalMetadata?> showGoalDetailsDialog(
  BuildContext context, {
  required String goalTitle,
  GoalMetadata? initial,
}) async {
  return showDialog<GoalMetadata?>(
    context: context,
    builder: (context) => _GoalDetailsDialog(goalTitle: goalTitle, initial: initial),
  );
}

class _GoalDetailsDialog extends StatefulWidget {
  final String goalTitle;
  final GoalMetadata? initial;
  const _GoalDetailsDialog({required this.goalTitle, required this.initial});

  @override
  State<_GoalDetailsDialog> createState() => _GoalDetailsDialogState();
}

class _GoalDetailsDialogState extends State<_GoalDetailsDialog> {
  final _category = TextEditingController();
  final _coreValue = TextEditingController();
  final _visualization = TextEditingController();
  final _limitingBelief = TextEditingController();
  final _reframedTruth = TextEditingController();
  final _microHabit = TextEditingController();
  String? _frequency; // null | 'Daily' | 'Weekly'
  final Set<int> _weeklyDays = <int>{};

  DateTime? _deadline;
  final List<GoalObstacle> _obstacles = [];

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial == null) return;

    _category.text = initial.category ?? '';
    final d = initial.deadline;
    if (d != null && d.isNotEmpty) {
      try {
        _deadline = DateTime.parse(d);
      } catch (_) {}
    }

    final cbt = initial.cbt;
    if (cbt != null) {
      _coreValue.text = cbt.coreValue ?? '';
      _visualization.text = cbt.visualization ?? '';
      _limitingBelief.text = cbt.limitingBelief ?? '';
      _reframedTruth.text = cbt.reframedTruth ?? '';
      _obstacles.addAll(cbt.obstacles);
    }

    final plan = initial.actionPlan;
    if (plan != null) {
      _microHabit.text = plan.microHabit ?? '';
      final f = (plan.frequency ?? '').trim();
      if (f.isNotEmpty) {
        final lower = f.toLowerCase();
        if (lower == 'daily') _frequency = 'Daily';
        if (lower == 'weekly') _frequency = 'Weekly';
      }
      if (plan.weeklyDays.isNotEmpty) {
        _weeklyDays.addAll(plan.weeklyDays);
      }
    }
  }

  @override
  void dispose() {
    _category.dispose();
    _coreValue.dispose();
    _visualization.dispose();
    _limitingBelief.dispose();
    _reframedTruth.dispose();
    _microHabit.dispose();
    super.dispose();
  }

  String? _deadlineIso() {
    final d = _deadline;
    if (d == null) return null;
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  void _submit() {
    final freq = (_frequency ?? '').trim();
    final freqNorm = freq.isEmpty ? null : freq; // already normalized values
    final weeklyDays = (_frequency == 'Weekly')
        ? (_weeklyDays.toList()..sort())
        : const <int>[];

    final meta = GoalMetadata(
      title: widget.goalTitle,
      deadline: _deadlineIso(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      cbt: GoalCbtMetadata(
        coreValue: _coreValue.text.trim().isEmpty ? null : _coreValue.text.trim(),
        visualization: _visualization.text.trim().isEmpty ? null : _visualization.text.trim(),
        limitingBelief: _limitingBelief.text.trim().isEmpty ? null : _limitingBelief.text.trim(),
        reframedTruth: _reframedTruth.text.trim().isEmpty ? null : _reframedTruth.text.trim(),
        obstacles: _obstacles,
      ),
      actionPlan: GoalActionPlan(
        microHabit: _microHabit.text.trim().isEmpty ? null : _microHabit.text.trim(),
        frequency: freqNorm,
        weeklyDays: weeklyDays,
      ),
    );
    Navigator.of(context).pop(meta);
  }

  static const _weekdays = <int, String>{
    DateTime.monday: 'Mon',
    DateTime.tuesday: 'Tue',
    DateTime.wednesday: 'Wed',
    DateTime.thursday: 'Thu',
    DateTime.friday: 'Fri',
    DateTime.saturday: 'Sat',
    DateTime.sunday: 'Sun',
  };

  Widget _weeklyDaysPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _weekdays.entries.map((e) {
        final selected = _weeklyDays.contains(e.key);
        return FilterChip(
          label: Text(e.value),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _weeklyDays.add(e.key);
              } else {
                _weeklyDays.remove(e.key);
              }
              // If user selects all days, this is equivalent to Daily.
              if (_weeklyDays.length >= 7) {
                _frequency = 'Daily';
                _weeklyDays.clear();
              }
            });
          },
        );
      }).toList(),
    );
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() => _deadline = picked);
  }

  Future<void> _addObstacle() async {
    final trigger = TextEditingController();
    final strategy = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add obstacle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: trigger,
              decoration: const InputDecoration(
                labelText: 'Trigger',
                hintText: 'e.g., Overwhelmed by new tech',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: strategy,
              decoration: const InputDecoration(
                labelText: 'Coping strategy',
                hintText: "e.g., Spend 15 mins reading docs—don't master it today.",
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (result != true) return;
    final t = trigger.text.trim();
    final s = strategy.text.trim();
    trigger.dispose();
    strategy.dispose();
    if (t.isEmpty || s.isEmpty) return;
    setState(() => _obstacles.add(GoalObstacle(trigger: t, copingStrategy: s)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Goal details (optional)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                widget.goalTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _category,
                      decoration: const InputDecoration(
                        labelText: 'Category (e.g., Career)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDeadline,
                      icon: const Icon(Icons.event_outlined),
                      label: Text(_deadline == null ? 'Deadline' : _deadlineIso()!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('CBT', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _coreValue,
                decoration: const InputDecoration(
                  labelText: 'Core value',
                  hintText: 'e.g., Growth and Mentorship',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _visualization,
                decoration: const InputDecoration(
                  labelText: 'Visualization',
                  hintText: 'e.g., I feel respected and capable leading large systems.',
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _limitingBelief,
                decoration: const InputDecoration(
                  labelText: 'Limiting belief',
                  hintText: "e.g., I worry I'm not technical enough.",
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reframedTruth,
                decoration: const InputDecoration(
                  labelText: 'Reframed truth',
                  hintText: "e.g., I have 10 years of experience and can learn what I don't know.",
                  border: OutlineInputBorder(),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Obstacles', style: TextStyle(fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: _addObstacle,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
              if (_obstacles.isNotEmpty)
                ..._obstacles.map(
                  (o) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.trigger),
                    subtitle: Text(o.copingStrategy),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _obstacles.remove(o)),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('Action plan', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _microHabit,
                decoration: const InputDecoration(
                  labelText: 'Micro habit',
                  hintText: 'e.g., Read 1 system design paper per week',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                value: _frequency,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Frequency (optional)')),
                  DropdownMenuItem(value: 'Daily', child: Text('Daily')),
                  DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                ],
                onChanged: (v) {
                  setState(() {
                    _frequency = v;
                    if (_frequency != 'Weekly') _weeklyDays.clear();
                    if (_frequency == 'Weekly' && _weeklyDays.isEmpty) {
                      _weeklyDays.add(DateTime.now().weekday);
                    }
                    // Weekly + all days collapses to Daily.
                    if (_frequency == 'Weekly' && _weeklyDays.length >= 7) {
                      _frequency = 'Daily';
                      _weeklyDays.clear();
                    }
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_frequency == 'Weekly') ...[
                const SizedBox(height: 10),
                const Text('Weekly days', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _weeklyDaysPicker(),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

