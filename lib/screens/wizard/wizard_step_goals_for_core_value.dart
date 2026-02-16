import 'package:flutter/material.dart';

import '../../models/core_value.dart';
import '../../models/cbt_enhancements.dart';
import '../../models/habit_item.dart';
import '../../models/goal_metadata.dart';
import '../../models/wizard/wizard_goal.dart';
import '../../models/wizard/wizard_state.dart';
import '../../services/wizard_recommendations_service.dart';
import '../../widgets/dialogs/add_habit_dialog.dart';

class WizardStepGoalsForCoreValue extends StatefulWidget {
  final CreateBoardWizardState state;
  final int coreValueIndex;
  final ValueChanged<CreateBoardWizardState> onNext;

  const WizardStepGoalsForCoreValue({
    super.key,
    required this.state,
    required this.coreValueIndex,
    required this.onNext,
  });

  @override
  State<WizardStepGoalsForCoreValue> createState() => _WizardStepGoalsForCoreValueState();
}

class _WizardStepGoalsForCoreValueState extends State<WizardStepGoalsForCoreValue> {
  late CreateBoardWizardState _state;
  final Map<String, _WizardCategoryRecsState> _recsByCategory = {};

  @override
  void initState() {
    super.initState();
    _state = widget.state;
  }

  @override
  void didUpdateWidget(covariant WizardStepGoalsForCoreValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _state = widget.state;
      // If categories changed, clear cached rec state for categories not present.
      final cats = _state.categoriesFor(_coreValueId).toSet();
      _recsByCategory.removeWhere((k, _) => !cats.contains(k));
    }
  }

  String get _coreValueId {
    final i = widget.coreValueIndex.clamp(0, (_state.coreValues.length - 1).clamp(0, 0x7fffffff));
    return _state.coreValues[i].coreValueId;
  }

  List<WizardGoalDraft> get _goalsForCore {
    return _state.goals.where((g) => g.coreValueId == _coreValueId).toList();
  }

  void _markGoalReviewed(String goalId) {
    final id = goalId.trim();
    if (id.isEmpty) return;
    final current = _state.reviewedGoalIds;
    if (current.contains(id)) return;
    setState(() => _state = _state.copyWith(reviewedGoalIds: [...current, id]));
  }

  Future<void> _ensureRecsLoaded(String category) async {
    final cat = category.trim();
    if (cat.isEmpty) return;
    final existing = _recsByCategory[cat] ?? _WizardCategoryRecsState.initial();
    if (existing.requested || existing.loading) return;

    setState(() {
      _recsByCategory[cat] = existing.copyWith(requested: true, loading: true, error: null);
    });

    try {
      final res = await WizardRecommendationsService.getOrGenerate(coreValueId: _coreValueId, category: cat);
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _recsByCategory[cat] = (_recsByCategory[cat] ?? existing).copyWith(
            loading: false,
            error: 'Could not load recommendations.',
            goals: const [],
          );
        });
        return;
      }
      setState(() {
        _recsByCategory[cat] = (_recsByCategory[cat] ?? existing).copyWith(
          loading: false,
          error: null,
          goals: res.goals,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recsByCategory[cat] = (_recsByCategory[cat] ?? existing).copyWith(
          loading: false,
          error: 'Failed to load recommendations.',
          goals: const [],
        );
      });
    }
  }

  Future<String?> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 10),
      initialDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return null;
    final yyyy = picked.year.toString().padLeft(4, '0');
    final mm = picked.month.toString().padLeft(2, '0');
    final dd = picked.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  Future<void> _addOrEditGoal({WizardGoalDraft? existing, WizardGoalDraft? prefill}) async {
    final isEdit = existing != null;
    final seed = existing ?? prefill;
    // Opening an existing goal counts as “reviewed”, even if user cancels.
    if (existing != null) _markGoalReviewed(existing.id);
    final nameC = TextEditingController(text: seed?.name ?? '');
    final whyC = TextEditingController(text: seed?.whyImportant ?? '');
    String category = (seed?.category ?? '');
    final categories = _state.categoriesFor(_coreValueId);
    if (category.trim().isEmpty && categories.isNotEmpty) category = categories.first;
    String? deadline = seed?.deadline;
    bool wantsActionPlan = seed?.wantsActionPlan ?? false;
    List<_WizardTodoDraft> todoItems = _WizardTodoDraft.fromSeed(seed);

    final res = await showModalBottomSheet<WizardGoalDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (ctx, setLocal) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEdit ? 'Edit goal' : 'Add goal',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameC,
                        decoration: const InputDecoration(
                          labelText: 'Goal name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category.isEmpty ? null : category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final c in categories)
                            DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setLocal(() => category = v ?? category),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: whyC,
                        minLines: 3,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'Why is this important to you?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event_outlined),
                        label: Text(deadline == null ? 'Add deadline (optional)' : 'Deadline: $deadline'),
                        onPressed: () async {
                          final d = await _pickDeadline();
                          setLocal(() => deadline = d);
                        },
                      ),
                      if (deadline != null)
                        TextButton(
                          onPressed: () => setLocal(() => deadline = null),
                          child: const Text('Clear deadline'),
                        ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: wantsActionPlan,
                        onChanged: (v) => setLocal(() => wantsActionPlan = v),
                        title: const Text('Create todo list'),
                        subtitle: const Text('Add an ordered list of items, then optionally turn each into a habit and/or task.'),
                      ),
                      if (wantsActionPlan) ...[
                        const SizedBox(height: 8),
                        _WizardTodoListEditor(
                          todos: todoItems,
                          onChanged: (next) => setLocal(() => todoItems = next),
                        ),
                      ],
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () {
                          final nm = nameC.text.trim();
                          final wi = whyC.text.trim();
                          if (nm.isEmpty) return;
                          final cat = category.trim();
                          if (cat.isEmpty) return;
                          final habits = wantsActionPlan ? _WizardTodoDraft.habitsFrom(todoItems) : const <HabitItem>[];
                          final todoPersisted = wantsActionPlan ? _WizardTodoDraft.todoItemsFrom(todoItems) : const <GoalTodoItem>[];
                          Navigator.of(ctx).pop(
                            WizardGoalDraft(
                              id: existing?.id ?? 'goal_${DateTime.now().millisecondsSinceEpoch}',
                              coreValueId: _coreValueId,
                              name: nm,
                              category: cat,
                              whyImportant: wi,
                              deadline: deadline,
                              wantsActionPlan: wantsActionPlan,
                              habits: habits,
                              tasks: const [],
                              todoItems: todoPersisted,
                            ),
                          );
                        },
                        child: Text(isEdit ? 'Save goal' : 'Add goal'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (res == null) return;
    final nextGoals = List<WizardGoalDraft>.from(_state.goals);
    nextGoals.removeWhere((g) => g.id == res.id);
    nextGoals.add(res);
    // keep stable ordering by insert time
    nextGoals.sort((a, b) => a.id.compareTo(b.id));
    setState(() => _state = _state.copyWith(goals: nextGoals));
    _markGoalReviewed(res.id);
  }

  void _removeGoal(WizardGoalDraft g) {
    final nextGoals = _state.goals.where((x) => x.id != g.id).toList();
    setState(() => _state = _state.copyWith(goals: nextGoals));
  }

  void _next() {
    // Require at least 1 goal per core value (per your spec “n number of goals”).
    final goals = _goalsForCore;
    if (goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 1 goal for this core value.')),
      );
      return;
    }

    final reviewed = _state.reviewedGoalIds.toSet();
    final unreviewed = goals.where((g) => !reviewed.contains(g.id)).toList();
    if (unreviewed.isNotEmpty) {
      final names = unreviewed.map((g) => g.name.trim()).where((s) => s.isNotEmpty).take(3).toList();
      final suffix = (unreviewed.length > 3) ? '…' : '';
      final hint = names.isEmpty ? '' : ' (${names.join(', ')}$suffix)';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review each goal (tap to open) before continuing. Remaining: ${unreviewed.length}$hint')),
      );
      return;
    }
    widget.onNext(_state);
  }

  @override
  Widget build(BuildContext context) {
    final core = CoreValues.byId(_coreValueId);
    final goals = _goalsForCore..sort((a, b) => a.name.compareTo(b.name));
    final stepLabel = '${widget.coreValueIndex + 1} / ${_state.coreValues.length}';
    final categories = _state.categoriesFor(_coreValueId);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Icon(core.icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Goals for ${core.label}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text(stepLabel),
          ],
        ),
        const SizedBox(height: 12),
        if (categories.isNotEmpty) ...[
          const Text(
            'Recommended (tap to load)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final cat in categories) _WizardRecommendedCategoryCard(
            coreValueId: _coreValueId,
            category: cat,
            state: _recsByCategory[cat] ?? _WizardCategoryRecsState.initial(),
            onExpand: () => _ensureRecsLoaded(cat),
            onUseGoal: (g) {
              final now = DateTime.now().millisecondsSinceEpoch;
              final habits = <HabitItem>[
                for (int i = 0; i < g.habits.length; i++)
                  HabitItem(
                    id: 'habit_rec_${now}_$i',
                    name: g.habits[i].name,
                    frequency: g.habits[i].frequency,
                    cbtEnhancements: (g.habits[i].cbtEnhancements is Map<String, dynamic>)
                        ? CbtEnhancements.fromJson(g.habits[i].cbtEnhancements as Map<String, dynamic>)
                        : null,
                    completedDates: const [],
                  ),
              ];
              _addOrEditGoal(
                prefill: WizardGoalDraft(
                  id: 'goal_prefill_$now',
                  coreValueId: _coreValueId,
                  name: g.name,
                  category: cat,
                  whyImportant: g.whyImportant,
                  deadline: null,
                  wantsActionPlan: true,
                  habits: habits,
                  tasks: const [],
                  todoItems: const [],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
        FilledButton.icon(
          onPressed: () => _addOrEditGoal(),
          icon: const Icon(Icons.add),
          label: const Text('Add goal'),
        ),
        const SizedBox(height: 12),
        if (goals.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('No goals yet. Add your first goal to continue.'),
          ),
        for (final g in goals)
          Card(
            child: ListTile(
              title: Text(g.name),
              subtitle: Text(g.category),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _addOrEditGoal(existing: g);
                  if (v == 'delete') _removeGoal(g);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
              onTap: () => _addOrEditGoal(existing: g),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _next,
          child: Text(_state.coreValues.length == 1 || widget.coreValueIndex == _state.coreValues.length - 1
              ? 'Next'
              : 'Next core value'),
        ),
      ],
    );
  }
}

final class _WizardCategoryRecsState {
  final bool requested;
  final bool loading;
  final String? error;
  final List<WizardRecommendedGoal> goals;

  const _WizardCategoryRecsState({
    required this.requested,
    required this.loading,
    required this.error,
    required this.goals,
  });

  factory _WizardCategoryRecsState.initial() =>
      const _WizardCategoryRecsState(requested: false, loading: false, error: null, goals: <WizardRecommendedGoal>[]);

  _WizardCategoryRecsState copyWith({
    bool? requested,
    bool? loading,
    String? error,
    List<WizardRecommendedGoal>? goals,
  }) {
    return _WizardCategoryRecsState(
      requested: requested ?? this.requested,
      loading: loading ?? this.loading,
      error: error,
      goals: goals ?? this.goals,
    );
  }
}

class _WizardRecommendedCategoryCard extends StatefulWidget {
  final String coreValueId;
  final String category;
  final _WizardCategoryRecsState state;
  final VoidCallback onExpand;
  final ValueChanged<WizardRecommendedGoal> onUseGoal;

  const _WizardRecommendedCategoryCard({
    required this.coreValueId,
    required this.category,
    required this.state,
    required this.onExpand,
    required this.onUseGoal,
  });

  @override
  State<_WizardRecommendedCategoryCard> createState() => _WizardRecommendedCategoryCardState();
}

class _WizardRecommendedCategoryCardState extends State<_WizardRecommendedCategoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: _expanded,
        title: Text(widget.category),
        onExpansionChanged: (v) {
          setState(() => _expanded = v);
          if (v) widget.onExpand();
        },
        children: [
          if (s.loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if ((s.error ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(s.error!, style: const TextStyle(color: Colors.red)),
            )
          else if (s.requested && s.goals.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No recommendations yet.'),
            )
          else
            for (final g in s.goals)
              ListTile(
                title: Text(g.name),
                subtitle: Text(
                  g.habits.isEmpty ? 'No habits' : '${g.habits.length} habit${g.habits.length == 1 ? '' : 's'}',
                ),
                trailing: TextButton(
                  onPressed: () => widget.onUseGoal(g),
                  child: const Text('Use'),
                ),
              ),
        ],
      ),
    );
  }
}

