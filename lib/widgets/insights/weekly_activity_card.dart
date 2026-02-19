import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/habit_item.dart';
import '../../utils/app_colors.dart';

enum _ChartMode { activity, coins }

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

class HabitTrendsChart extends StatefulWidget {
  final List<HabitItem> habits;

  const HabitTrendsChart({super.key, required this.habits});

  @override
  State<HabitTrendsChart> createState() => _HabitTrendsChartState();
}

class _HabitTrendsChartState extends State<HabitTrendsChart>
    with SingleTickerProviderStateMixin {
  _ChartMode _mode = _ChartMode.activity;
  _TimeRange _selectedRange = _TimeRange.week;

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
      _selectedRange = _TimeRange.week;
    });
    if (mode == _ChartMode.coins) {
      _legendController.forward();
    } else {
      _legendController.reverse();
    }
  }

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
              children: [
                const Text(
                  'Habit Trends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildModePills(colorScheme),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _buildRangeSelector(colorScheme),
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
                  key: ValueKey('${_mode.name}_${_selectedRange.name}'),
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
                child: _mode == _ChartMode.coins && widget.habits.isNotEmpty
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

  // ── Mode pills with animated indicator ──────────────────────────────────

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 12,
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

  // ── Time range selector ─────────────────────────────────────────────────

  Widget _buildRangeSelector(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
              color: selected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
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

  // ── Legend (coins mode only) ─────────────────────────────────────────────

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
          separatorBuilder: (_, __) => const SizedBox(width: 14),
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
                  style: TextStyle(
                    fontSize: 11,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIVITY MODE – single aggregate line
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildActivityChart(ColorScheme colorScheme) {
    switch (_selectedRange) {
      case _TimeRange.week:
        return _activityWeek(colorScheme);
      case _TimeRange.month:
        return _activityMonth(colorScheme);
      case _TimeRange.year:
        return _activityYear(colorScheme);
    }
  }

  Widget _activityWeek(ColorScheme colorScheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dayLabels = <String>[];
    final spots = <FlSpot>[];

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      final count =
          widget.habits.where((h) => h.isCompletedOnDate(dateOnly)).length;
      dayLabels.add(DateFormat('E').format(date));
      spots.add(FlSpot((6 - i).toDouble(), count.toDouble()));
    }

    return _singleLineChart(
      spots: spots,
      minX: 0,
      maxX: 6,
      maxY: (widget.habits.length + 10).toDouble(),
      colorScheme: colorScheme,
      bottomInterval: 1,
      getBottomTitle: (v) {
        final i = v.toInt();
        return (i >= 0 && i < dayLabels.length) ? dayLabels[i] : '';
      },
      isTodayIndex: (v) => v.toInt() == 6,
    );
  }

  Widget _activityMonth(ColorScheme colorScheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final spots = <FlSpot>[];

    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dateOnly = DateTime(date.year, date.month, date.day);
      final count =
          widget.habits.where((h) => h.isCompletedOnDate(dateOnly)).length;
      spots.add(FlSpot((30 - i).toDouble(), count.toDouble()));
    }

    return _singleLineChart(
      spots: spots,
      minX: 1,
      maxX: 30,
      maxY: (widget.habits.length + 10).toDouble(),
      colorScheme: colorScheme,
      bottomInterval: 5,
      getBottomTitle: (v) {
        final d = v.toInt();
        return (d == 1 || d % 5 == 0 || d == 30) ? '$d' : '';
      },
      isTodayIndex: (v) => v.toInt() == 30,
    );
  }

  Widget _activityYear(ColorScheme colorScheme) {
    const monthLabels = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yearStart = DateTime(now.year, 1, 1);

    final Map<int, List<int>> countsByMonth = {};
    var date = yearStart;
    while (!date.isAfter(today)) {
      final count =
          widget.habits.where((h) => h.isCompletedOnDate(date)).length;
      countsByMonth.putIfAbsent(date.month, () => []).add(count);
      date = date.add(const Duration(days: 1));
    }

    final spots = <FlSpot>[];
    for (int m = 1; m <= 12; m++) {
      final vals = countsByMonth[m];
      if (vals != null && vals.isNotEmpty) {
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        spots.add(FlSpot(m.toDouble(), avg));
      }
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          'No data this year yet.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return _singleLineChart(
      spots: spots,
      minX: 1,
      maxX: 12,
      maxY: (widget.habits.length + 10).toDouble(),
      colorScheme: colorScheme,
      bottomInterval: 1,
      getBottomTitle: (v) {
        final m = v.toInt();
        return (m >= 1 && m <= 12) ? monthLabels[m - 1] : '';
      },
      isTodayIndex: (v) => v.toInt() == now.month,
    );
  }

  Widget _singleLineChart({
    required List<FlSpot> spots,
    required double minX,
    required double maxX,
    required double maxY,
    required ColorScheme colorScheme,
    required double bottomInterval,
    required String Function(double) getBottomTitle,
    required bool Function(double) isTodayIndex,
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
              final val = _selectedRange == _TimeRange.year
                  ? s.y.toStringAsFixed(1)
                  : s.y.toInt().toString();
              return LineTooltipItem(
                '$val completed',
                TextStyle(
                  color: AppColors.mossGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
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
            color: AppColors.mossGreen,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) => spot.y > 0,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.mossGreen,
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
                  AppColors.mossGreen.withValues(alpha: 0.25),
                  AppColors.mossGreen.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COINS MODE – per-habit cumulative lines
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCoinsChart(ColorScheme colorScheme) {
    switch (_selectedRange) {
      case _TimeRange.week:
        return _coinsWeek(colorScheme);
      case _TimeRange.month:
        return _coinsMonth(colorScheme);
      case _TimeRange.year:
        return _coinsYear(colorScheme);
    }
  }

  _CumulativeResult _computeCumulative(
      List<DateTime> dates, double Function(int) xMapper) {
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

    return _CumulativeResult(
        spotsPerHabit: spotsPerHabit, maxY: globalMax + 10);
  }

  Widget _coinsWeek(ColorScheme colorScheme) {
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

    return _multiLineChart(
      spotsPerHabit: result.spotsPerHabit,
      minX: 0,
      maxX: 6,
      maxY: result.maxY,
      colorScheme: colorScheme,
      bottomInterval: 1,
      getBottomTitle: (v) {
        final i = v.toInt();
        return (i >= 0 && i < dayLabels.length) ? dayLabels[i] : '';
      },
      isTodayIndex: (v) => v.toInt() == 6,
    );
  }

  Widget _coinsMonth(ColorScheme colorScheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = <DateTime>[];

    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      dates.add(DateTime(date.year, date.month, date.day));
    }

    final result = _computeCumulative(dates, (di) => (di + 1).toDouble());

    return _multiLineChart(
      spotsPerHabit: result.spotsPerHabit,
      minX: 1,
      maxX: 30,
      maxY: result.maxY,
      colorScheme: colorScheme,
      bottomInterval: 5,
      getBottomTitle: (v) {
        final d = v.toInt();
        return (d == 1 || d % 5 == 0 || d == 30) ? '$d' : '';
      },
      isTodayIndex: (v) => v.toInt() == 30,
    );
  }

  Widget _coinsYear(ColorScheme colorScheme) {
    const monthLabels = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
    ];
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
          final iso =
              DateTime(now.year, m, d).toIso8601String().split('T')[0];
          final feedback = habit.feedbackByDate[iso];
          cumulative += feedback?.coinsEarned ?? 0;
        }
        spots.add(FlSpot(m.toDouble(), cumulative));
      }

      if (cumulative > globalMax) globalMax = cumulative;
      spotsPerHabit[hi] = spots;
    }

    final maxY = globalMax + 10;
    final hasData = spotsPerHabit.values.any((s) => s.isNotEmpty);

    if (!hasData) {
      return Center(
        child: Text(
          'No data this year yet.',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return _multiLineChart(
      spotsPerHabit: spotsPerHabit,
      minX: 1,
      maxX: 12,
      maxY: maxY,
      colorScheme: colorScheme,
      bottomInterval: 1,
      getBottomTitle: (v) {
        final m = v.toInt();
        return (m >= 1 && m <= 12) ? monthLabels[m - 1] : '';
      },
      isTodayIndex: (v) => v.toInt() == now.month,
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
    );
  }

  // ── Shared axis title builder ───────────────────────────────────────────

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
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: 10,
                  color:
                      colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: today ? FontWeight.w700 : FontWeight.w400,
                  color: today
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.6),
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

/// Wraps [LineChart] with a grow-from-zero animation.
///
/// On first build the Y values are zeroed out; after one frame the real data
/// is set and fl_chart's built-in interpolation animates the lines upward.
class _GrowingLineChart extends StatefulWidget {
  final LineChartData data;
  final Duration growDuration;
  final Curve growCurve;

  const _GrowingLineChart({
    required this.data,
    this.growDuration = const Duration(milliseconds: 600),
    this.growCurve = Curves.easeOutCubic,
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
      duration: widget.growDuration,
      curve: widget.growCurve,
    );
  }
}
