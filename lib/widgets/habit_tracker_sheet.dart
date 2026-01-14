import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit_item.dart';
import '../models/vision_components.dart';
import 'habits/habit_tracker_header.dart';
import 'habits/habit_tracker_insights_tab.dart';
import 'habits/habit_tracker_tracker_tab.dart';

/// Modal bottom sheet for tracking habits associated with a canvas component.
class HabitTrackerSheet extends StatefulWidget {
  final VisionComponent component;
  final ValueChanged<VisionComponent> onComponentUpdated;

  const HabitTrackerSheet({
    super.key,
    required this.component,
    required this.onComponentUpdated,
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
    _habits = List<HabitItem>.from(widget.component.habits);
  }

  @override
  void dispose() {
    _newHabitController.dispose();
    super.dispose();
  }

  void _updateComponent() {
    final updatedComponent = widget.component.copyWithCommon(habits: _habits);
    widget.onComponentUpdated(updatedComponent);
  }

  void _toggleHabitCompletion(HabitItem habit) {
    setState(() {
      final int index = _habits.indexWhere((h) => h.id == habit.id);
      if (index != -1) {
        _habits[index] = habit.toggleToday();
        _updateComponent();
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
      _updateComponent();
    });
  }

  void _deleteHabit(HabitItem habit) {
    setState(() {
      _habits.removeWhere((h) => h.id == habit.id);
      _updateComponent();
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
          final last7DaysData = _getLast7DaysData();
          final maxCount = last7DaysData.isEmpty
              ? 1
              : last7DaysData
                  .map((d) => d['count'] as int)
                  .reduce((a, b) => a > b ? a : b);

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
                HabitTrackerHeader(
                  component: widget.component,
                  onClose: () => Navigator.of(context).pop(),
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
                      HabitTrackerTab(
                        scrollController: scrollController,
                        habits: _habits,
                        newHabitController: _newHabitController,
                        onAddHabit: _addNewHabit,
                        onToggleHabit: _toggleHabitCompletion,
                        onDeleteHabit: _deleteHabit,
                      ),
                      HabitInsightsTab(
                        scrollController: scrollController,
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        onFocusedDayChanged: (d) => setState(() => _focusedDay = d),
                        onSelectedDayChanged: (d) => setState(() => _selectedDay = d),
                        isAnyHabitCompletedOnDate: _isAnyHabitCompletedOnDate,
                        last7DaysData: last7DaysData,
                        maxCount: maxCount,
                      ),
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
}
