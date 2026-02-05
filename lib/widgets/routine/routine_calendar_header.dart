import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/routine.dart';
import '../../utils/app_colors.dart';

/// Calendar header widget for the routine screen.
/// Displays:
/// - Month/year with calendar icon and "Today" button
/// - Horizontal week day selector with completion indicators
class RoutineCalendarHeader extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final List<Routine> routines;

  const RoutineCalendarHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.routines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Calendar row
            _buildCalendarRow(context),
            const SizedBox(height: 8),
            // Week selector (5 days centered on selected date)
            _WeekDaySelector(
              selectedDate: selectedDate,
              onDateSelected: onDateSelected,
              routines: routines,
              daysToShow: 7,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarRow(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthYearFormat = DateFormat('MMMM yyyy');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Calendar icon + Month/Year
          GestureDetector(
            onTap: () => _showMonthPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    monthYearFormat.format(selectedDate),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Today button - always enabled to allow resetting to current date
          ElevatedButton(
            onPressed: () => onDateSelected(today),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.medium,
              foregroundColor: Colors.white,
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Today',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonthPicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.day,
    );
    
    if (picked != null) {
      onDateSelected(picked);
    }
  }
}

/// Horizontal week day selector
class _WeekDaySelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final List<Routine> routines;
  final int daysToShow;

  const _WeekDaySelector({
    required this.selectedDate,
    required this.onDateSelected,
    required this.routines,
    this.daysToShow = 7,
  });

  @override
  State<_WeekDaySelector> createState() => _WeekDaySelectorState();
}

class _WeekDaySelectorState extends State<_WeekDaySelector> {
  late PageController _pageController;
  late DateTime _currentRangeStart;

  int get _daysToShow => widget.daysToShow;

  @override
  void initState() {
    super.initState();
    _currentRangeStart = _getRangeStart(widget.selectedDate);
    _pageController = PageController(initialPage: 500);
  }

  @override
  void didUpdateWidget(_WeekDaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If selected date changed to a different range, scroll to that range
    final newRangeStart = _getRangeStart(widget.selectedDate);
    if (!_isSameDay(newRangeStart, _currentRangeStart)) {
      final rangeDiff = newRangeStart.difference(_currentRangeStart).inDays ~/ _daysToShow;
      final currentPage = _pageController.page?.round() ?? 500;
      _pageController.animateToPage(
        currentPage + rangeDiff,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      _currentRangeStart = newRangeStart;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getRangeStart(DateTime date) {
    // Center the selected date in the range
    final offset = _daysToShow ~/ 2;
    return DateTime(date.year, date.month, date.day - offset);
  }

  DateTime _getRangeForPage(int page) {
    final rangeOffset = page - 500;
    return _currentRangeStart.add(Duration(days: rangeOffset * _daysToShow));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentRangeStart = _getRangeForPage(page);
          });
        },
        itemBuilder: (context, page) {
          final rangeStart = _getRangeForPage(page);
          return _buildDaysView(context, rangeStart);
        },
      ),
    );
  }

  Widget _buildDaysView(BuildContext context, DateTime rangeStart) {
    final days = List.generate(_daysToShow, (i) => rangeStart.add(Duration(days: i)));
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: days.map((date) {
          final isSelected = _isSameDay(date, widget.selectedDate);
          final isToday = _isSameDay(date, normalizedToday);

          return _DateItem(
            date: date,
            isSelected: isSelected,
            isToday: isToday,
            onTap: () => widget.onDateSelected(date),
          );
        }).toList(),
      ),
    );
  }
}

class _DateItem extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final VoidCallback onTap;

  const _DateItem({
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  static const _weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bgColor = isSelected
        ? AppColors.medium
        : Colors.transparent;

    final textColor = isSelected
        ? Colors.white
        : colorScheme.onSurface;

    final weekdayColor = isSelected
        ? Colors.white.withOpacity(0.8)
        : colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 44,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.medium, width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _weekdays[date.weekday % 7],
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: weekdayColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
