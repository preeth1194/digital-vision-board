import 'package:flutter/material.dart';

import '../models/goal_metadata.dart';
import '../models/vision_components.dart';
import '../utils/component_label_utils.dart';

typedef OpenComponentCallback = Future<void> Function(VisionComponent component);

class TodosListScreen extends StatefulWidget {
  final List<VisionComponent> components;
  final ValueChanged<List<VisionComponent>> onComponentsUpdated;
  final OpenComponentCallback onOpenComponent;
  final bool showAppBar;

  const TodosListScreen({
    super.key,
    required this.components,
    required this.onComponentsUpdated,
    required this.onOpenComponent,
    this.showAppBar = true,
  });

  @override
  State<TodosListScreen> createState() => _TodosListScreenState();
}

class _TodosListScreenState extends State<TodosListScreen> {
  late List<VisionComponent> _components;

  @override
  void initState() {
    super.initState();
    _components = widget.components;
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
      if (c is ImageComponent) return c.copyWith(goal: nextMeta);
      if (c is GoalOverlayComponent) return c.copyWith(goal: nextMeta);
      return c;
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _flattenTodos();

    final body = rows.isEmpty
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
                    if (hasHabit) const Chip(label: Text('Habit ✓')),
                  ],
                ),
                leading: Checkbox(
                  value: todo.isCompleted,
                  onChanged: (v) => _toggleTodo(component, meta, todo, v == true),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onOpenComponent(component),
              );
            },
          );

    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Todo')),
      body: body,
    );
  }
}