final class _WizardTodoDraft {
  final String id;
  final String text;
  final HabitItem? habit;

  const _WizardTodoDraft({
    required this.id,
    required this.text,
    required this.habit,
  });

  static const Object _unset = Object();

  _WizardTodoDraft copyWith({
    String? id,
    String? text,
    Object? habit = _unset,
  }) {
    return _WizardTodoDraft(
      id: id ?? this.id,
      text: text ?? this.text,
      habit: identical(habit, _unset) ? this.habit : habit as HabitItem?,
    );
  }

  static List<_WizardTodoDraft> fromSeed(WizardGoalDraft? seed) {
    if (seed == null) return const <_WizardTodoDraft>[];
    final habits = seed.habits;
    final byHabitId = <String, HabitItem>{for (final h in habits) h.id: h};

    // Prefer persisted ordering if present.
    final persisted = seed.todoItems;
    if (persisted.isNotEmpty) {
      return <_WizardTodoDraft>[
        for (final t in persisted)
          _WizardTodoDraft(
            id: t.id,
            text: t.text,
            habit: (t.habitId == null) ? null : byHabitId[t.habitId],
          ),
      ];
    }

    // Fallback for older drafts: derive from habits list.
    return <_WizardTodoDraft>[
      for (final h in habits)
        _WizardTodoDraft(id: 'todo_${h.id}', text: h.name, habit: h),
    ];
  }

