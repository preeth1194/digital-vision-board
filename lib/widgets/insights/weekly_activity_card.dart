import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/habit_item.dart';
import '../../models/insights_month_summary.dart';
import '../../services/logical_date_service.dart';
import '../../utils/app_spacing.dart';
import '../../utils/app_typography.dart';

enum _ChartMode { activity, coins }

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

/// Calendar-month habit trends (activity aggregate or per-habit, coins cumulative).
class HabitTrendsChart extends StatefulWidget {
  final List<HabitItem> habits;
  final int year;
  final int month;
  final HabitItem? focusHabit;

  const HabitTrendsChart({
    super.key,
    required this.habits,
    required this.year,
    required this.month,
    this.focusHabit,
  });

  @override
  State<HabitTrendsChart> createState() => _HabitTrendsChartState();
}

class _HabitTrendsChartState extends State<HabitTrendsChart>
    with SingleTickerProviderStateMixin {
  _ChartMode _mode = _ChartMode.activity;

  late final AnimationController _legendController;
  late final Animation<double> _legendFade;

  int _slideDirection = 1;

  Color _colorForHabit(int index) => _habitColors[index % _habitColors.length];

  @override
  void initState() {
    super.initState();
    _legendController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _legendFade = CurvedAnimation(
      parent: _legendController,
      curve: Curves.easeInOutCubic,
    );
    if (_mode == _ChartMode.coins) {
      _legendController.value = 1;
    }
  }

  @override
  void dispose() {
    _legendController.dispose();
    super.dispose();
  }

  void _setMode(_ChartMode mode) {
    if (mode == _mode) return;
    setState(() {
      _slideDirection = mode == _ChartMode.coins ? 1 : -1;
      _mode = mode;
    });
    if (mode == _ChartMode.coins) {
      _legendController.forward();
    } else {
      _legendController.reverse();
    }
  }

  InsightsMonthSummary get _summary =>
      InsightsMonthSummary.forMonth(widget.year, widget.month);

  bool _isAxisToday(double x) {
    final logical = LogicalDateService.today();
    if (widget.year != logical.year || widget.month != logical.month) {
      return false;
    }
    return x.toInt() == logical.day;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keySuffix =
        '${widget.year}_${widget.month}_${widget.focusHabit?.id ?? 'all'}_${_mode.name}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Habit Trends',
                  style: AppTypography.heading3(context),
                ),
                const Spacer(),
                _buildModePills(colorScheme),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOutCubic,
                switchOutCurve: Curves.easeInOutCubic,
                transitionBuilder: (child, animation) {
                  final offsetIn = Tween<Offset>(
                    begin: Offset(0.15 * _slideDirection, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetIn,
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(keySuffix),
                  child: _mode == _ChartMode.activity
                      ? _buildActivityChart(colorScheme)
                      : _buildCoinsChart(colorScheme),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: _legendFade,
                child: _shouldShowLegend()
                    ? Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _buildLegend(colorScheme),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowLegend() {
    if (_mode != _ChartMode.coins) return false;
    if (widget.focusHabit != null) return false;
    return widget.habits.length > 1;
  }

  Widget _buildModePills(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modePill('Activity', _ChartMode.activity, colorScheme),
          _modePill('Coins', _ChartMode.coins, colorScheme),
        ],
      ),
    );
  }

  Widget _modePill(String label, _ChartMode mode, ColorScheme colorScheme) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => _setMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppTypography.caption(context).copyWith(
            fontWeight: FontWeight.w600,
            color: selected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildLegend(ColorScheme colorScheme) {
    final cardColor = Theme.of(context).cardColor;
    return SizedBox(
      height: 20,
      child: ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [
            Colors.transparent,
            cardColor,
            cardColor,
            Colors.transparent,
          ],
          stops: const [0.0, 0.03, 0.92, 1.0],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(bounds),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          physics: const BouncingScrollPhysics(),
          itemCount: widget.habits.length,
          separatorBuilder: (context, index) =>
              const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final color = _colorForHabit(index);
            final name = widget.habits[index].name;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: AppTypography.caption(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActivityChart(ColorScheme colorScheme) {
    final summary = _summary;
    final n = summary.daysInMonth;
    final habits = widget.habits;
    final focus = widget.focusHabit;

    if (habits.isEmpty) {
      return _emptyChart(colorScheme, 'No habits to chart.');
    }

    final List<FlSpot> spots;
    double maxY;

    if (focus != null) {
      final series = InsightsMonthSummary.habitCompletionSeries(focus, summary);
      spots = List.generate(
        n,
        (i) => FlSpot((i + 1).toDouble(), series[i].toDouble()),
      );
      maxY = 4;
    } else {
      final perDay = InsightsMonthSummary.aggregateCompletionsPerDay(
        habits,
        summary,
      );
      final peak = perDay.isEmpty ? 0 : perDay.reduce((a, b) => a > b ? a : b);
      spots = List.generate(
        n,
        (i) => FlSpot((i + 1).toDouble(), perDay[i].toDouble()),
      );
      maxY = (peak > habits.length ? peak : habits.length).toDouble() + 4;
    }

    return _singleLineChart(
      spots: spots,
      minX: 1,
      maxX: n.toDouble(),
      maxY: maxY,
      colorScheme: colorScheme,
      lineColor: colorScheme.primary,
      bottomInterval: _bottomTitleInterval(n),
      getBottomTitle: (v) => _bottomTitleForDay(v, n),
      isTodayIndex: _isAxisToday,
      coinsMode: false,
      aggregateActivity: focus == null,
    );
  }

  double _bottomTitleInterval(int n) {
    if (n <= 10) return 1;
    if (n <= 20) return 2;
    return 5;
  }

  String _bottomTitleForDay(double v, int n) {
    final d = v.toInt();
    if (d < 1 || d > n) return '';
    final interval = _bottomTitleInterval(n).toInt();
    if (d == 1 || d == n || d % interval == 0) return '$d';
    return '';
  }

  Widget _buildCoinsChart(ColorScheme colorScheme) {
    final summary = _summary;
    final n = summary.daysInMonth;
    final habits = widget.habits;
    final focus = widget.focusHabit;

    if (habits.isEmpty) {
      return _emptyChart(colorScheme, 'No habits to chart.');
    }

    if (focus != null) {
      final result = _computeCumulativeForHabits([focus], summary);
      if (result.maxY <= 0) {
        return _emptyChart(colorScheme, 'No coins this month yet.');
      }
      return _singleLineChart(
        spots: result.spotsPerHabit[0]!,
        minX: 1,
        maxX: n.toDouble(),
        maxY: result.maxY,
        colorScheme: colorScheme,
        lineColor: colorScheme.primary,
        bottomInterval: _bottomTitleInterval(n),
        getBottomTitle: (v) => _bottomTitleForDay(v, n),
        isTodayIndex: _isAxisToday,
        coinsMode: true,
      );
    }

    final result = _computeCumulativeForHabits(habits, summary);
    if (result.maxY <= 0) {
      return _emptyChart(colorScheme, 'No coins this month yet.');
    }

    return _multiLineChart(
      spotsPerHabit: result.spotsPerHabit,
      minX: 1,
      maxX: n.toDouble(),
      maxY: result.maxY,
      colorScheme: colorScheme,
      bottomInterval: _bottomTitleInterval(n),
      getBottomTitle: (v) => _bottomTitleForDay(v, n),
      isTodayIndex: _isAxisToday,
    );
  }

  Widget _emptyChart(ColorScheme colorScheme, String message) {
    return Center(
      child: Text(
        message,
        style: AppTypography.bodySmall(context).copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  _CumulativeResult _computeCumulativeForHabits(
    List<HabitItem> habits,
    InsightsMonthSummary summary,
  ) {
    double globalMax = 0;
    final Map<int, List<FlSpot>> spotsPerHabit = {};

    for (int hi = 0; hi < habits.length; hi++) {
      final habit = habits[hi];
      double cumulative = 0;
      final spots = <FlSpot>[];

      for (int di = 0; di < summary.days.length; di++) {
        final iso = LogicalDateService.toIsoDate(summary.days[di]);
        final feedback = habit.feedbackByDate[iso];
        cumulative += feedback?.coinsEarned ?? 0;
        spots.add(FlSpot((di + 1).toDouble(), cumulative));
      }

      if (cumulative > globalMax) globalMax = cumulative;
      spotsPerHabit[hi] = spots;
    }

    return _CumulativeResult(
      spotsPerHabit: spotsPerHabit,
      maxY: globalMax + 10,
    );
  }

  Widget _singleLineChart({
    required List<FlSpot> spots,
    required double minX,
    required double maxX,
    required double maxY,
    required ColorScheme colorScheme,
    required Color lineColor,
    required double bottomInterval,
    required String Function(double) getBottomTitle,
    required bool Function(double) isTodayIndex,
    required bool coinsMode,
    bool aggregateActivity = true,
  }) {
    return _GrowingLineChart(
      data: LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 20 ? 5 : (maxY > 10 ? 2 : 1),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _buildTitles(
          colorScheme: colorScheme,
          maxY: maxY,
          bottomInterval: bottomInterval,
          getBottomTitle: getBottomTitle,
          isTodayIndex: isTodayIndex,
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              final intVal = s.y.toInt();
              final val = intVal.toString();
              final String label;
              if (coinsMode) {
                label = '$val seeds';
              } else if (aggregateActivity) {
                label = '$val habits';
              } else {
                label = intVal >= 1 ? 'Completed' : 'Not completed';
              }
              return LineTooltipItem(
                label,
                AppTypography.bodySmall(context).copyWith(
                  color: lineColor,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) => spot.y > 0,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: lineColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.25),
                  lineColor.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multiLineChart({
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

    return _GrowingLineChart(
      data: LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval:
              maxY > 50 ? 10 : (maxY > 20 ? 5 : (maxY > 10 ? 2 : 1)),
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: _buildTitles(
          colorScheme: colorScheme,
          maxY: maxY,
          bottomInterval: bottomInterval,
          getBottomTitle: getBottomTitle,
          isTodayIndex: isTodayIndex,
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
                '$habitName: ${s.y.toInt()} seeds',
                AppTypography.caption(context).copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: lineBars,
      ),
    );
  }

  FlTitlesData _buildTitles({
    required ColorScheme colorScheme,
    required double maxY,
    required double bottomInterval,
    required String Function(double) getBottomTitle,
    required bool Function(double) isTodayIndex,
  }) {
    final interval =
        maxY > 50 ? 10.0 : (maxY > 20 ? 5.0 : (maxY > 10 ? 2.0 : 1.0));
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 32,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                value.toInt().toString(),
                style: AppTypography.caption(context).copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            );
          },
        ),
      ),
      topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                label,
                style: AppTypography.caption(context).copyWith(
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
    );
  }
}

class _CumulativeResult {
  final Map<int, List<FlSpot>> spotsPerHabit;
  final double maxY;

  const _CumulativeResult({required this.spotsPerHabit, required this.maxY});
}

class _GrowingLineChart extends StatefulWidget {
  final LineChartData data;

  const _GrowingLineChart({
    required this.data,
  });

  @override
  State<_GrowingLineChart> createState() => _GrowingLineChartState();
}

class _GrowingLineChartState extends State<_GrowingLineChart> {
  bool _grown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _grown = true);
    });
  }

  LineChartData _zeroedData(LineChartData src) {
    return src.copyWith(
      lineBarsData: src.lineBarsData.map((bar) {
        return bar.copyWith(
          spots: bar.spots.map((s) => FlSpot(s.x, 0)).toList(),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LineChart(
      _grown ? widget.data : _zeroedData(widget.data),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }
}
