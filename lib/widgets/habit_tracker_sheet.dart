import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hotspot_model.dart';
import '../models/habit_item.dart';

/// Modal bottom sheet for tracking habits associated with a hotspot
class HabitTrackerSheet extends StatefulWidget {
  final HotspotModel hotspot;
  final ValueChanged<HotspotModel> onHotspotUpdated;

  const HabitTrackerSheet({
    super.key,
    required this.hotspot,
    required this.onHotspotUpdated,
  });

  @override
  State<HabitTrackerSheet> createState() => _HabitTrackerSheetState();
}

class _HabitTrackerSheetState extends State<HabitTrackerSheet> {
  late List<HabitItem> _habits;
  final TextEditingController _newHabitController = TextEditingController();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _habits = List<HabitItem>.from(widget.hotspot.habits);
  }

  @override
  void dispose() {
    _newHabitController.dispose();
    super.dispose();
  }

  void _updateHotspot() {
    final updatedHotspot = widget.hotspot.copyWith(habits: _habits);
    widget.onHotspotUpdated(updatedHotspot);
  }

  void _toggleHabitCompletion(HabitItem habit) {
    setState(() {
      final int index = _habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        _habits[index] = habit.toggleToday();
        _updateHotspot();
      }
    });
  }

  void _addNewHabit() {
    final String habitName = _newHabitController.text.trim();
    if (habitName.isEmpty) return;

    setState(() {
      final String newId = DateTime.now().millisecondsSinceEpoch.toString();
      _habits.add(HabitItem(
        id: newId,
        name: habitName,
        completedDates: [],
      ));
      _newHabitController.clear();
      _updateHotspot();
    });
  }

  void _deleteHabit(HabitItem habit) {
    setState(() {
      _habits.removeWhere((h) => h.id == habit.id);
      _updateHotspot();
    });
  }

  /// Check if any habit was completed on a specific date
  bool _isAnyHabitCompletedOnDate(DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    return _habits.any((habit) => habit.isCompletedOnDate(normalizedDate));
  }

  /// Get the total number of habits completed on a specific date
  int _getCompletionCountForDate(DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    int count = 0;
    for (final habit in _habits) {
      if (habit.isCompletedOnDate(normalizedDate)) {
        count++;
      }
    }
    return count;
  }

  /// Get completion data for the last 7 days
  List<Map<String, dynamic>> _getLast7DaysData() {
    final List<Map<String, dynamic>> data = [];
    final DateTime now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final DateTime date = now.subtract(Duration(days: i));
      final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
      final int count = _getCompletionCountForDate(normalizedDate);
      final String dayName = DateFormat('EEE').format(date);
      
      data.add({
        'date': normalizedDate,
        'count': count,
        'dayName': dayName,
      });
    }
    
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.hotspot.id ?? 'Untitled Goal',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            if (widget.hotspot.link != null &&
                                widget.hotspot.link!.isNotEmpty)
                              TextButton.icon(
                                onPressed: () async {
                                  try {
                                    final Uri url = Uri.parse(widget.hotspot.link!);
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Could not open link: $e'),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open Link'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  // Remove minimum size constraints to make it compact
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                // Tabs
                const TabBar(
                  tabs: [
                    Tab(text: 'Tracker', icon: Icon(Icons.check_circle_outline)),
                    Tab(text: 'Insights', icon: Icon(Icons.insights)),
                  ],
                ),
                // Tab Content
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildTrackerTab(scrollController),
                      _buildInsightsTab(scrollController),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrackerTab(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Add New Habit
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newHabitController,
                    decoration: const InputDecoration(
                      hintText: 'Enter new habit name',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _addNewHabit(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle),
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: _addNewHabit,
                  tooltip: 'Add Habit',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Habits List
        if (_habits.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No habits yet. Add one above!',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ..._habits.map((habit) {
            final bool isTodayCompleted = habit.isCompletedOnDate(DateTime.now());
            final int streak = habit.currentStreak;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Checkbox(
                  value: isTodayCompleted,
                  onChanged: (_) => _toggleHabitCompletion(habit),
                ),
                title: Text(habit.name),
                subtitle: Row(
                  children: [
                    if (streak > 0) ...[
                      const Icon(Icons.local_fire_department,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text('$streak day${streak != 1 ? 's' : ''} streak'),
                    ] else
                      const Text('No streak yet',
                          style: TextStyle(color: Colors.grey)),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    showDialog(
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
                              _deleteHabit(habit);
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

  Widget _buildInsightsTab(ScrollController scrollController) {
    final last7DaysData = _getLast7DaysData();
    final maxCount = last7DaysData.isEmpty
        ? 1
        : last7DaysData.map((d) => d['count'] as int).reduce((a, b) => a > b ? a : b);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Calendar View
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monthly Calendar',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) {
                    final DateTime normalizedDay = DateTime(day.year, day.month, day.day);
                    final DateTime normalizedSelected = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
                    return normalizedDay == normalizedSelected;
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  eventLoader: (day) {
                    if (_isAnyHabitCompletedOnDate(day)) {
                      return [1]; // Return a list to show marker
                    }
                    return [];
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          bottom: 1,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Bar Chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last 7 Days',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxCount > 0 ? maxCount.toDouble() + 1 : 1,
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
                              if (value.toInt() >= 0 &&
                                  value.toInt() < last7DaysData.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    last7DaysData[value.toInt()]['dayName'] as String,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                            reservedSize: 30,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              if (value == value.toInt()) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200]!,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      barGroups: last7DaysData.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final int count = entry.value['count'] as int;
                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: count.toDouble(),
                              color: Theme.of(context).colorScheme.primary,
                              width: 20,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
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
      ],
    );
  }
}
