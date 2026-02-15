import 'package:flutter/material.dart';

import '../../models/goal_metadata.dart';
import '../../models/habit_item.dart';
import '../dialogs/add_habit_dialog.dart';
import '../dialogs/text_input_dialog.dart';

class GoalTodoTab extends StatefulWidget {
  final List<GoalTodoItem> todos;
  final List<HabitItem> habits;
  final ValueChanged<List<GoalTodoItem>> onTodosChanged;
  final ValueChanged<List<HabitItem>> onHabitsChanged;

  const GoalTodoTab({
    super.key,
    required this.todos,
    required this.habits,
    required this.onTodosChanged,
    required this.onHabitsChanged,
  });

  @override
  State<GoalTodoTab> createState() => _GoalTodoTabState();
}

class _GoalTodoTabState extends State<GoalTodoTab> {
  late final TextEditingController _newTodoC;
  late final FocusNode _newTodoFocus;

  @override
  void initState() {
    super.initState();
    _newTodoC = TextEditingController();
    _newTodoFocus = FocusNode();
  }

  @override
  void dispose() {
    _newTodoC.dispose();
    _newTodoFocus.dispose();
    super.dispose();
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
    );
  }

  static String _normalizeTodoText(String raw) {
    return raw.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  Future<void> _addTodos(BuildContext context) async {
    final next = _newTodoC.text.trim();
    if (next.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    widget.onTodosChanged([
      ...widget.todos,
      GoalTodoItem(
        id: 'todo_${now}_0',
        text: next,
        isCompleted: false,
        completedAtMs: null,
        habitId: null,
        taskId: null,
      ),
    ]);
    _newTodoC.clear();
    _newTodoFocus.requestFocus();
  }

  Future<void> _editTodoText(BuildContext context, GoalTodoItem item) async {
    final res = await showTextInputDialog(
      context,
      title: 'Edit todo',
      initialText: item.text,
    );
    if (res == null) return;
    final nextText = _normalizeTodoText(res);
    if (nextText.isEmpty) return;
    final nextTodos = widget.todos
        .map((t) => t.id == item.id ? t.copyWith(text: nextText) : t)
        .toList();
    widget.onTodosChanged(nextTodos);

    // Keep linked entities in sync (optional but improves UX).
    final linkedHabitId = item.habitId;
    if (linkedHabitId != null && linkedHabitId.trim().isNotEmpty) {
      final nextHabits = widget.habits
          .map((h) => h.id == linkedHabitId ? h.copyWith(name: nextText) : h)
          .toList();
      widget.onHabitsChanged(nextHabits);
    }
  }

  void _toggleComplete(GoalTodoItem item, bool? v) {
    final nextDone = v == true;
    final now = DateTime.now().millisecondsSinceEpoch;
    widget.onTodosChanged(
      widget.todos
          .map(
            (t) => t.id == item.id
                ? t.copyWith(
                    isCompleted: nextDone,
                    completedAtMs: nextDone ? now : null,
                  )
                : t,
          )
          .toList(),
    );
  }

  void _deleteTodo(GoalTodoItem item) {
    widget.onTodosChanged(widget.todos.where((t) => t.id != item.id).toList());
  }

  void _unlinkHabit(GoalTodoItem item) {
    widget.onTodosChanged(
      widget.todos
          .map((t) => t.id == item.id ? t.copyWith(habitId: null) : t)
          .toList(),
    );
  }

  Future<void> _convertToHabit(BuildContext context, GoalTodoItem item) async {
    final existing = (item.habitId == null)
        ? null
        : widget.habits.cast<HabitItem?>().firstWhere((h) => h?.id == item.habitId, orElse: () => null);
    final otherHabits = widget.habits.where((h) => h.id != existing?.id).toList();

    final HabitCreateRequest? req = (existing == null)
        ? await showAddHabitDialog(
            context,
            existingHabits: otherHabits,
            suggestedGoalDeadline: null,
            initialName: item.text.trim().isEmpty ? null : item.text.trim(),
          )
        : await showEditHabitDialog(
            context,
            habit: existing,
            existingHabits: otherHabits,
            suggestedGoalDeadline: null,
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
        ? [...widget.habits, nextHabit]
        : widget.habits.map((h) => h.id == existing.id ? nextHabit : h).toList();
    widget.onHabitsChanged(nextHabits);

    final nextText = nextHabit.name.trim().isEmpty ? item.text : nextHabit.name.trim();
    widget.onTodosChanged(
      widget.todos
          .map(
            (t) => t.id == item.id
                ? t.copyWith(text: nextText, habitId: nextHabit.id)
                : t,
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _newTodoC.text.trim().isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      children: [
        Row(
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
        const SizedBox(height: 12),
        if (widget.todos.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('No todo items yet.'),
          )
        else
          for (final item in widget.todos)
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: item.isCompleted,
                      onChanged: (v) => _toggleComplete(item, v),
                      title: Text(
                        item.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      subtitle: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          InputChip(
                            selected: (item.habitId ?? '').trim().isNotEmpty,
                            label: Text(((item.habitId ?? '').trim().isEmpty) ? 'Habit' : 'Habit ✓'),
                            onPressed: () => _convertToHabit(context, item),
                            onDeleted: ((item.habitId ?? '').trim().isEmpty) ? null : () => _unlinkHabit(item),
                            deleteIcon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      secondary: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _editTodoText(context, item);
                          if (v == 'delete') _deleteTodo(item);
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

