import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../../models/routine.dart';

/// A horizontal week view date selector for the routine timeline.
class RoutineDateSelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final List<Routine> routines;

  const RoutineDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.routines,
  });

  @override
  State<RoutineDateSelector> createState() => _RoutineDateSelectorState();
}

class _RoutineDateSelectorState extends State<RoutineDateSelector> {
  late PageController _pageController;
  late DateTime _currentWeekStart;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(widget.selectedDate);
    // Start at middle page (page 500) to allow scrolling both directions
    _pageController = PageController(initialPage: 500);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    // Get Monday of the week
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  DateTime _getWeekForPage(int page) {
    // Page 500 is the current week
    final weekOffset = page - 500;
    return _currentWeekStart.add(Duration(days: weekOffset * 7));
  }

  bool _hasRoutinesOnDate(DateTime date) {
    return widget.routines.any((routine) => routine.occursOnDate(date));
  }

  double _getCompletionForDate(DateTime date) {
    final routinesForDate = widget.routines.where((r) => r.occursOnDate(date)).toList();
    if (routinesForDate.isEmpty) return 0.0;
    
    double totalCompletion = 0;
    for (final routine in routinesForDate) {
      totalCompletion += routine.getCompletionPercentageForDate(date);
    }
    return totalCompletion / routinesForDate.length;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 100,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          // Optional: Auto-select first day of new week when swiping
        },
        itemBuilder: (context, page) {
          final weekStart = _getWeekForPage(page);
          return _buildWeekView(context, weekStart, colorScheme);
        },
      ),
    );
  }

  Widget _buildWeekView(BuildContext context, DateTime weekStart, ColorScheme colorScheme) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: days.map((date) {
          final isSelected = _isSameDay(date, widget.selectedDate);
          final isToday = _isSameDay(date, normalizedToday);
          final hasRoutines = _hasRoutinesOnDate(date);
          final completion = _getCompletionForDate(date);

          return _DateItem(
            date: date,
            isSelected: isSelected,
            isToday: isToday,
            hasRoutines: hasRoutines,
            completion: completion,
            onTap: () => widget.onDateSelected(date),
          );
        }).toList(),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateItem extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool hasRoutines;
  final double completion;
  final VoidCallback onTap;

  const _DateItem({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.hasRoutines,
    required this.completion,
    required this.onTap,
  });

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isSelected
        ? colorScheme.primary
        : isToday
            ? colorScheme.primaryContainer
            : Colors.transparent;

    final textColor = isSelected
        ? colorScheme.onPrimary
        : isToday
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface;

    final weekdayColor = isSelected
        ? colorScheme.onPrimary.withOpacity(0.7)
        : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _weekdays[date.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: weekdayColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            // Completion indicator
            if (hasRoutines)
              _CompletionDot(
                completion: completion,
                isSelected: isSelected,
              )
            else
              const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _CompletionDot extends StatelessWidget {
  final double completion;
  final bool isSelected;

  const _CompletionDot({
    required this.completion,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color dotColor;
    if (completion >= 1.0) {
      dotColor = isSelected ? colorScheme.onPrimary : AppColors.medium;
    } else if (completion > 0) {
      dotColor = isSelected 
          ? colorScheme.onPrimary.withOpacity(0.6)
          : AppColors.light;
    } else {
      dotColor = isSelected 
          ? colorScheme.onPrimary.withOpacity(0.3)
          : colorScheme.outlineVariant;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dotColor,
      ),
    );
  }
}
