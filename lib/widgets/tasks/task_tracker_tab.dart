import 'package:flutter/material.dart';

import '../../models/task_item.dart';

class TaskTrackerTab extends StatelessWidget {
  final List<TaskItem> tasks;
  final VoidCallback onAddTask;
  final void Function(String taskId) onDeleteTask;
  final ValueChanged<TaskItem> onEditTask;
  final void Function(String taskId) onAddChecklistItem;
  final void Function(String taskId, ChecklistItem item) onToggleChecklistItem;
  final void Function(String taskId, String itemId) onDeleteChecklistItem;
  final void Function(String taskId, ChecklistItem item) onEditChecklistItem;

  const TaskTrackerTab({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onDeleteTask,
    required this.onEditTask,
    required this.onAddChecklistItem,
    required this.onToggleChecklistItem,
    required this.onDeleteChecklistItem,
    required this.onEditChecklistItem,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Tasks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No tasks yet. Add one above!', style: TextStyle(color: Colors.grey))),
          )
        else
          ...tasks.map((t) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ExpansionTile(
                title: Text(t.title),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit task',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEditTask(t),
                    ),
                    IconButton(
                      tooltip: 'Delete task',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => onDeleteTask(t.id),
                    ),
                  ],
                ),
                children: [
                  if (t.checklist.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('No checklist items yet.', style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ...t.checklist.map((c) {
                      final due = (c.dueDate ?? '').trim();
                      return ListTile(
                        leading: Checkbox(
                          value: c.isCompleted,
                          onChanged: (_) => onToggleChecklistItem(t.id, c),
                        ),
                        title: Text(c.text),
                        subtitle: due.isEmpty ? null : Text('Due $due'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit checklist item',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => onEditChecklistItem(t.id, c),
                            ),
                            IconButton(
                              tooltip: 'Delete checklist item',
                              icon: const Icon(Icons.close),
                              onPressed: () => onDeleteChecklistItem(t.id, c.id),
                            ),
                          ],
                        ),
                      );
                    }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => onAddChecklistItem(t.id),
                        icon: const Icon(Icons.add),
                        label: const Text('Add checklist item'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

