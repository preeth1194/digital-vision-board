import 'package:flutter/material.dart';

import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';

class AllBoardsHabitsTab extends StatelessWidget {
  final List<VisionBoardInfo> boards;
  final Map<String, List<VisionComponent>> componentsByBoardId;
  final Future<void> Function(String boardId, List<VisionComponent> updated) onSaveBoardComponents;

  const AllBoardsHabitsTab({
    super.key,
    required this.boards,
    required this.componentsByBoardId,
    required this.onSaveBoardComponents,
  });

  @override
  Widget build(BuildContext context) {
    final boardIds = boards.map((b) => b.id).toList();
    return StatefulBuilder(
      builder: (context, setLocal) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'All Boards Habits',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...boardIds.map((id) {
              final board = boards.firstWhere((b) => b.id == id);
              final components = componentsByBoardId[id] ?? const <VisionComponent>[];
              final componentsWithHabits = components.where((c) => c.habits.isNotEmpty).toList();
              if (componentsWithHabits.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      board.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...componentsWithHabits.map((component) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              component.id,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          ...component.habits.map((habit) {
                            final isCompleted = habit.isCompletedForCurrentPeriod(DateTime.now());
                            return CheckboxListTile(
                              value: isCompleted,
                              onChanged: (_) async {
                                final updatedHabit = habit.toggleForDate(DateTime.now());
                                final updatedHabits = component.habits
                                    .map((h) => h.id == habit.id ? updatedHabit : h)
                                    .toList();
                                final updatedComponent =
                                    component.copyWithCommon(habits: updatedHabits);
                                final updatedComponents = components
                                    .map((c) => c.id == component.id ? updatedComponent : c)
                                    .toList();
                                await onSaveBoardComponents(id, updatedComponents);
                                setLocal(() {
                                  componentsByBoardId[id] = updatedComponents;
                                });
                              },
                              title: Text(habit.name),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                            );
                          }),
                        ],
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

