import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/routine.dart';
import '../../utils/app_typography.dart';

/// Calendar header widget for the routine screen.
/// Displays:
/// - Month/year with calendar icon and "Today" button
/// - Horizontal week day selector with completion indicators
class RoutineCalendarHeader extends StatefulWidget {
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
  State<RoutineCalendarHeader> createState() => _RoutineCalendarHeaderState();
}

class _RoutineCalendarHeaderState extends State<RoutineCalendarHeader> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = widget.selectedDate;
  }

  @override
  void didUpdateWidget(RoutineCalendarHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      setState(() => _displayedMonth = widget.selectedDate);
    }
  }

  void _onVisibleWeekChanged(DateTime weekMidDate) {
    if (weekMidDate.month != _displayedMonth.month ||
        weekMidDate.year != _displayedMonth.year) {
      setState(() => _displayedMonth = weekMidDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildCalendarRow(context),
            const SizedBox(height: 8),
            _WeekDaySelector(
              selectedDate: widget.selectedDate,
              onDateSelected: widget.onDateSelected,
              onVisibleWeekChanged: _onVisibleWeekChanged,
              routines: widget.routines,
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      monthYearFormat.format(_displayedMonth),
                      key: ValueKey('${_displayedMonth.year}-${_displayedMonth.month}'),
                      style: AppTypography.bodySmall(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () => widget.onDateSelected(today),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Today',
              style: AppTypography.caption(context).copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimary,
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
      initialDate: widget.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.day,
    );
    
    if (picked != null) {
      widget.onDateSelected(picked);
    }
  }
}

/// Horizontal week day selector
class _WeekDaySelector extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime>? onVisibleWeekChanged;
  final List<Routine> routines;

  const _WeekDaySelector({
    required this.selectedDate,
    required this.onDateSelected,
    this.onVisibleWeekChanged,
    required this.routines,
  });

  @override
  State<_WeekDaySelector> createState() => _WeekDaySelectorState();
}

class _WeekDaySelectorState extends State<_WeekDaySelector> {
  late PageController _pageController;
  late DateTime _anchorWeekStart;
  static const int _centerPage = 500;

  @override
  void initState() {
    super.initState();
    _anchorWeekStart = _getWeekStart(widget.selectedDate);
    _pageController = PageController(initialPage: _centerPage);
  }

  @override
  void didUpdateWidget(_WeekDaySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isSameDay(widget.selectedDate, oldWidget.selectedDate)) {
      final targetWeekStart = _getWeekStart(widget.selectedDate);
      final weeksDiff = targetWeekStart.difference(_anchorWeekStart).inDays ~/ 7;
      final targetPage = _centerPage + weeksDiff;
      final currentPage = _pageController.page?.round() ?? _centerPage;
      if (currentPage != targetPage) {
        // Defer page change to avoid setState-during-build from onPageChanged
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if ((currentPage - targetPage).abs() > 3) {
            _pageController.jumpToPage(targetPage);
          } else {
            _pageController.animateToPage(
              targetPage,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Returns the Sunday that starts the calendar week containing [date].
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
    return DateTime(date.year, date.month, date.day - weekday);
  }

  DateTime _getRangeForPage(int page) {
    return _anchorWeekStart.add(Duration(days: (page - _centerPage) * 7));
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
          final weekStart = _getRangeForPage(page);
          // Report the Wednesday (mid-week) to determine the displayed month
          widget.onVisibleWeekChanged?.call(weekStart.add(const Duration(days: 3)));
        },
        itemBuilder: (context, page) {
          final rangeStart = _getRangeForPage(page);
          return _buildDaysView(context, rangeStart);
        },
      ),
    );
  }

  Widget _buildDaysView(BuildContext context, DateTime rangeStart) {
    final days = List.generate(7, (i) => rangeStart.add(Duration(days: i)));
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
        ? colorScheme.primary
        : Colors.transparent;

    final textColor = isSelected
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    final weekdayColor = isSelected
        ? colorScheme.onPrimary.withOpacity(0.8)
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
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _weekdays[date.weekday % 7],
              style: AppTypography.caption(context).copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: weekdayColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: AppTypography.body(context).copyWith(
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
