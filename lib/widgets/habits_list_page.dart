import 'package:flutter/material.dart';
import '../models/hotspot_model.dart';
import '../models/habit_item.dart';

class HabitsListPage extends StatefulWidget {
  final List<HotspotModel> hotspots;
  final ValueChanged<List<HotspotModel>> onHotspotsUpdated;

  const HabitsListPage({
    super.key,
    required this.hotspots,
    required this.onHotspotsUpdated,
  });

  @override
  State<HabitsListPage> createState() => _HabitsListPageState();
}

class _HabitsListPageState extends State<HabitsListPage> {
  void _toggleHabit(HotspotModel hotspot, HabitItem habit) {
    final updatedHabit = habit.toggleToday();
    
    // Create updated habits list for this hotspot
    final updatedHabits = hotspot.habits.map((h) {
      return h.id == habit.id ? updatedHabit : h;
    }).toList();

    // Create updated hotspot
    final updatedHotspot = hotspot.copyWith(habits: updatedHabits);

    // Update the list of hotspots
    final updatedHotspots = widget.hotspots.map((h) {
      // Use coordinate comparison or ID if available
      // Here we assume hotspot references might have changed, so we find by ID or identity
      if (h == hotspot) return updatedHotspot;
      // Fallback coordinate check if object identity fails (though map uses current objects)
      if (h.x == hotspot.x && h.y == hotspot.y && h.width == hotspot.width && h.height == hotspot.height) {
        return updatedHotspot;
      }
      return h;
    }).toList();

    widget.onHotspotsUpdated(updatedHotspots);
  }

  @override
  Widget build(BuildContext context) {
    final hotspotsWithHabits = widget.hotspots.where((h) => h.habits.isNotEmpty).toList();

    if (hotspotsWithHabits.isEmpty) {
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
        itemCount: hotspotsWithHabits.length,
        itemBuilder: (context, index) {
          final hotspot = hotspotsWithHabits[index];
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
                    hotspot.id ?? 'Untitled Zone',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // Habits List
                ...hotspot.habits.map((habit) {
                  final bool isCompleted = habit.isCompletedOnDate(DateTime.now());
                  return ListTile(
                    leading: Checkbox(
                      value: isCompleted,
                      onChanged: (_) => _toggleHabit(hotspot, habit),
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
