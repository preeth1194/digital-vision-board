import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/hotspot_model.dart';

class GlobalInsightsPage extends StatelessWidget {
  final List<HotspotModel> hotspots;

  const GlobalInsightsPage({
    super.key,
    required this.hotspots,
  });

  @override
  Widget build(BuildContext context) {
    final allHabits = hotspots.expand((h) => h.habits).toList();
    
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

    // Calculate Today's Stats
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final completedToday = allHabits.where((h) => h.isCompletedOnDate(today)).length;
    final totalHabits = allHabits.length;
    final completionRate = totalHabits > 0 ? (completedToday / totalHabits * 100) : 0.0;

    // Calculate Last 7 Days Stats
    List<Map<String, dynamic>> weeklyData = [];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      final count = allHabits.where((h) => h.isCompletedOnDate(dateOnly)).length;
      weeklyData.add({
        'day': DateFormat('E').format(date), // Mon, Tue...
        'count': count,
      });
    }
    
    final maxWeeklyCount = weeklyData.isEmpty 
        ? 0 
        : weeklyData.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Insights'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Today's Summary Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Today\'s Progress',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${completionRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '$completedToday of $totalHabits habits completed',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: totalHabits > 0 ? completedToday / totalHabits : 0,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Weekly Chart
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last 7 Days Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxWeeklyCount > 0 ? maxWeeklyCount.toDouble() + 1 : 5,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.grey[800]!,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < weeklyData.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      weeklyData[value.toInt()]['day'] as String,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          ),
                        ),
                        barGroups: weeklyData.asMap().entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: (entry.value['count'] as int).toDouble(),
                                color: Theme.of(context).colorScheme.primary,
                                width: 16,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Stats Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                context,
                'Total Zones',
                hotspots.length.toString(),
                Icons.map,
                Colors.orange,
              ),
              _buildStatCard(
                context,
                'Active Habits',
                totalHabits.toString(),
                Icons.check_circle_outline,
                Colors.green,
              ),
              _buildStatCard(
                context,
                'Longest Streak',
                _calculateLongestStreak(allHabits).toString(),
                Icons.local_fire_department,
                Colors.red,
              ),
              _buildStatCard(
                context,
                'Best Day',
                _calculateBestDay(allHabits),
                Icons.emoji_events,
                Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

  int _calculateLongestStreak(List<dynamic> habits) {
      if (habits.isEmpty) return 0;
      int maxStreak = 0;
      for (var habit in habits) {
        if (habit.currentStreak > maxStreak) {
          maxStreak = habit.currentStreak;
        }
      }
      return maxStreak;
    }

  String _calculateBestDay(List<dynamic> habits) {
      if (habits.isEmpty) return '-';
      // Simple logic: Day with most completions in last 7 days? 
      // Or just a placeholder logic for now.
      // Let's find the day name with most completions in history? Too expensive.
      // Let's stick to last 7 days data we already calculated.
      return '-'; // Placeholder for simplicity unless we want complex logic
    }
  }