  static List<HabitItem> habitsFrom(List<_WizardTodoDraft> todos) {
    return todos.map((t) => t.habit).whereType<HabitItem>().toList();
  }

  static List<GoalTodoItem> todoItemsFrom(List<_WizardTodoDraft> todos) {
    final out = <GoalTodoItem>[];
    for (final src in todos) {
      final text = src.text.trim();
      if (text.isEmpty) continue;
      out.add(
        GoalTodoItem(
          id: src.id,
          text: text,
          isCompleted: false,
          completedAtMs: null,
          habitId: src.habit?.id,
          taskId: null,
        ),
      );
    }
    return out;
  }
}

class _WizardTodoListEditor extends StatefulWidget {
  final List<_WizardTodoDraft> todos;
  final ValueChanged<List<_WizardTodoDraft>> onChanged;

  const _WizardTodoListEditor({required this.todos, required this.onChanged});

  @override
  State<_WizardTodoListEditor> createState() => _WizardTodoListEditorState();
}

class _WizardTodoListEditorState extends State<_WizardTodoListEditor> {
  final TextEditingController _bulkAddC = TextEditingController();

  @override
  void dispose() {
    _bulkAddC.dispose();
    super.dispose();
  }

  void _addItems() {
    final raw = _bulkAddC.text;
    final lines = raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (lines.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = <_WizardTodoDraft>[
      ...widget.todos,
      for (int i = 0; i < lines.length; i++)
        _WizardTodoDraft(
          id: 'todo_${now}_$i',
          text: lines[i],
          habit: null,
        ),
    ];
    widget.onChanged(next);
    _bulkAddC.clear();
    FocusScope.of(context).unfocus();
  }

  static HabitItem _applyHabitRequest(HabitItem base, HabitCreateRequest req) {
    return base.copyWith(
      name: req.name,
      category: req.category,
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
      iconIndex: req.iconIndex,
    );
  }

  Future<void> _configureHabit(int index) async {
    final item = widget.todos[index];
    final existing = item.habit;
    final otherHabits = widget.todos
        .where((t) => t.id != item.id)
        .map((t) => t.habit)
        .whereType<HabitItem>()
        .toList();

    final HabitCreateRequest? req = (existing == null)
        ? await showAddHabitDialog(
            context,
            existingHabits: otherHabits,
            initialName: item.text.trim().isEmpty ? null : item.text.trim(),
          )
        : await showEditHabitDialog(
            context,
            habit: existing,
            existingHabits: otherHabits,
          );

    if (req == null) return;
    final HabitItem nextHabit = _applyHabitRequest(
      existing ??
          HabitItem(
            id: 'habit_${DateTime.now().millisecondsSinceEpoch}',
            name: req.name,
            completedDates: const [],
          ),
      req,
    );
    final next = [...widget.todos];
    next[index] = item.copyWith(text: nextHabit.name, habit: nextHabit);
    widget.onChanged(next);
  }

  void _removeHabit(int index) {
    final next = [...widget.todos];
    next[index] = next[index].copyWith(habit: null);
    widget.onChanged(next);
  }

  void _removeRow(int index) {
    final next = [...widget.todos]..removeAt(index);
    widget.onChanged(next);
  }

  void _moveRow(int index, int delta) {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= widget.todos.length) return;
    final next = [...widget.todos];
    final item = next.removeAt(index);
    next.insert(nextIndex, item);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Todo list', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _bulkAddC,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Add todo items (one per line)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _addItems,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.todos.isEmpty)
              const Text('No todo items added.')
            else
              for (int i = 0; i < widget.todos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _TodoRow(
                    key: ValueKey(widget.todos[i].id),
                    index: i,
                    total: widget.todos.length,
                    item: widget.todos[i],
                    onMoveUp: () => _moveRow(i, -1),
                    onMoveDown: () => _moveRow(i, 1),
                    onTextChanged: (txt) {
                      final next = [...widget.todos];
                      final updated = next[i].copyWith(text: txt);
                      next[i] = updated.copyWith(
                        habit: updated.habit?.copyWith(name: txt),
                      );
                      widget.onChanged(next);
                    },
                    onConfigureHabit: () => _configureHabit(i),
                    onRemoveHabit: () => _removeHabit(i),
                    onDelete: () => _removeRow(i),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  final int index;
  final int total;
  final _WizardTodoDraft item;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onConfigureHabit;
  final VoidCallback onRemoveHabit;
  final VoidCallback onDelete;

  const _TodoRow({
    super.key,
    required this.index,
    required this.total,
    required this.item,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onTextChanged,
    required this.onConfigureHabit,
    required this.onRemoveHabit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            IconButton(
              tooltip: 'Move up',
              onPressed: index == 0 ? null : onMoveUp,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: index == (total - 1) ? null : onMoveDown,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: item.text,
                decoration: InputDecoration(
                  labelText: 'Item ${index + 1}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: onTextChanged,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InputChip(
                    selected: item.habit != null,
                    label: Text((item.habit == null) ? 'Habit' : 'Habit ✓'),
                    onPressed: onConfigureHabit,
                    onDeleted: (item.habit == null) ? null : onRemoveHabit,
                    deleteIcon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Delete item',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}

