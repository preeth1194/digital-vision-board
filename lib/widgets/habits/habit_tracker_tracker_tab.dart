import 'package:flutter/material.dart';

import '../../models/habit_item.dart';

class HabitTrackerTab extends StatelessWidget {
  final ScrollController scrollController;
  final List<HabitItem> habits;
  final TextEditingController newHabitController;
  final VoidCallback onAddHabit;
  final ValueChanged<HabitItem> onToggleHabit;
  final ValueChanged<HabitItem> onDeleteHabit;

  const HabitTrackerTab({
    super.key,
    required this.scrollController,
    required this.habits,
    required this.newHabitController,
    required this.onAddHabit,
    required this.onToggleHabit,
    required this.onDeleteHabit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: newHabitController,
                    decoration: const InputDecoration(
                      hintText: 'Enter new habit name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onSubmitted: (_) => onAddHabit(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: onAddHabit,
                  tooltip: 'Add Habit',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (habits.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No habits yet. Add one above!', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...habits.map((habit) {
            final isTodayCompleted = habit.isCompletedOnDate(DateTime.now());
            final streak = habit.currentStreak;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Checkbox(
                  value: isTodayCompleted,
                  onChanged: (_) => onToggleHabit(habit),
                ),
                title: Text(habit.name),
                subtitle: Row(
                  children: [
                    if (streak > 0) ...[
                      const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('$streak day${streak != 1 ? 's' : ''} streak'),
                    ] else
                      const Text('No streak yet', style: TextStyle(color: Colors.grey)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Habit'),
                        content: Text('Delete "${habit.name}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              onDeleteHabit(habit);
                            },
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}

