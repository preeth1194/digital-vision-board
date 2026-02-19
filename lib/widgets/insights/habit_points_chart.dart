import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/habit_item.dart';

enum _TimeRange { week, month, year }

const _habitColors = [
  Color(0xFF4A7C59),
  Color(0xFF5B8DBE),
  Color(0xFFE57373),
  Color(0xFFFFB74D),
  Color(0xFF9575CD),
  Color(0xFF4DB6AC),
  Color(0xFFFF8A65),
  Color(0xFF7986CB),
  Color(0xFFAED581),
  Color(0xFFF06292),
];

class HabitPointsChart extends StatefulWidget {
  final List<HabitItem> habits;

  const HabitPointsChart({super.key, required this.habits});

  @override
  State<HabitPointsChart> createState() => _HabitPointsChartState();
}

class _HabitPointsChartState extends State<HabitPointsChart> {
  _TimeRange _selectedRange = _TimeRange.week;

  Color _colorForHabit(int index) => _habitColors[index % _habitColors.length];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Points by Habit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                _buildRangeSelector(colorScheme),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: _buildChart(colorScheme),
            ),
            if (widget.habits.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildLegend(colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector(ColorScheme colorScheme) {
    return Row(
      children: _TimeRange.values.map((range) {
        final selected = _selectedRange == range;
        final label = switch (range) {
          _TimeRange.week => '7D',
          _TimeRange.month => '30D',
          _TimeRange.year => '1Y',
        };
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => setState(() => _selectedRange = range),
            selectedColor: colorScheme.primary,
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            backgroundColor: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide.none,
            ),
            showCheckmark: false,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend(ColorScheme colorScheme) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: widget.habits.asMap().entries.map((entry) {
        final color = _colorForHabit(entry.key);
        final name = entry.value.name;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                name,
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildChart(ColorScheme colorScheme) {
    switch (_selectedRange) {
      case _TimeRange.week:
        return _buildWeekChart(colorScheme);
      case _TimeRange.month:
        return _buildMonthChart(colorScheme);
      case _TimeRange.year:
        return _buildYearChart(colorScheme);
    }
  }

  /// Compute cumulative points per habit for a list of dates.
  /// Returns a map: habitIndex -> list of FlSpots (one per date with x = xValue).
  _CumulativeResult _computeCumulative(List<DateTime> dates, double Function(int) xMapper) {
    double globalMax = 0;
    final Map<int, List<FlSpot>> spotsPerHabit = {};

    for (int hi = 0; hi < widget.habits.length; hi++) {
      final habit = widget.habits[hi];
      double cumulative = 0;
      final spots = <FlSpot>[];

      for (int di = 0; di < dates.length; di++) {
        final iso = dates[di].toIso8601String().split('T')[0];
        final feedback = habit.feedbackByDate[iso];
        cumulative += feedback?.coinsEarned ?? 0;
        spots.add(FlSpot(xMapper(di), cumulative));
      }

      if (cumulative > globalMax) globalMax = cumulative;
      spotsPerHabit[hi] = spots;
    }

    return _CumulativeResult(spotsPerHabit: spotsPerHabit, maxY: globalMax + 10);
  }

  Widget _buildWeekChart(ColorScheme colorScheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = <DateTime>[];
    final dayLabels = <String>[];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      dates.add(DateTime(date.year, date.month, date.day));
      dayLabels.add(DateFormat('E').format(date));
    }

    final result = _computeCumulative(dates, (di) => di.toDouble());

    return _lineChart(
      spotsPerHabit: result.spotsPerHabit,
      minX: 0,
      maxX: 6,
      maxY: result.maxY,
      colorScheme: colorScheme,
      bottomInterval: 1,
      getBottomTitle: (value) {
        final i = value.toInt();
        if (i < 0 || i >= dayLabels.length) return '';
        return dayLabels[i];
      },
      isTodayIndex: (value) => value.toInt() == 6,
    );
  }

  Widget _buildMonthChart(ColorScheme colorScheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = <DateTime>[];

    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      dates.add(DateTime(date.year, date.month, date.day));
    }

    final result = _computeCumulative(dates, (di) => (di + 1).toDouble());

    return _lineChart(
      spotsPerHabit: result.spotsPerHabit,
      minX: 1,
      maxX: 30,
      maxY: result.maxY,
      colorScheme: colorScheme,
      bottomInterval: 5,
      getBottomTitle: (value) {
        final d = value.toInt();
        if (d == 1 || d % 5 == 0 || d == 30) return '$d';
        return '';
      },
      isTodayIndex: (value) => value.toInt() == 30,
    );
  }

  Widget _buildYearChart(ColorScheme colorScheme) {
    const monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    double globalMax = 0;
    final Map<int, List<FlSpot>> spotsPerHabit = {};

    for (int hi = 0; hi < widget.habits.length; hi++) {
      final habit = widget.habits[hi];
      double cumulative = 0;
      final spots = <FlSpot>[];

      for (int m = 1; m <= 12; m++) {
        final daysInMonth = DateTime(now.year, m + 1, 0).day;
        final lastDay = (m == now.month) ? today.day : daysInMonth;
        if (m > now.month) break;

        for (int d = 1; d <= lastDay; d++) {
          final iso = DateTime(now.year, m, d).toIso8601String().split('T')[0];
          final feedback = habit.feedbackByDate[iso];
          cumulative += feedback?.coinsEarned ?? 0;
        }
        spots.add(FlSpot(m.toDouble(), cumulative));
      }

      if (cumulative > globalMax) globalMax = cumulative;
      spotsPerHabit[hi] = spots;
    }

    final maxY = globalMax + 10;

    final hasData = spotsPerHabit.values.any((spots) => spots.isNotEmpty);
    if (!hasData) {
      return Center(
        child: Text(
          'No points data this year.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return _lineChart(
      spotsPerHabit: spotsPerHabit,
      minX: 1,
      maxX: 12,
      maxY: maxY,
      colorScheme: colorScheme,
      bottomInterval: 1,
      getBottomTitle: (value) {
        final m = value.toInt();
        if (m < 1 || m > 12) return '';
        return monthLabels[m - 1];
      },
      isTodayIndex: (value) => value.toInt() == now.month,
    );
  }

  Widget _lineChart({
    required Map<int, List<FlSpot>> spotsPerHabit,
    required double minX,
    required double maxX,
    required double maxY,
    required ColorScheme colorScheme,
    required double bottomInterval,
    required String Function(double) getBottomTitle,
    required bool Function(double) isTodayIndex,
  }) {
    final lineBars = spotsPerHabit.entries.map((entry) {
      final color = _colorForHabit(entry.key);
      return LineChartBarData(
        spots: entry.value,
        isCurved: true,
        curveSmoothness: 0.35,
        preventCurveOverShooting: true,
        color: color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          checkToShowDot: (spot, barData) => spot.y > 0,
          getDotPainter: (spot, percent, bar, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: color,
              strokeWidth: 1.5,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
      );
    }).toList();

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 50 ? 10 : (maxY > 20 ? 5 : (maxY > 10 ? 2 : 1)),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: maxY > 50 ? 10 : (maxY > 20 ? 5 : (maxY > 10 ? 2 : 1)),
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: bottomInterval,
              getTitlesWidget: (value, meta) {
                final label = getBottomTitle(value);
                if (label.isEmpty) return const SizedBox.shrink();
                final today = isTodayIndex(value);
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: today ? FontWeight.w700 : FontWeight.w400,
                      color: today
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final habitIdx = s.barIndex;
              final habitName = habitIdx < widget.habits.length
                  ? widget.habits[habitIdx].name
                  : 'Habit';
              final color = _colorForHabit(habitIdx);
              return LineTooltipItem(
                '$habitName: ${s.y.toInt()} pts',
                TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: lineBars,
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }
}

class _CumulativeResult {
  final Map<int, List<FlSpot>> spotsPerHabit;
  final double maxY;

  const _CumulativeResult({required this.spotsPerHabit, required this.maxY});
}
