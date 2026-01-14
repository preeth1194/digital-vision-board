import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/vision_components.dart';
import '../widgets/insights/stat_card.dart';
import '../widgets/insights/today_progress_card.dart';
import '../widgets/insights/weekly_activity_card.dart';

class GlobalInsightsScreen extends StatelessWidget {
  final List<VisionComponent> components;

  const GlobalInsightsScreen({super.key, required this.components});

  @override
  Widget build(BuildContext context) {
    final allHabits = components.expand((c) => c.habits).toList();

    if (allHabits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No habits to analyze yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedToday = allHabits.where((h) => h.isCompletedOnDate(today)).length;
    final totalHabits = allHabits.length;
    final completionRate = totalHabits > 0 ? (completedToday / totalHabits * 100) : 0.0;

    final weeklyData = <({String day, int count})>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      final count = allHabits.where((h) => h.isCompletedOnDate(dateOnly)).length;
      weeklyData.add((day: DateFormat('E').format(date), count: count));
    }
    final maxWeeklyCount = weeklyData.isEmpty
        ? 0
        : weeklyData.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TodayProgressCard(
          completionRate: completionRate,
          completedToday: completedToday,
          totalHabits: totalHabits,
        ),
        const SizedBox(height: 24),
        WeeklyActivityCard(weeklyData: weeklyData, maxWeeklyCount: maxWeeklyCount),
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
              title: 'Total Zones',
              value: components.whereType<ZoneComponent>().length.toString(),
              icon: Icons.map,
              color: Colors.orange,
            ),
            StatCard(
              title: 'Active Habits',
              value: totalHabits.toString(),
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            StatCard(
              title: 'Longest Streak',
              value: _calculateLongestStreak(allHabits).toString(),
              icon: Icons.local_fire_department,
              color: Colors.red,
            ),
            const StatCard(
              title: 'Best Day',
              value: '-',
              icon: Icons.emoji_events,
              color: Colors.amber,
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
