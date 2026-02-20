import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/mood_entry.dart';
import '../services/mood_storage_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_typography.dart';

// ─── Public mood helpers (used by dashboard summary card too) ────────────────

class MoodOption {
  final int value;
  final IconData icon;
  final String assetPath;
  final String label;
  final Color color;
  const MoodOption({
    required this.value,
    required this.icon,
    required this.assetPath,
    required this.label,
    required this.color,
  });
}

const moodOptions = <MoodOption>[
  MoodOption(value: 1, icon: Icons.sentiment_very_dissatisfied_rounded, assetPath: 'assets/moods/awful.png', label: 'AWFUL', color: AppColors.moodAwful),
  MoodOption(value: 2, icon: Icons.sentiment_dissatisfied_rounded, assetPath: 'assets/moods/bad.png', label: 'BAD', color: AppColors.moodBad),
  MoodOption(value: 3, icon: Icons.sentiment_neutral_rounded, assetPath: 'assets/moods/okay.png', label: 'OKAY', color: AppColors.moodNeutral),
  MoodOption(value: 4, icon: Icons.sentiment_satisfied_rounded, assetPath: 'assets/moods/good.png', label: 'GOOD', color: AppColors.moodGood),
  MoodOption(value: 5, icon: Icons.sentiment_very_satisfied_rounded, assetPath: 'assets/moods/great.png', label: 'GREAT', color: AppColors.moodGreat),
];

Color colorForMood(int value) =>
    moodOptions.firstWhere((m) => m.value == value, orElse: () => moodOptions[2]).color;

IconData iconForMood(int value) =>
    moodOptions.firstWhere((m) => m.value == value, orElse: () => moodOptions[2]).icon;

String assetForMood(int value) =>
    moodOptions.firstWhere((m) => m.value == value, orElse: () => moodOptions[2]).assetPath;

String labelForMood(int value) =>
    moodOptions.firstWhere((m) => m.value == value, orElse: () => moodOptions[2]).label;

// ─── Time range enum ─────────────────────────────────────────────────────────

enum _TimeRange { week, month, year }

// ─── Screen ──────────────────────────────────────────────────────────────────

class MoodDetailScreen extends StatefulWidget {
  const MoodDetailScreen({super.key});

  @override
  State<MoodDetailScreen> createState() => _MoodDetailScreenState();
}

class _MoodDetailScreenState extends State<MoodDetailScreen> {
  List<MoodEntry> _rangeMoods = [];
  int? _todayMood;
  int _totalCheckIns = 0;
  bool _loaded = false;

  _TimeRange _selectedRange = _TimeRange.month;
  late DateTime _rangeStart;

  @override
  void initState() {
    super.initState();
    _rangeStart = _defaultStart(_selectedRange);
    _load();
  }

  // ─── Date helpers ─────────────────────────────────────────────────────────

