import 'package:flutter/material.dart';

import '../../models/goal_metadata.dart';
import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../utils/component_label_utils.dart';

class AllBoardsTodosTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final Map<String, List<VisionComponent>> componentsByBoardId;
  final Future<void> Function(String boardId, List<VisionComponent> updated) onSaveBoardComponents;

  const AllBoardsTodosTab({
    super.key,
    required this.boards,
    required this.componentsByBoardId,
    required this.onSaveBoardComponents,
  });

  static GoalMetadata? _goalMeta(VisionComponent c) {
    if (c is ImageComponent) return c.goal;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final rows = <({VisionBoardInfo board, VisionComponent component, GoalMetadata meta, GoalTodoItem todo})>[];
    for (final b in boards) {
      final components = componentsByBoardId[b.id] ?? const <VisionComponent>[];
      for (final c in components) {
        final meta = _goalMeta(c);
        if (meta == null) continue;
        for (final t in meta.todoItems) {
          if (t.text.trim().isEmpty) continue;
          rows.add((board: b, component: c, meta: meta, todo: t));
        }
      }
    }

    if (rows.isEmpty) {
      return const Center(child: Text('No todo items yet.'));
    }

    Future<void> toggleRow(int idx, bool nextDone) async {
      final row = rows[idx];
      final boardId = row.board.id;
      final components = componentsByBoardId[boardId] ?? const <VisionComponent>[];
      final now = DateTime.now().millisecondsSinceEpoch;

      final nextComponents = components.map((c) {
        if (c.id != row.component.id) return c;
        final meta = _goalMeta(c);
        if (meta == null) return c;
        final nextItems = meta.todoItems
            .map(
              (t) => t.id == row.todo.id
                  ? t.copyWith(isCompleted: nextDone, completedAtMs: nextDone ? now : null)
                  : t,
            )
            .toList();
        final nextMeta = meta.copyWith(todoItems: nextItems);
        if (c is ImageComponent) return c.copyWith(goal: nextMeta);
        return c;
      }).toList();

      await onSaveBoardComponents(boardId, nextComponents);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, idx) {
        final row = rows[idx];
        final goalLabel = ComponentLabelUtils.categoryOrTitleOrId(row.component);
        final hasHabit = (row.todo.habitId ?? '').trim().isNotEmpty;
        return Card(
          child: ListTile(
            leading: Checkbox(
              value: row.todo.isCompleted,
              onChanged: (v) => toggleRow(idx, v == true),
            ),
            title: Text(
              row.todo.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: row.todo.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Text('${row.board.title} • $goalLabel'),
                if (hasHabit) const Chip(label: Text('Habit ✓')),
              ],
            ),
          ),
        );
      },
    );
  }
}

