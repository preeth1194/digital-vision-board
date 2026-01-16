import 'package:flutter/material.dart';

import '../../models/habit_item.dart';

class HabitTrackerTab extends StatelessWidget {
  final List<HabitItem> habits;
  final TextEditingController newHabitController;
  final VoidCallback onAddHabit;
  final ValueChanged<HabitItem> onToggleHabit;
  final ValueChanged<HabitItem> onDeleteHabit;
  final ValueChanged<HabitItem> onEditHabit;

  const HabitTrackerTab({
    super.key,
    required this.habits,
    required this.newHabitController,
    required this.onAddHabit,
    required this.onToggleHabit,
    required this.onDeleteHabit,
    required this.onEditHabit,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
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
                      hintText: 'Enter habit name (optional)',
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
                  tooltip: 'Add habit',
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
            final today = DateTime.now();
            final scheduledToday = habit.isScheduledOnDate(today);
            final isTodayCompleted = scheduledToday && habit.isCompletedForCurrentPeriod(today);
            final streak = habit.currentStreak;
            final unit = habit.isWeekly ? 'week' : 'day';
            final weeklyDays = habit.hasWeeklySchedule
                ? habit.weeklyDays
                    .map((d) => const {
                          DateTime.monday: 'Mon',
                          DateTime.tuesday: 'Tue',
                          DateTime.wednesday: 'Wed',
                          DateTime.thursday: 'Thu',
                          DateTime.friday: 'Fri',
                          DateTime.saturday: 'Sat',
                          DateTime.sunday: 'Sun',
                        }[d])
                    .whereType<String>()
                    .join(', ')
                : null;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Checkbox(
                  value: isTodayCompleted,
                  onChanged: scheduledToday ? (_) => onToggleHabit(habit) : null,
                ),
                title: Text(habit.name),
                subtitle: Row(
                  children: [
                    if (!scheduledToday) const Text('Not scheduled today', style: TextStyle(color: Colors.grey)),
                    if (streak > 0) ...[
                      const Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('$streak $unit${streak != 1 ? 's' : ''} streak'),
                    ] else
                      const Text('No streak yet', style: TextStyle(color: Colors.grey)),
                    if ((weeklyDays ?? '').trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 10),
                      Text('Days $weeklyDays', style: const TextStyle(color: Colors.grey)),
                    ],
                    if ((habit.deadline ?? '').trim().isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Text('•', style: TextStyle(color: Colors.grey)),
                      const SizedBox(width: 10),
                      Text('Due ${habit.deadline}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit habit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => onEditHabit(habit),
                    ),
                    IconButton(
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
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

