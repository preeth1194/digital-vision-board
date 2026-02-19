import 'package:flutter/material.dart';

import '../models/habit_item.dart';
import '../models/vision_components.dart';
import '../services/habit_storage_service.dart';
import '../widgets/insights/stat_card.dart';
import '../widgets/insights/today_progress_card.dart';
import '../widgets/insights/weekly_activity_card.dart';

class GlobalInsightsScreen extends StatefulWidget {
  final List<VisionComponent> components;

  const GlobalInsightsScreen({super.key, required this.components});

  @override
  State<GlobalInsightsScreen> createState() => _GlobalInsightsScreenState();
}

class _GlobalInsightsScreenState extends State<GlobalInsightsScreen> {
  List<HabitItem> _habits = const [];

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  @override
  void didUpdateWidget(GlobalInsightsScreen old) {
    super.didUpdateWidget(old);
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final habits = await HabitStorageService.loadAll();
    if (mounted) setState(() => _habits = habits);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allHabits = _habits;

    if (allHabits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights, size: 64, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No activity to analyze yet',
              style: TextStyle(fontSize: 18, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedHabitsToday = allHabits.where((h) => h.isCompletedOnDate(today)).length;
    final completionRate = allHabits.isNotEmpty ? (completedHabitsToday / allHabits.length * 100) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TodayProgressCard(
          completionRate: completionRate,
          completedToday: completedHabitsToday,
          totalHabits: allHabits.length,
        ),
        const SizedBox(height: 24),
        HabitTrendsChart(habits: allHabits),
        const SizedBox(height: 24),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            StatCard(
              title: 'Active Habits',
              value: allHabits.length.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            StatCard(
              title: 'Longest Streak',
              value: _calculateLongestStreak(allHabits).toString(),
              icon: Icons.local_fire_department,
              color: Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  static int _calculateLongestStreak(List<dynamic> habits) {
    var maxStreak = 0;
    for (final habit in habits) {
      final streak = (habit.currentStreak as int?) ?? 0;
      if (streak > maxStreak) maxStreak = streak;
    }
    return maxStreak;
  }
}
