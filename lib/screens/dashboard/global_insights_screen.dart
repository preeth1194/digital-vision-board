import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/vision_components.dart';
import '../models/goal_metadata.dart';
import '../../widgets/dashboard/stat_card.dart';
import '../../widgets/dashboard/today_progress_card.dart';
import '../../widgets/dashboard/weekly_activity_card.dart';

class GlobalInsightsScreen extends StatelessWidget {
  final List<VisionComponent> components;

  const GlobalInsightsScreen({super.key, required this.components});

  @override
  Widget build(BuildContext context) {
    final allHabits = components.expand((c) => c.habits).toList();
    final allTodos = _allGoalTodos(components);

    if (allHabits.isEmpty && allTodos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No activity to analyze yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isoToday = _toIsoDate(today);
    final completedHabitsToday = allHabits.where((h) => h.isCompletedOnDate(today)).length;
    final completedTodosToday = allTodos.where((t) => t.isCompleted && (t.completedAtMs != null)).length;
    final totalTrackables = allHabits.length + allTodos.length;
    final completedToday = completedHabitsToday + completedTodosToday;
    final completionRate = totalTrackables > 0 ? (completedToday / totalTrackables * 100) : 0.0;

    final weeklyData = <({String day, int count})>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      final count =
          allHabits.where((h) => h.isCompletedOnDate(dateOnly)).length +
          allTodos.where((t) {
            final ms = t.completedAtMs;
            if (ms == null) return false;
            final d = DateTime.fromMillisecondsSinceEpoch(ms);
            return d.year == dateOnly.year && d.month == dateOnly.month && d.day == dateOnly.day;
          }).length;
      weeklyData.add((day: DateFormat('E').format(date), count: count));
    }
    final maxWeeklyCount = weeklyData.isEmpty
        ? 0
        : weeklyData.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    final totalTodos = allTodos.length;
    final completedTodos = allTodos.where((t) => t.isCompleted).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TodayProgressCard(
          completionRate: completionRate,
          completedToday: completedToday,
          totalHabits: totalTrackables,
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
            StatCard(
              title: 'Todos done',
              value: completedTodos.toString(),
              icon: Icons.playlist_add_check,
              color: Colors.blue,
            ),
            StatCard(
              title: 'Todos total',
              value: totalTodos.toString(),
              icon: Icons.list_alt_outlined,
              color: Colors.purple,
            ),
            StatCard(
              title: 'Todos done today',
              value: completedTodosToday.toString(),
              icon: Icons.today_outlined,
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  static List<GoalTodoItem> _allGoalTodos(List<VisionComponent> components) {
    final out = <GoalTodoItem>[];
    for (final c in components) {
      GoalMetadata? meta;
      if (c is ImageComponent) meta = c.goal;
      if (c is GoalOverlayComponent) meta = c.goal;
      if (meta == null) continue;
      out.addAll(meta.todoItems.where((t) => t.text.trim().isNotEmpty));
    }
    return out;
  }

  static int _calculateLongestStreak(List<dynamic> habits) {
    var maxStreak = 0;
    for (final habit in habits) {
      final streak = (habit.currentStreak as int?) ?? 0;
      if (streak > maxStreak) maxStreak = streak;
    }
    return maxStreak;
  }

  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
