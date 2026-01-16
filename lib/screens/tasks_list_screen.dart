import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../models/vision_components.dart';

class TasksListScreen extends StatefulWidget {
  final List<VisionComponent> components;
  final ValueChanged<List<VisionComponent>> onComponentsUpdated;
  final bool showAppBar;

  const TasksListScreen({
    super.key,
    required this.components,
    required this.onComponentsUpdated,
    this.showAppBar = true,
  });

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  void _toggleChecklistItem(VisionComponent component, String taskId, ChecklistItem item) {
    final isoToday = _toIsoDate(DateTime.now());
    final updatedComponents = widget.components.map((c) {
      if (c.id != component.id) return c;
      final nextTasks = c.tasks.map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(
          checklist: t.checklist.map((ci) {
            if (ci.id != item.id) return ci;
            return ci.copyWith(completedOn: ci.isCompleted ? null : isoToday);
          }).toList(),
        );
      }).toList();
      return c.copyWithCommon(tasks: nextTasks);
    }).toList();

    widget.onComponentsUpdated(updatedComponents);
  }

  @override
  Widget build(BuildContext context) {
    final componentsWithTasks = widget.components.where((c) => c.tasks.isNotEmpty).toList();
    final allChecklist = componentsWithTasks.expand((c) => c.tasks).expand((t) => t.checklist).toList();

    if (componentsWithTasks.isEmpty) {
      final body = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text('Open a goal and add tasks in the tracker', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
      if (!widget.showAppBar) return body;
      return Scaffold(appBar: AppBar(title: const Text('All Tasks')), body: body);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isoToday = _toIsoDate(today);
    final doneToday = allChecklist.where((c) => c.completedOn == isoToday).length;
    final total = allChecklist.length;
    final dueToday = allChecklist.where((c) => (c.dueDate ?? '').trim() == isoToday && !c.isCompleted).length;
    final overdue = allChecklist.where((c) {
      final due = (c.dueDate ?? '').trim();
      if (due.isEmpty) return false;
      if (c.isCompleted) return false;
      return due.compareTo(isoToday) < 0;
    }).length;

    final body = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks progress',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text('$doneToday done today • $dueToday due today • $overdue overdue'),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: total == 0 ? 0 : (allChecklist.where((c) => c.isCompleted).length / total)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...componentsWithTasks.map((component) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(component.id, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ...component.tasks.map((t) {
                    final done = t.checklist.where((c) => c.isCompleted).length;
                    final totalItems = t.checklist.length;
                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(t.title),
                      subtitle: totalItems == 0 ? const Text('No checklist items') : Text('$done / $totalItems completed'),
                      children: [
                        ...t.checklist.map((c) {
                          final due = (c.dueDate ?? '').trim();
                          final dueText = due.isEmpty ? null : (due == isoToday ? 'Due today' : (due.compareTo(isoToday) < 0 ? 'Overdue $due' : 'Due $due'));
                          return CheckboxListTile(
                            value: c.isCompleted,
                            onChanged: (_) => _toggleChecklistItem(component, t.id, c),
                            title: Text(c.text),
                            subtitle: dueText == null ? null : Text(dueText),
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );

    if (!widget.showAppBar) return body;
    return Scaffold(appBar: AppBar(title: const Text('All Tasks')), body: body);
  }
}