  static DateTime _mondayOf(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static DateTime _defaultStart(_TimeRange range) {
    final now = DateTime.now();
    switch (range) {
      case _TimeRange.week:
        return _mondayOf(now);
      case _TimeRange.month:
        return DateTime(now.year, now.month, 1);
      case _TimeRange.year:
        return DateTime(now.year, 1, 1);
    }
  }

  DateTime get _rangeEnd {
    switch (_selectedRange) {
      case _TimeRange.week:
        return _rangeStart.add(const Duration(days: 7));
      case _TimeRange.month:
        return DateTime(_rangeStart.year, _rangeStart.month + 1, 1);
      case _TimeRange.year:
        return DateTime(_rangeStart.year + 1, 1, 1);
    }
  }

  bool get _isCurrentPeriod {
    final defStart = _defaultStart(_selectedRange);
    return _rangeStart.year == defStart.year &&
        _rangeStart.month == defStart.month &&
        _rangeStart.day == defStart.day;
  }

  String get _periodLabel {
    switch (_selectedRange) {
      case _TimeRange.week:
        final end = _rangeStart.add(const Duration(days: 6));
        final fmt = DateFormat('MMM d');
        return '${fmt.format(_rangeStart)} – ${fmt.format(end)}';
      case _TimeRange.month:
        return DateFormat('MMMM yyyy').format(_rangeStart);
      case _TimeRange.year:
        return '${_rangeStart.year}';
    }
  }

  // ─── Data loading ─────────────────────────────────────────────────────────

  Future<void> _load() async {
    final moods = await MoodStorageService.getMoodsForRange(_rangeStart, _rangeEnd);
    final total = await MoodStorageService.totalCheckIns();
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final todayEntry = moods.where((e) => e.dateKey == todayKey).toList();
    if (mounted) {
      setState(() {
        _rangeMoods = moods;
        _totalCheckIns = total;
        _todayMood = todayEntry.isNotEmpty ? todayEntry.first.value : null;
        _loaded = true;
      });
    }
  }

  Future<void> _onMoodSelected(int value) async {
    final now = DateTime.now();
    final entry = MoodEntry(
      id: 'mood_${now.millisecondsSinceEpoch}',
      date: DateTime(now.year, now.month, now.day),
      value: value,
    );
    await MoodStorageService.saveMood(entry);
    setState(() => _todayMood = value);
    await _load();
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _previous() {
    setState(() {
      switch (_selectedRange) {
        case _TimeRange.week:
          _rangeStart = _rangeStart.subtract(const Duration(days: 7));
        case _TimeRange.month:
          _rangeStart = DateTime(_rangeStart.year, _rangeStart.month - 1, 1);
        case _TimeRange.year:
          _rangeStart = DateTime(_rangeStart.year - 1, 1, 1);
      }
    });
    _load();
  }

  void _next() {
    if (!_isCurrentPeriod) {
      setState(() {
        switch (_selectedRange) {
          case _TimeRange.week:
            _rangeStart = _rangeStart.add(const Duration(days: 7));
          case _TimeRange.month:
            _rangeStart = DateTime(_rangeStart.year, _rangeStart.month + 1, 1);
          case _TimeRange.year:
            _rangeStart = DateTime(_rangeStart.year + 1, 1, 1);
        }
      });
      _load();
    }
  }

  void _onRangeChanged(_TimeRange range) {
    setState(() {
      _selectedRange = range;
      _rangeStart = _defaultStart(range);
    });
    _load();
  }

  String get _ordinalCheckIn {
    final n = _totalCheckIns + (_todayMood == null ? 1 : 0);
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}TH';
    switch (n % 10) {
      case 1:
        return '${n}ST';
      case 2:
        return '${n}ND';
      case 3:
        return '${n}RD';
      default:
        return '${n}TH';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(gradient: AppColors.skyGradient(isDark: isDark)),
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Mood'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCheckInSection(colorScheme),
          const SizedBox(height: 16),
          _buildAnalysisSection(colorScheme),
        ],
      ),
    ),
    );
  }

  // ─── Section A: How are you today? ────────────────────────────────────────

  Widget _buildCheckInSection(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            if (_loaded)
              Text(
                '$_ordinalCheckIn CHECK-IN',
                style: AppTypography.caption(context).copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'How are you today?',
              style: AppTypography.heading1(context).copyWith(
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: moodOptions.map((m) => _buildMoodButton(m, colorScheme)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodButton(MoodOption mood, ColorScheme colorScheme) {
    final isSelected = _todayMood == mood.value;
    return GestureDetector(
      onTap: () => _onMoodSelected(mood.value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? mood.color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 52 : 44,
              height: isSelected ? 52 : 44,
              child: Opacity(
                opacity: isSelected ? 1.0 : 0.75,
                child: Image.asset(
                  mood.assetPath,
                  width: isSelected ? 52 : 44,
                  height: isSelected ? 52 : 44,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mood.label,
              style: AppTypography.caption(context).copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? mood.color : colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section B: Mood Analysis ─────────────────────────────────────────────

  Widget _buildAnalysisSection(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mood Analysis',
              style: AppTypography.heading2(context),
            ),
            const SizedBox(height: 14),
            _buildRangeSelector(colorScheme),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _periodLabel,
                    style: AppTypography.bodySmall(context).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _navButton(Icons.chevron_left_rounded, _previous, colorScheme),
                const SizedBox(width: 4),
                _navButton(
                  Icons.chevron_right_rounded,
                  _isCurrentPeriod ? null : _next,
                  colorScheme,
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!_loaded)
              const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(height: 200, child: _buildChart(colorScheme)),
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
          _TimeRange.week => 'Week',
          _TimeRange.month => 'Month',
          _TimeRange.year => 'Year',
        };
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            onSelected: (_) => _onRangeChanged(range),
            selectedColor: colorScheme.primary,
            labelStyle: AppTypography.bodySmall(context).copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            ),
            backgroundColor: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
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

  Widget _navButton(IconData icon, VoidCallback? onTap, ColorScheme colorScheme) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colorScheme.surfaceContainerHigh,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled
              ? colorScheme.onSurface
              : colorScheme.onSurface.withValues(alpha: 0.25),
        ),
      ),
    );
  }

  // ─── Chart ────────────────────────────────────────────────────────────────

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

  // ── Week chart (Mon–Sun, 7 points) ──

  Widget _buildWeekChart(ColorScheme colorScheme) {
    const dayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    final Map<int, MoodEntry> moodByDay = {};
    for (final entry in _rangeMoods) {
      moodByDay[entry.date.weekday - 1] = entry;
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      if (moodByDay.containsKey(i)) {
        spots.add(FlSpot(i.toDouble(), moodByDay[i]!.value.toDouble()));
      }
    }

    if (spots.isEmpty) return _emptyState('No mood data this week.');

    return _lineChart(
      spots: spots,
      minX: 0,
      maxX: 6,
      colorScheme: colorScheme,
      bottomInterval: 1,
      getBottomTitle: (value) {
        final i = value.toInt();
        if (i < 0 || i > 6) return '';
        return dayLabels[i];
      },
      isTodayIndex: (value) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dayDate = _rangeStart.add(Duration(days: value.toInt()));
        return dayDate.year == today.year &&
            dayDate.month == today.month &&
            dayDate.day == today.day;
      },
    );
  }

  // ── Month chart (day 1–N, up to 31 points) ──

  Widget _buildMonthChart(ColorScheme colorScheme) {
    final daysInMonth = DateTime(_rangeStart.year, _rangeStart.month + 1, 0).day;

    final Map<int, MoodEntry> moodByDayOfMonth = {};
    for (final entry in _rangeMoods) {
      moodByDayOfMonth[entry.date.day] = entry;
    }

    final spots = <FlSpot>[];
    for (int d = 1; d <= daysInMonth; d++) {
      if (moodByDayOfMonth.containsKey(d)) {
        spots.add(FlSpot(d.toDouble(), moodByDayOfMonth[d]!.value.toDouble()));
      }
    }

    if (spots.isEmpty) return _emptyState('No mood data this month.');

    return _lineChart(
      spots: spots,
      minX: 1,
      maxX: daysInMonth.toDouble(),
      colorScheme: colorScheme,
      bottomInterval: 5,
      getBottomTitle: (value) {
        final d = value.toInt();
        if (d == 1 || d % 5 == 0 || d == daysInMonth) return '$d';
        return '';
      },
      isTodayIndex: (value) {
        final now = DateTime.now();
        return _rangeStart.year == now.year &&
            _rangeStart.month == now.month &&
            value.toInt() == now.day;
      },
    );
  }

  // ── Year chart (Jan–Dec, 12 points = monthly averages) ──

  Widget _buildYearChart(ColorScheme colorScheme) {
    const monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    final Map<int, List<int>> valuesByMonth = {};
    for (final entry in _rangeMoods) {
      valuesByMonth.putIfAbsent(entry.date.month, () => []).add(entry.value);
    }

    final spots = <FlSpot>[];
    for (int m = 1; m <= 12; m++) {
      final vals = valuesByMonth[m];
      if (vals != null && vals.isNotEmpty) {
        final avg = vals.reduce((a, b) => a + b) / vals.length;
        spots.add(FlSpot(m.toDouble(), avg));
      }
    }

    if (spots.isEmpty) return _emptyState('No mood data this year.');

    return _lineChart(
      spots: spots,
      minX: 1,
      maxX: 12,
      colorScheme: colorScheme,
      bottomInterval: 1,
      getBottomTitle: (value) {
        final m = value.toInt();
        if (m < 1 || m > 12) return '';
        return monthLabels[m - 1];
      },
      isTodayIndex: (value) {
        final now = DateTime.now();
        return _rangeStart.year == now.year && value.toInt() == now.month;
      },
    );
  }

  // ── Shared line chart builder ──

  Widget _lineChart({
    required List<FlSpot> spots,
    required double minX,
    required double maxX,
    required ColorScheme colorScheme,
    required double bottomInterval,
    required String Function(double) getBottomTitle,
    required bool Function(double) isTodayIndex,
  }) {
    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: 0.5,
        maxY: 5.5,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                    style: AppTypography.caption(context).copyWith(
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
              final moodIdx = s.y.round().clamp(1, 5) - 1;
              final mood = moodOptions[moodIdx];
              return LineTooltipItem(
                mood.label,
                AppTypography.bodySmall(context).copyWith(
                  color: mood.color,
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
              getDotPainter: (spot, percent, bar, index) {
                final moodVal = spot.y.round().clamp(1, 5);
                return FlDotCirclePainter(
                  radius: 6,
                  color: colorForMood(moodVal),
                  strokeWidth: 2.5,
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
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _emptyState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        '$message\nTap an emoji above to log how you feel!',
        textAlign: TextAlign.center,
        style: AppTypography.secondary(context).copyWith(
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
