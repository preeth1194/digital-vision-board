import 'package:flutter/material.dart';

import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../models/task_item.dart';
import '../../services/completion_mutations.dart';
import '../dialogs/completion_feedback_sheet.dart';
import '../dialogs/goal_picker_sheet.dart';
import '../dialogs/add_task_dialog.dart';
import '../dialogs/add_checklist_item_dialog.dart';

class AllBoardsTasksTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final Map<String, List<VisionComponent>> componentsByBoardId;
  final Future<void> Function(String boardId, List<VisionComponent> updated) onSaveBoardComponents;

  const AllBoardsTasksTab({
    super.key,
    required this.boards,
    required this.componentsByBoardId,
    required this.onSaveBoardComponents,
  });

  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    final boardIds = boards.map((b) => b.id).toList();
    final isoToday = _toIsoDate(DateTime.now());

    return StatefulBuilder(
      builder: (context, setLocal) {
        Future<VisionBoardInfo?> pickBoard() async {
          if (boards.isEmpty) return null;
          return showModalBottomSheet<VisionBoardInfo?>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: boards.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final b = boards[i];
                  return ListTile(
                    title: Text(b.title),
                    onTap: () => Navigator.of(ctx).pop(b),
                  );
                },
              ),
            ),
          );
        }

        Future<void> addTaskGlobal() async {
          final board = await pickBoard();
          if (board == null) return;
          final components = componentsByBoardId[board.id] ?? const <VisionComponent>[];
          final selected = await showGoalPickerSheet(
            context,
            components: components,
            title: 'Select goal for task',
          );
          if (selected == null) return;

          final res = await showAddTaskDialog(
            context,
            dialogTitle: 'Add task',
            primaryActionText: 'Add',
          );
          if (res == null) return;

          final newTask = TaskItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: res.title,
            checklist: const [],
            cbtEnhancements: res.cbtEnhancements,
          );

          final nextComponents = components.map((c) {
            if (c.id != selected.id) return c;
            return c.copyWithCommon(tasks: [...c.tasks, newTask]);
          }).toList();

          await onSaveBoardComponents(board.id, nextComponents);
          setLocal(() => componentsByBoardId[board.id] = nextComponents);
        }

        int totalChecklist = 0;
        int completedChecklist = 0;
        int dueToday = 0;
        int overdue = 0;

        for (final id in boardIds) {
          final components = componentsByBoardId[id] ?? const <VisionComponent>[];
          for (final c in components) {
            for (final t in c.tasks) {
              for (final ci in t.checklist) {
                totalChecklist++;
                if (ci.isCompleted) completedChecklist++;
                final due = (ci.dueDate ?? '').trim();
                if (!ci.isCompleted && due == isoToday) dueToday++;
                if (!ci.isCompleted && due.isNotEmpty && due.compareTo(isoToday) < 0) overdue++;
              }
            }
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'All Boards Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: addTaskGlobal,
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
                    Text('$completedChecklist / $totalChecklist completed'),
                    const SizedBox(height: 6),
                    Text('$dueToday due today • $overdue overdue'),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: totalChecklist == 0 ? 0 : completedChecklist / totalChecklist),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...boardIds.map((id) {
              final board = boards.firstWhere((b) => b.id == id);
              final components = componentsByBoardId[id] ?? const <VisionComponent>[];
              final componentsWithTasks = components.where((c) => c.tasks.isNotEmpty).toList();
              if (componentsWithTasks.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Text(
                      board.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...componentsWithTasks.map((component) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(component.id, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            ...component.tasks.map((task) {
                              final done = task.checklist.where((c) => c.isCompleted).length;
                              final total = task.checklist.length;
                              return ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(task.title),
                                subtitle: total == 0 ? const Text('No checklist items') : Text('$done / $total completed'),
                                children: [
                                  ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.add),
                                    title: const Text('Add checklist item'),
                                    onTap: () async {
                                      final res = await showAddChecklistItemDialog(
                                        context,
                                        dialogTitle: 'Add checklist item',
                                        primaryActionText: 'Add',
                                      );
                                      if (res == null) return;

                                      final newItem = ChecklistItem(
                                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                                        text: res.text,
                                        dueDate: res.dueDate,
                                        completedOn: null,
                                        cbtEnhancements: res.cbtEnhancements,
                                        feedbackByDate: const {},
                                      );

                                      final updatedComponents = components.map((c) {
                                        if (c.id != component.id) return c;
                                        final updatedTasks = component.tasks.map((t) {
                                          if (t.id != task.id) return t;
                                          return t.copyWith(checklist: [...t.checklist, newItem]);
                                        }).toList();
                                        return c.copyWithCommon(tasks: updatedTasks);
                                      }).toList();

                                      await onSaveBoardComponents(id, updatedComponents);
                                      setLocal(() => componentsByBoardId[id] = updatedComponents);
                                    },
                                  ),
                                  ...task.checklist.map((item) {
                                    return CheckboxListTile(
                                      value: item.isCompleted,
                                      onChanged: (_) async {
                                        final toggle = CompletionMutations.toggleChecklistItemForToday(task, item);
                                        var currentTask = toggle.updatedTask;

                                        List<VisionComponent> updatedComponents = components.map((c) {
                                          if (c.id != component.id) return c;
                                          final updatedTasks = component.tasks
                                              .map((t) => t.id == task.id ? currentTask : t)
                                              .toList();
                                          return c.copyWithCommon(tasks: updatedTasks);
                                        }).toList();

                                        await onSaveBoardComponents(id, updatedComponents);
                                        setLocal(() => componentsByBoardId[id] = updatedComponents);

                                        if (!toggle.wasItemCompleted && toggle.isItemCompleted) {
                                          final updatedItem = currentTask.checklist.firstWhere((c) => c.id == item.id);
                                          final isSingleItemTask = currentTask.checklist.length == 1;
                                          final shouldSkipItemFeedback =
                                              isSingleItemTask && !toggle.wasTaskComplete && toggle.isTaskComplete;

                                          if (!shouldSkipItemFeedback &&
                                              !updatedItem.feedbackByDate.containsKey(toggle.isoDate)) {
                                            final res = await showCompletionFeedbackSheet(
                                              context,
                                              title: 'How did it go?',
                                              subtitle: '${task.title}: ${updatedItem.text} • ${board.title}',
                                            );
                                            if (res != null) {
                                              currentTask = CompletionMutations.applyChecklistItemFeedback(
                                                currentTask,
                                                itemId: updatedItem.id,
                                                isoDate: toggle.isoDate,
                                                feedback: CompletionFeedback(rating: res.rating, note: res.note),
                                              );
                                              updatedComponents = components.map((c) {
                                                if (c.id != component.id) return c;
                                                final updatedTasks = component.tasks
                                                    .map((t) => t.id == task.id ? currentTask : t)
                                                    .toList();
                                                return c.copyWithCommon(tasks: updatedTasks);
                                              }).toList();
                                              await onSaveBoardComponents(id, updatedComponents);
                                              setLocal(() => componentsByBoardId[id] = updatedComponents);
                                            }
                                          }

                                          if (!toggle.wasTaskComplete && toggle.isTaskComplete) {
                                            if (!currentTask.completionFeedbackByDate.containsKey(toggle.isoDate)) {
                                              final res = await showCompletionFeedbackSheet(
                                                context,
                                                title: 'Task completed',
                                                subtitle: '${task.title} • ${board.title}',
                                              );
                                              if (res != null) {
                                                currentTask = CompletionMutations.applyTaskCompletionFeedback(
                                                  currentTask,
                                                  isoDate: toggle.isoDate,
                                                  feedback: CompletionFeedback(rating: res.rating, note: res.note),
                                                );
                                                updatedComponents = components.map((c) {
                                                  if (c.id != component.id) return c;
                                                  final updatedTasks = component.tasks
                                                      .map((t) => t.id == task.id ? currentTask : t)
                                                      .toList();
                                                  return c.copyWithCommon(tasks: updatedTasks);
                                                }).toList();
                                                await onSaveBoardComponents(id, updatedComponents);
                                                setLocal(() => componentsByBoardId[id] = updatedComponents);
                                              }
                                            }
                                          }
                                        }
                                      },
                                      title: Text(item.text),
                                      subtitle: (item.dueDate ?? '').trim().isEmpty ? null : Text('Due ${item.dueDate}'),
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
            }),
          ],
        );
      },
    );
  }
}

