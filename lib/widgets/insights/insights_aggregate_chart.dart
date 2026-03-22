import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/insights_month_summary.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';
import '../../utils/app_colors.dart';

/// Line chart showing aggregate habit completions per day for the selected month.
/// Used in the "All habits" view on the Insights screen.
class InsightsAggregateChart extends StatefulWidget {
  const InsightsAggregateChart({
    super.key,
    required this.habits,
    required this.year,
    required this.month,
  });

  final List<HabitItem> habits;
  final int year;
  final int month;

  @override
  State<InsightsAggregateChart> createState() => _InsightsAggregateChartState();
}

class _InsightsAggregateChartState extends State<InsightsAggregateChart> {
  bool _grown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _grown = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final summary = InsightsMonthSummary.forMonth(widget.year, widget.month);
    final perDay = InsightsMonthSummary.aggregateCompletionsPerDay(
      widget.habits,
      summary,
    );
    final n = summary.daysInMonth;
    final logicalToday = LogicalDateService.today();
    final isCurrentMonth =
        widget.year == logicalToday.year && widget.month == logicalToday.month;

    final peak = perDay.isEmpty ? 0 : perDay.reduce((a, b) => a > b ? a : b);
    final maxY = (peak > widget.habits.length
            ? peak.toDouble()
            : widget.habits.length.toDouble()) +
        2;

    final spots = List.generate(
      n,
      (i) => FlSpot((i + 1).toDouble(), perDay[i].toDouble()),
    );

    final displayData = LineChartData(
      minX: 1,
      maxX: n.toDouble(),
      minY: 0,
      maxY: maxY,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxY > 10 ? 2 : 1,
        getDrawingHorizontalLine: (_) => FlLine(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: maxY > 10 ? 2 : 1,
            getTitlesWidget: (value, meta) {
              if (value == meta.max || value == meta.min) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  value.toInt().toString(),
                  style: AppTypography.caption(context).copyWith(
                    color:
                        colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: n <= 10 ? 1 : (n <= 20 ? 2 : 5),
            getTitlesWidget: (value, meta) {
              final d = value.toInt();
              if (d < 1 || d > n) return const SizedBox.shrink();
              final interval = n <= 10 ? 1 : (n <= 20 ? 2 : 5);
              if (d != 1 && d != n && d % interval != 0) {
                return const SizedBox.shrink();
              }
              // Skip intermediate label when it's too close to the last day.
              if (d != n && (n - d) < interval) {
                return const SizedBox.shrink();
              }
              final isToday = isCurrentMonth && d == logicalToday.day;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '$d',
                  style: AppTypography.caption(context).copyWith(
                    fontWeight:
                        isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isToday
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
          getTooltipItems: (spots) => spots
              .map(
                (s) => LineTooltipItem(
                  '${s.y.toInt()} habits',
                  AppTypography.caption(context).copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              .toList(),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.35,
          preventCurveOverShooting: true,
          color: colorScheme.primary,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, _) => spot.y > 0,
            getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
              radius: 4,
              color: colorScheme.primary,
              strokeWidth: 2,
              strokeColor: AppColors.cloudWhite,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primary.withValues(alpha: 0.25),
                colorScheme.primary.withValues(alpha: 0.02),
              ],
            ),
          ),
        ),
      ],
    );

    final zeroedData = displayData.copyWith(
      lineBarsData: displayData.lineBarsData
          .map((b) => b.copyWith(
                spots: b.spots.map((s) => FlSpot(s.x, 0)).toList(),
              ))
          .toList(),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'All Habits — Activity',
                  style: AppTypography.heading3(context),
                ),
              ),
              Image.asset(
                'assets/icon/app_icon.png',
                width: 18,
                height: 18,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Habit Seeding',
                style: AppTypography.caption(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 200,
            child: LineChart(
              _grown ? displayData : zeroedData,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}
