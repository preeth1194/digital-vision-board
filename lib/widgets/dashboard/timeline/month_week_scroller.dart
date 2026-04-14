import 'package:flutter/material.dart';

import '../../../utils/app_typography.dart';

class MonthWeekScroller extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime today;

  const MonthWeekScroller({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.today,
  });

  @override
  State<MonthWeekScroller> createState() => MonthWeekScrollerState();
}

class MonthWeekScrollerState extends State<MonthWeekScroller> {
  late PageController _pageController;

  DateTime get _monthStart =>
      DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedWeekIndex());
  }

  @override
  void didUpdateWidget(covariant MonthWeekScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_sameMonth(widget.selectedDate, oldWidget.selectedDate)) {
      final target = _selectedWeekIndex();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final current = (_pageController.page ?? target.toDouble()).round();
        if (current != target) {
          _pageController.animateToPage(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }
      });
      return;
    }
    _pageController.dispose();
    _pageController = PageController(initialPage: _selectedWeekIndex());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _weekStart(DateTime date) {
    final weekday = date.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
    return DateTime(date.year, date.month, date.day - weekday);
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _sameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  List<DateTime> _monthWeekStarts() {
    final first = _monthStart;
    final nextMonth = DateTime(first.year, first.month + 1, 1);
    final last = nextMonth.subtract(const Duration(days: 1));
    final firstWeekStart = _weekStart(first);
    final lastWeekStart = _weekStart(last);
    final totalWeeks =
        (lastWeekStart.difference(firstWeekStart).inDays ~/ 7) + 1;
    return List<DateTime>.generate(
      totalWeeks,
      (index) => firstWeekStart.add(Duration(days: index * 7)),
    );
  }

  int _selectedWeekIndex() {
    final starts = _monthWeekStarts();
    for (var i = 0; i < starts.length; i++) {
      final start = starts[i];
      final end = start.add(const Duration(days: 6));
      if (!widget.selectedDate.isBefore(start) &&
          !widget.selectedDate.isAfter(end)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final starts = _monthWeekStarts();
    return PageView.builder(
      controller: _pageController,
      itemCount: starts.length,
      itemBuilder: (context, index) {
        return MonthWeekRow(
          weekStart: starts[index],
          month: widget.selectedDate.month,
          selectedDate: widget.selectedDate,
          today: widget.today,
          onDateSelected: widget.onDateSelected,
          sameDay: _sameDay,
        );
      },
    );
  }
}

class MonthWeekRow extends StatelessWidget {
  final DateTime weekStart;
  final int month;
  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime> onDateSelected;
  final bool Function(DateTime a, DateTime b) sameDay;

  const MonthWeekRow({
    super.key,
    required this.weekStart,
    required this.month,
    required this.selectedDate,
    required this.today,
    required this.onDateSelected,
    required this.sameDay,
  });

  static const _weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final weekDates = List<DateTime>.generate(
      7,
      (index) => weekStart.add(Duration(days: index)),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: weekDates.asMap().entries.map((entry) {
        final index = entry.key;
        final date = entry.value;
        final inMonth = date.month == month;
        final isSelected = sameDay(date, selectedDate);
        final isToday = sameDay(date, today);
        final textColor = inMonth
            ? colorScheme.onSurface
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.45);

        return Expanded(
          child: InkWell(
            onTap: inMonth ? () => onDateSelected(date) : null,
            borderRadius: BorderRadius.circular(6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: EdgeInsets.symmetric(vertical: isSelected ? 8 : 4),
              constraints: BoxConstraints(minHeight: isSelected ? 40 : 36),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isToday && !isSelected
                    ? Border.all(color: colorScheme.primary, width: 1.6)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdays[index],
                    style: AppTypography.caption(context).copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: isSelected
                          ? colorScheme.onPrimary.withValues(alpha: 0.86)
                          : colorScheme.onSurfaceVariant.withValues(
                              alpha: inMonth ? 1 : 0.55,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: AppTypography.bodySmall(context).copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: isSelected ? colorScheme.onPrimary : textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
