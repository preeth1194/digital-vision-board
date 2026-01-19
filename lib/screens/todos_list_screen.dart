import 'package:flutter/material.dart';

import '../models/habit_item.dart';
import '../models/goal_metadata.dart';
import '../models/vision_components.dart';
import '../utils/component_label_utils.dart';
import '../widgets/dialogs/add_habit_dialog.dart';
import '../widgets/dialogs/goal_picker_sheet.dart';
import '../widgets/dialogs/text_input_dialog.dart';

typedef OpenComponentCallback = Future<void> Function(VisionComponent component);

class TodosListScreen extends StatefulWidget {
  final List<VisionComponent> components;
  final ValueChanged<List<VisionComponent>> onComponentsUpdated;
  final OpenComponentCallback onOpenComponent;
  final bool showAppBar;
  /// When true, enables add/edit/delete and convert-to-habit actions.
  final bool allowManageTodos;
  /// Preferred goal component id for "Add todo" (e.g. last-opened goal).
  final String? preferredGoalComponentId;

  const TodosListScreen({
    super.key,
    required this.components,
    required this.onComponentsUpdated,
    required this.onOpenComponent,
    this.showAppBar = true,
    this.allowManageTodos = false,
    this.preferredGoalComponentId,
  });

  @override
  State<TodosListScreen> createState() => _TodosListScreenState();
}

class _TodosListScreenState extends State<TodosListScreen> {
  late List<VisionComponent> _components;
  late final TextEditingController _newTodoC;
  late final FocusNode _newTodoFocus;

  @override
  void initState() {
    super.initState();
    _components = widget.components;
    _newTodoC = TextEditingController();
    _newTodoFocus = FocusNode();
  }

