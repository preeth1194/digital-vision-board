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
    final allChecklist = components
        .expand((c) => c.tasks)
        .expand((t) => t.checklist)
        .toList();

    if (allHabits.isEmpty && allChecklist.isEmpty) {
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
    final completedChecklistToday = allChecklist.where((c) => c.completedOn == isoToday).length;
    final totalTrackables = allHabits.length + allChecklist.length;
    final completedToday = completedHabitsToday + completedChecklistToday;
    final completionRate = totalTrackables > 0 ? (completedToday / totalTrackables * 100) : 0.0;

    final weeklyData = <({String day, int count})>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      final iso = _toIsoDate(dateOnly);
      final count =
          allHabits.where((h) => h.isCompletedOnDate(dateOnly)).length +
          allChecklist.where((c) => c.completedOn == iso).length;
      weeklyData.add((day: DateFormat('E').format(date), count: count));
    }
    final maxWeeklyCount = weeklyData.isEmpty
        ? 0
        : weeklyData.map((d) => d.count).reduce((a, b) => a > b ? a : b);

    final checklistDueToday = allChecklist.where((c) => (c.dueDate ?? '') == isoToday && !c.isCompleted).length;
    final checklistOverdue = allChecklist.where((c) {
      final due = (c.dueDate ?? '').trim();
      if (due.isEmpty) return false;
      if (c.isCompleted) return false;
      return due.compareTo(isoToday) < 0;
    }).length;

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
              title: 'Checklist done today',
              value: completedChecklistToday.toString(),
              icon: Icons.checklist,
              color: Colors.blue,
            ),
            StatCard(
              title: 'Checklist due today',
              value: checklistDueToday.toString(),
              icon: Icons.event_outlined,
              color: Colors.purple,
            ),
            StatCard(
              title: 'Checklist overdue',
              value: checklistOverdue.toString(),
              icon: Icons.warning_amber_outlined,
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

  static String _toIsoDate(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
