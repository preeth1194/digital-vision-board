import 'package:flutter/material.dart';

import '../models/task_item.dart';
import '../models/vision_components.dart';
import '../services/completion_mutations.dart';
import '../services/logical_date_service.dart';
import '../services/sync_service.dart';
import '../widgets/dialogs/completion_feedback_sheet.dart';
import '../widgets/dialogs/goal_picker_sheet.dart';

class TasksListScreen extends StatefulWidget {
  final String? boardId;
  final List<VisionComponent> components;
  final ValueChanged<List<VisionComponent>> onComponentsUpdated;
  final bool showAppBar;

  const TasksListScreen({
    super.key,
    this.boardId,
    required this.components,
    required this.onComponentsUpdated,
    this.showAppBar = true,
  });

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  late List<VisionComponent> _components;

  @override
  void initState() {
    super.initState();
    _components = widget.components;
  }

  @override
  void didUpdateWidget(covariant TasksListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.components != widget.components) {
      _components = widget.components;
    }
  }

  static List<VisionComponent> _goalLikeComponents(List<VisionComponent> all) {
    return all.where((c) => c is ImageComponent || c is GoalOverlayComponent).toList();
  }

  Future<void> _addTaskFromGoalPicker() async {
    final selected = await showGoalPickerSheet(
      context,
      components: _goalLikeComponents(_components),
      title: 'Select goal for task',
    );
    if (selected == null) return;

    String draftTitle = '';
    final title = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add task'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => draftTitle = v,
          decoration: const InputDecoration(
            labelText: 'Task title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(draftTitle.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty) return;

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final newTask = TaskItem(id: taskId, title: title.trim(), checklist: const []);

    final nextComponents = _components.map((c) {
      if (c.id != selected.id) return c;
      return c.copyWithCommon(tasks: [...c.tasks, newTask]);
    }).toList();

    setState(() => _components = nextComponents);
    widget.onComponentsUpdated(nextComponents);
  }
  static String _toIsoDate(DateTime d) {
    return LogicalDateService.toIsoDate(d);
  }

  Future<void> _addChecklistItem(VisionComponent component, String taskId) async {
    String draft = '';
    final text = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add checklist item'),
        content: TextField(
          autofocus: true,
          onChanged: (v) => draft = v,
          decoration: const InputDecoration(
            labelText: 'Item',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(draft.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;

    final newItem = ChecklistItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      dueDate: null,
      completedOn: null,
      cbtEnhancements: null,
      feedbackByDate: const {},
    );

    final updatedComponents = _components.map((c) {
      if (c.id != component.id) return c;
      final nextTasks = c.tasks.map((t) {
        if (t.id != taskId) return t;
        return t.copyWith(checklist: [...t.checklist, newItem]);
      }).toList();
      return c.copyWithCommon(tasks: nextTasks);
    }).toList();

    if (!mounted) return;
    setState(() => _components = updatedComponents);
    widget.onComponentsUpdated(updatedComponents);
  }

  Future<void> _toggleChecklistItem(VisionComponent component, String taskId, ChecklistItem item) async {
    final now = LogicalDateService.now();
    final task = component.tasks.firstWhere((t) => t.id == taskId);

    final toggle = CompletionMutations.toggleChecklistItemForToday(task, item, now: now);
    var currentTask = toggle.updatedTask;

    List<VisionComponent> updatedComponents = _components.map((c) {
      if (c.id != component.id) return c;
      final nextTasks = c.tasks.map((t) => t.id == taskId ? currentTask : t).toList();
      return c.copyWithCommon(tasks: nextTasks);
    }).toList();
    setState(() => _components = updatedComponents);
    widget.onComponentsUpdated(updatedComponents);

    final boardId = widget.boardId;
    if (boardId != null && boardId.isNotEmpty) {
      Future<void>(() async {
        await SyncService.enqueueChecklistEvent(
          boardId: boardId,
          componentId: component.id,
          taskId: taskId,
          itemId: item.id,
          logicalDate: toggle.isoDate,
          deleted: toggle.wasItemCompleted && !toggle.isItemCompleted,
        );
        if (toggle.wasTaskComplete && !toggle.isTaskComplete) {
          await SyncService.enqueueChecklistEvent(
            boardId: boardId,
            componentId: component.id,
            taskId: taskId,
            itemId: '__task__',
            logicalDate: toggle.isoDate,
            deleted: true,
          );
        }
      });
    }

    // Checklist item feedback when checking off.
    if (!toggle.wasItemCompleted && toggle.isItemCompleted) {
      final updatedItem = currentTask.checklist.firstWhere((c) => c.id == item.id);
      final isSingleItemTask = currentTask.checklist.length == 1;
      final shouldSkipItemFeedback = isSingleItemTask && !toggle.wasTaskComplete && toggle.isTaskComplete;

      if (!shouldSkipItemFeedback && !updatedItem.feedbackByDate.containsKey(toggle.isoDate)) {
        final res = await showCompletionFeedbackSheet(
          context,
          title: 'How did it go?',
          subtitle: '${task.title}: ${updatedItem.text}',
        );
        if (res != null) {
          currentTask = CompletionMutations.applyChecklistItemFeedback(
            currentTask,
            itemId: updatedItem.id,
            isoDate: toggle.isoDate,
            feedback: CompletionFeedback(rating: res.rating, note: res.note),
          );
          updatedComponents = _components.map((c) {
            if (c.id != component.id) return c;
            final nextTasks = c.tasks.map((t) => t.id == taskId ? currentTask : t).toList();
            return c.copyWithCommon(tasks: nextTasks);
          }).toList();
          if (mounted) setState(() => _components = updatedComponents);
          widget.onComponentsUpdated(updatedComponents);

          final boardId2 = widget.boardId;
          if (boardId2 != null && boardId2.isNotEmpty) {
            Future<void>(() async {
              await SyncService.enqueueChecklistEvent(
                boardId: boardId2,
                componentId: component.id,
                taskId: taskId,
                itemId: updatedItem.id,
                logicalDate: toggle.isoDate,
                rating: res.rating,
                note: res.note,
                deleted: false,
              );
            });
          }
        }
      }

      // Task-level feedback when task becomes fully complete.
      if (!toggle.wasTaskComplete && toggle.isTaskComplete) {
        if (!currentTask.completionFeedbackByDate.containsKey(toggle.isoDate)) {
          final res = await showCompletionFeedbackSheet(
            context,
            title: 'Task completed',
            subtitle: task.title,
          );
          if (res != null) {
            currentTask = CompletionMutations.applyTaskCompletionFeedback(
              currentTask,
              isoDate: toggle.isoDate,
              feedback: CompletionFeedback(rating: res.rating, note: res.note),
            );
            updatedComponents = _components.map((c) {
              if (c.id != component.id) return c;
              final nextTasks = c.tasks.map((t) => t.id == taskId ? currentTask : t).toList();
              return c.copyWithCommon(tasks: nextTasks);
            }).toList();
            if (mounted) setState(() => _components = updatedComponents);
            widget.onComponentsUpdated(updatedComponents);

            final boardId3 = widget.boardId;
            if (boardId3 != null && boardId3.isNotEmpty) {
              Future<void>(() async {
                await SyncService.enqueueChecklistEvent(
                  boardId: boardId3,
                  componentId: component.id,
                  taskId: taskId,
                  itemId: '__task__',
                  logicalDate: toggle.isoDate,
                  rating: res.rating,
                  note: res.note,
                  deleted: false,
                );
              });
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final componentsWithTasks = _components.where((c) => c.tasks.isNotEmpty).toList();
    final allChecklist = componentsWithTasks.expand((c) => c.tasks).expand((t) => t.checklist).toList();

    if (componentsWithTasks.isEmpty) {
      final body = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.checklist, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No tasks found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text('Add a task to a goal to get started', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _addTaskFromGoalPicker,
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ],
        ),
      );
      if (!widget.showAppBar) return body;
      return Scaffold(
        appBar: AppBar(
          title: const Text('All Tasks'),
          actions: [
            IconButton(
              tooltip: 'Add task',
              icon: const Icon(Icons.add),
              onPressed: _addTaskFromGoalPicker,
            ),
          ],
        ),
        body: body,
      );
    }

    final isoToday = LogicalDateService.isoToday();
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Tasks',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.icon(
              onPressed: _addTaskFromGoalPicker,
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.add),
                          title: const Text('Add checklist item'),
                          onTap: () => _addChecklistItem(component, t.id),
                        ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Tasks'),
        actions: [
          IconButton(
            tooltip: 'Add task',
            icon: const Icon(Icons.add),
            onPressed: _addTaskFromGoalPicker,
          ),
        ],
      ),
      body: body,
    );
  }
}