  @override
  void dispose() {
    _newTodoC.dispose();
    _newTodoFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TodosListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.components != widget.components) {
      _components = widget.components;
    }
  }

  static GoalMetadata? _goalMeta(VisionComponent c) {
    if (c is ImageComponent) return c.goal;
    if (c is GoalOverlayComponent) return c.goal;
    return null;
  }

  static bool _isGoalLike(VisionComponent c) => _goalMeta(c) != null;

  static VisionComponent _withGoalMeta(VisionComponent c, GoalMetadata meta) {
    if (c is ImageComponent) return c.copyWith(goal: meta);
    if (c is GoalOverlayComponent) return c.copyWith(goal: meta);
    return c;
  }

  static HabitItem _applyHabitRequest(HabitItem base, HabitCreateRequest req) {
    return base.copyWith(
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
  }

  static String _normalizeTodoText(String raw) {
    return raw.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<({VisionComponent component, GoalTodoItem todo, GoalMetadata meta})> _flattenTodos() {
    final out = <({VisionComponent component, GoalTodoItem todo, GoalMetadata meta})>[];
    for (final c in _components) {
      final meta = _goalMeta(c);
      if (meta == null) continue;
      for (final t in meta.todoItems) {
        if (t.text.trim().isEmpty) continue;
        out.add((component: c, todo: t, meta: meta));
      }
    }
    return out;
  }

  Future<VisionComponent?> _pickTargetComponentForNewTodos(BuildContext context) async {
    final preferredId = (widget.preferredGoalComponentId ?? '').trim();
    if (preferredId.isNotEmpty) {
      final preferred = _components
          .cast<VisionComponent?>()
          .firstWhere((c) => c?.id == preferredId && _isGoalLike(c!), orElse: () => null);
      if (preferred != null) return preferred;
    }

    return showGoalPickerSheet(
      context,
      components: _components,
      title: 'Select goal for todo',
    );
  }

  Future<void> _addTodos(BuildContext context) async {
    final target = await _pickTargetComponentForNewTodos(context);
    if (target == null) return;
    final meta = _goalMeta(target);
    if (meta == null) return;

    final nextText = _newTodoC.text.trim();
    if (nextText.isEmpty) {
      _newTodoFocus.requestFocus();
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final nextItems = [
      ...meta.todoItems,
      GoalTodoItem(
        id: 'todo_${now}_0',
        text: nextText,
        isCompleted: false,
        completedAtMs: null,
        habitId: null,
        taskId: null,
      ),
    ];
    final nextMeta = meta.copyWith(todoItems: nextItems);

    final nextComponents = _components.map((c) {
      if (c.id != target.id) return c;
      return _withGoalMeta(c, nextMeta);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);
    _newTodoC.clear();
    _newTodoFocus.requestFocus();
  }

  Future<void> _editTodoText(BuildContext context, VisionComponent component, GoalMetadata meta, GoalTodoItem item) async {
    final res = await showTextInputDialog(
      context,
      title: 'Edit todo',
      initialText: item.text,
    );
    if (res == null) return;
    final nextText = _normalizeTodoText(res);
    if (nextText.isEmpty) return;

    final nextItems = meta.todoItems.map((t) => t.id == item.id ? t.copyWith(text: nextText) : t).toList();
    final nextMeta = meta.copyWith(todoItems: nextItems);

    final linkedHabitId = (item.habitId ?? '').trim();
    final nextComponents = _components.map((c) {
      if (c.id != component.id) return c;
      final updatedGoal = _withGoalMeta(c, nextMeta);
      if (linkedHabitId.isEmpty) return updatedGoal;
      return updatedGoal.copyWithCommon(
        habits: updatedGoal.habits.map((h) => h.id == linkedHabitId ? h.copyWith(name: nextText) : h).toList(),
      );
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);
  }

  void _deleteTodo(VisionComponent component, GoalMetadata meta, GoalTodoItem item) {
    final nextItems = meta.todoItems.where((t) => t.id != item.id).toList();
    final nextMeta = meta.copyWith(todoItems: nextItems);

    final nextComponents = _components.map((c) {
      if (c.id != component.id) return c;
      return _withGoalMeta(c, nextMeta);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);
  }

  void _toggleTodo(VisionComponent component, GoalMetadata meta, GoalTodoItem item, bool nextDone) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextItems = meta.todoItems
        .map(
          (t) => t.id == item.id
              ? t.copyWith(isCompleted: nextDone, completedAtMs: nextDone ? now : null)
              : t,
        )
        .toList();

    final nextMeta = meta.copyWith(todoItems: nextItems);
    final nextComponents = _components.map((c) {
      if (c.id != component.id) return c;
      return _withGoalMeta(c, nextMeta);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);
  }

  void _unlinkHabit(VisionComponent component, GoalMetadata meta, GoalTodoItem item) {
    final nextItems = meta.todoItems
        .map((t) => t.id == item.id ? t.copyWith(habitId: null) : t)
        .toList();
    final nextMeta = meta.copyWith(todoItems: nextItems);

    final nextComponents = _components.map((c) {
      if (c.id != component.id) return c;
      return _withGoalMeta(c, nextMeta);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);
  }

  Future<void> _convertToHabit(BuildContext context, VisionComponent component, GoalMetadata meta, GoalTodoItem item) async {
    final linkedId = (item.habitId ?? '').trim();
    final existing = linkedId.isEmpty
        ? null
        : component.habits.cast<HabitItem?>().firstWhere((h) => h?.id == linkedId, orElse: () => null);
    final otherHabits = component.habits.where((h) => h.id != existing?.id).toList();

    final HabitCreateRequest? req = (existing == null)
        ? await showAddHabitDialog(
            context,
            existingHabits: otherHabits,
            suggestedGoalDeadline: meta.deadline,
            initialName: item.text.trim().isEmpty ? null : item.text.trim(),
          )
        : await showEditHabitDialog(
            context,
            habit: existing,
            existingHabits: otherHabits,
            suggestedGoalDeadline: meta.deadline,
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

    final nextHabits = (existing == null)
        ? [...component.habits, nextHabit]
        : component.habits.map((h) => h.id == existing.id ? nextHabit : h).toList();

    final nextText = nextHabit.name.trim().isEmpty ? item.text : nextHabit.name.trim();
    final nextItems = meta.todoItems
        .map((t) => t.id == item.id ? t.copyWith(text: nextText, habitId: nextHabit.id) : t)
        .toList();
    final nextMeta = meta.copyWith(todoItems: nextItems);

    final nextComponents = _components.map((c) {
      if (c.id != component.id) return c;
      final updated = _withGoalMeta(c, nextMeta);
      return updated.copyWithCommon(habits: nextHabits);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _flattenTodos();

    final list = rows.isEmpty
        ? const Center(child: Text('No todo items yet.'))
        : ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, idx) {
              final component = rows[idx].component;
              final todo = rows[idx].todo;
              final meta = rows[idx].meta;
              final goalLabel = ComponentLabelUtils.categoryOrTitleOrId(component);
              final hasHabit = (todo.habitId ?? '').trim().isNotEmpty;

              return ListTile(
                title: Text(
                  todo.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(goalLabel),
                    if (hasHabit)
                      const Chip(
                        avatar: Icon(Icons.check_circle_outline, size: 18),
                        label: Text('Habit ✓'),
                      ),
                  ],
                ),
                leading: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (v) => _toggleTodo(component, meta, todo, v == true),
                ),
                trailing: widget.allowManageTodos
                    ? PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') await _editTodoText(context, component, meta, todo);
                          if (v == 'delete') _deleteTodo(component, meta, todo);
                          if (v == 'convert') await _convertToHabit(context, component, meta, todo);
                          if (v == 'unlink') _unlinkHabit(component, meta, todo);
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          const PopupMenuItem(value: 'convert', child: Text('Convert to habit')),
                          if (hasHabit) const PopupMenuItem(value: 'unlink', child: Text('Unlink habit')),
                        ],
                      )
                    : const Icon(Icons.chevron_right),
                onTap: () => widget.onOpenComponent(component),
              );
            },
          );

    Widget body = list;
    if (!widget.showAppBar && widget.allowManageTodos) {
      final canSave = _newTodoC.text.trim().isNotEmpty;
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTodoC,
                    focusNode: _newTodoFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addTodos(context),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Add a todo…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 40,
                  child: FilledButton(
                    onPressed: canSave ? () => _addTodos(context) : null,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: list),
        ],
      );
    }

    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo'),
      ),
      body: widget.allowManageTodos
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTodoC,
                          focusNode: _newTodoFocus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addTodos(context),
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Add a todo…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 40,
                        child: FilledButton(
                          onPressed: _newTodoC.text.trim().isNotEmpty ? () => _addTodos(context) : null,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: list),
              ],
            )
          : body,
    );
  }
}

