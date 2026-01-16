import 'package:flutter/material.dart';

import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';

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
            const Text(
              'All Boards Tasks',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                  ...task.checklist.map((item) {
                                    return CheckboxListTile(
                                      value: item.isCompleted,
                                      onChanged: (_) async {
                                        final nowIso = _toIsoDate(DateTime.now());
                                        final updatedItem = item.copyWith(
                                          completedOn: item.isCompleted ? null : nowIso,
                                        );
                                        final updatedTasks = component.tasks.map((t) {
                                          if (t.id != task.id) return t;
                                          return t.copyWith(
                                            checklist: t.checklist.map((ci) => ci.id == item.id ? updatedItem : ci).toList(),
                                          );
                                        }).toList();

                                        final updatedComponent = component.copyWithCommon(tasks: updatedTasks);
                                        final updatedComponents = components.map((c) => c.id == component.id ? updatedComponent : c).toList();
                                        await onSaveBoardComponents(id, updatedComponents);
                                        setLocal(() {
                                          componentsByBoardId[id] = updatedComponents;
                                        });
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

