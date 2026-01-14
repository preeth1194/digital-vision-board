import 'package:flutter/material.dart';
import '../models/habit_item.dart';
import '../models/vision_component.dart';

class HabitsListPage extends StatefulWidget {
  final List<VisionComponent> components;
  final ValueChanged<List<VisionComponent>> onComponentsUpdated;

  const HabitsListPage({
    super.key,
    required this.components,
    required this.onComponentsUpdated,
  });

  @override
  State<HabitsListPage> createState() => _HabitsListPageState();
}

class _HabitsListPageState extends State<HabitsListPage> {
  void _toggleHabit(VisionComponent component, HabitItem habit) {
    final updatedHabit = habit.toggleToday();
    
    // Create updated habits list for this hotspot
    final updatedHabits = component.habits.map((h) {
      return h.id == habit.id ? updatedHabit : h;
    }).toList();

    // Create updated component
    final updatedComponent = component.copyWithCommon(habits: updatedHabits);

    // Update the list of components
    final updatedComponents = widget.components.map((c) {
      if (c.id == component.id) return updatedComponent;
      return c;
    }).toList();

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
            Text(
              'Add habits to your zones in Edit Mode',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Habits'),
        automaticallyImplyLeading: false,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: componentsWithHabits.length,
        itemBuilder: (context, index) {
          final component = componentsWithHabits[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hotspot Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  width: double.infinity,
                  child: Text(
                    component.id,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // Habits List
                ...component.habits.map((habit) {
                  final bool isCompleted = habit.isCompletedOnDate(DateTime.now());
                  return ListTile(
                    leading: Checkbox(
                      value: isCompleted,
                      onChanged: (_) => _toggleHabit(component, habit),
                    ),
                    title: Text(
                      habit.name,
                      style: TextStyle(
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        color: isCompleted ? Colors.grey : null,
                      ),
                    ),
                    subtitle: habit.currentStreak > 0
                        ? Row(
                            children: [
                              const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text('${habit.currentStreak} day streak'),
                            ],
                          )
                        : null,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}
