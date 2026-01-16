import 'package:flutter/material.dart';

import '../models/habit_item.dart';
import '../models/vision_components.dart';

class HabitsListScreen extends StatefulWidget {
  final List<VisionComponent> components;
  final ValueChanged<List<VisionComponent>> onComponentsUpdated;
  final bool showAppBar;

  const HabitsListScreen({
    super.key,
    required this.components,
    required this.onComponentsUpdated,
    this.showAppBar = true,
  });

  @override
  State<HabitsListScreen> createState() => _HabitsListScreenState();
}

class _HabitsListScreenState extends State<HabitsListScreen> {
  void _toggleHabit(VisionComponent component, HabitItem habit) {
    final updatedHabit = habit.toggleForDate(DateTime.now());
    final updatedHabits =
        component.habits.map((h) => h.id == habit.id ? updatedHabit : h).toList();
    final updatedComponent = component.copyWithCommon(habits: updatedHabits);
    final updatedComponents =
        widget.components.map((c) => c.id == component.id ? updatedComponent : c).toList();
    widget.onComponentsUpdated(updatedComponents);
  }

  @override
  Widget build(BuildContext context) {
    final componentsWithHabits =
        widget.components.where((c) => c.habits.isNotEmpty).toList();

    if (componentsWithHabits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No habits found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text('Tap a goal on the canvas to add habits', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final body = ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: componentsWithHabits.length,
        itemBuilder: (context, index) {
          final component = componentsWithHabits[index];
          final displayTitle = (component is ImageComponent && (component.goal?.title ?? '').trim().isNotEmpty)
              ? component.goal!.title!.trim()
              : component.id;
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  width: double.infinity,
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                ...component.habits.map((habit) {
                  final now = DateTime.now();
                  final scheduledToday = habit.isScheduledOnDate(now);
                  final isCompleted = scheduledToday && habit.isCompletedForCurrentPeriod(now);
                  return ListTile(
                    leading: Checkbox(
                      value: isCompleted,
                      onChanged: scheduledToday ? (_) => _toggleHabit(component, habit) : null,
                    ),
                    title: Text(
                      habit.name,
                      style: TextStyle(
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey : null,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (!scheduledToday)
                          const Text('Not scheduled today', style: TextStyle(color: Colors.grey)),
                        if (habit.currentStreak > 0) ...[
                          const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '${habit.currentStreak} ${habit.isWeekly ? 'week' : 'day'} streak',
                          ),
                        ] else
                          const Text('No streak yet', style: TextStyle(color: Colors.grey)),
                        if ((habit.deadline ?? '').trim().isNotEmpty) ...[
                          const SizedBox(width: 10),
                          const Text('•', style: TextStyle(color: Colors.grey)),
                          const SizedBox(width: 10),
                          Text('Due ${habit.deadline}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      );

    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('All Habits'), automaticallyImplyLeading: false),
      body: body,
    );
  }
}

