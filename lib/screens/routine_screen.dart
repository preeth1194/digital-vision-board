import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../services/habit_storage_service.dart';
import '../services/sun_times_service.dart';
import '../utils/app_colors.dart';
import '../widgets/routine/routine_calendar_header.dart';
import '../widgets/routine/sun_times_header.dart';
import '../widgets/rituals/habit_form_constants.dart';
import 'routine_timer_screen.dart';

/// Habit timeline screen: calendar header, sun/moon arc, 24-hour timeline of
/// habits that have a start time and duration.
class RoutineScreen extends StatefulWidget {
  final bool standalone;
  final ValueNotifier<int>? dataVersion;

  const RoutineScreen({
    super.key,
    this.standalone = false,
    this.dataVersion,
  });

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> with TickerProviderStateMixin {
  bool _loading = true;
  SharedPreferences? _prefs;
  List<HabitItem> _habits = [];
  late DateTime _selectedDate;

  DateTime? _sunrise;
  DateTime? _sunset;
  Timer? _currentTimeTimer;
  DateTime _currentTime = DateTime.now();

  late ScrollController _timelineScrollController;
  DateTime? _timelinePreviewTime;
  static const double _baseHourHeight = 80.0;
  static const double _minCardHeight = 54.0;
  static const double _cardGap = 6.0;
  static const double _hourLabelPad = 18.0;
  List<double> _hourYOffsets = List.generate(25, (i) => i * _baseHourHeight);
  List<double> _hourHeights = List.filled(24, _baseHourHeight);
  List<int> _habitsPerHour = List.filled(24, 0);
  double _viewportHeight = 0;
  int _lastCrossedHour = -1;
  double _timelineMaxY = 0;

  late AnimationController _currentTimeIndicatorController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _normalizeDate();
    _init();

    _timelineScrollController = ScrollController();
    _timelineScrollController.addListener(_onTimelineScroll);

    _currentTimeIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _currentTimeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    widget.dataVersion?.addListener(_onDataVersionChanged);
  }

  @override
  void didUpdateWidget(covariant RoutineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataVersion != oldWidget.dataVersion) {
      oldWidget.dataVersion?.removeListener(_onDataVersionChanged);
      widget.dataVersion?.addListener(_onDataVersionChanged);
    }
  }

  void _onDataVersionChanged() => _loadHabits();

  void _normalizeDate() {
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  }

  @override
  void dispose() {
    widget.dataVersion?.removeListener(_onDataVersionChanged);
    _currentTimeTimer?.cancel();
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _currentTimeIndicatorController.dispose();
    super.dispose();
  }

  int _hourFromOffset(double yOffset) {
    for (int h = 0; h < 24; h++) {
      if (yOffset < _hourYOffsets[h + 1]) return h;
    }
    return 23;
  }

  void _onTimelineScroll() {
    if (!_timelineScrollController.hasClients) return;

    final scrollOffset = _timelineScrollController.offset;
    final centerOffset = scrollOffset + _viewportHeight / 2;
    final hour = _hourFromOffset(centerOffset);
    final fraction = _hourHeights[hour] > 0
        ? ((centerOffset - _hourYOffsets[hour]) / _hourHeights[hour]).clamp(0.0, 1.0)
        : 0.0;
    final minute = (fraction * 60).toInt().clamp(0, 59);

    final previewTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      hour, minute,
    );

    if (hour != _lastCrossedHour && _lastCrossedHour != -1) {
      HapticFeedback.selectionClick();
    }
    _lastCrossedHour = hour;

    setState(() => _timelinePreviewTime = previewTime);
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadHabits();
    await _loadSunTimes();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadHabits() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final all = await HabitStorageService.loadAll(prefs: prefs);
    if (mounted) setState(() => _habits = all);
  }

  Future<void> _loadSunTimes() async {
    final sunTimes = await SunTimesService.getSunTimes(date: _selectedDate, prefs: _prefs);
    if (sunTimes != null && mounted) {
      setState(() {
        _sunrise = sunTimes.sunrise;
        _sunset = sunTimes.sunset;
      });
    } else if (mounted) {
      final defaults = SunTimesService.getDefaultSunTimes(_selectedDate);
      setState(() {
        _sunrise = defaults.sunrise;
        _sunset = defaults.sunset;
      });
    }
  }

  bool _isRefreshingLocation = false;

  Future<void> _refreshLocation() async {
    if (_isRefreshingLocation) return;
    setState(() => _isRefreshingLocation = true);
    try {
      final sunTimes = await SunTimesService.refreshLocationAndGetSunTimes(
          date: _selectedDate, prefs: _prefs);
      if (mounted) {
        if (sunTimes != null) {
          setState(() {
            _sunrise = sunTimes.sunrise;
            _sunset = sunTimes.sunset;
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location updated'), duration: Duration(seconds: 2)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not get location. Check permissions.'),
              duration: Duration(seconds: 3)));
        }
      }
    } finally {
      if (mounted) setState(() => _isRefreshingLocation = false);
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
    _loadSunTimes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToRelevantTime());
  }

  void _scrollToRelevantTime({bool animate = true}) {
    if (!_timelineScrollController.hasClients) return;
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    int targetHour;
    double minuteFraction = 0;
    if (isToday) {
      targetHour = now.hour;
      minuteFraction = now.minute / 60;
    } else {
      final timed = _timedHabitsForDate;
      if (timed.isNotEmpty) {
        final s = timed.first.startTimeMinutes ?? 0;
        targetHour = (s ~/ 60).clamp(0, 23);
        minuteFraction = (s % 60) / 60;
      } else {
        targetHour = 6;
      }
    }

    final h = targetHour.clamp(0, 23);
    final yPosition = _hourYOffsets[h] + minuteFraction * _hourHeights[h];
    final totalHeight = _hourYOffsets[24];
    final maxScroll = (totalHeight - _viewportHeight).clamp(0.0, double.infinity);
    final targetOffset = (yPosition - _viewportHeight / 3).clamp(0.0, maxScroll);

    if (animate) {
      _timelineScrollController.animateTo(targetOffset,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      _timelineScrollController.jumpTo(targetOffset);
    }
  }

  /// Filter habits for the selected date based on frequency, weeklyDays,
  /// and mastery milestone (deadline).
  List<HabitItem> get _habitsForSelectedDate {
    return _habits.where((h) {
      if (!h.isScheduledOnDate(_selectedDate)) return false;
      if (h.deadline != null && h.deadline!.trim().isNotEmpty) {
        final deadlineDate = DateTime.tryParse(h.deadline!);
        if (deadlineDate != null) {
          final d = DateTime(deadlineDate.year, deadlineDate.month, deadlineDate.day);
          if (_selectedDate.isAfter(d)) return false;
        }
      }
      return true;
    }).toList()
      ..sort((a, b) => (a.startTimeMinutes ?? 0).compareTo(b.startTimeMinutes ?? 0));
  }

  /// Habits with start time + duration — placed on the 24-hour timeline.
  List<HabitItem> get _timedHabitsForDate {
    return _habitsForSelectedDate.where((h) {
      if (h.startTimeMinutes == null) return false;
      final tb = h.timeBound;
      return tb != null && tb.enabled && tb.durationMinutes > 0;
    }).toList();
  }

  /// Habits without a specific time slot — shown in the compact section.
  List<HabitItem> get _untimedHabitsForDate {
    return _habitsForSelectedDate.where((h) {
      final tb = h.timeBound;
      return h.startTimeMinutes == null || tb == null || !tb.enabled || tb.durationMinutes <= 0;
    }).toList();
  }

  void _computeHourLayout(List<HabitItem> habits) {
    final perHour = List.filled(24, 0);
    for (final h in habits) {
      final hour = ((h.startTimeMinutes ?? 0) ~/ 60).clamp(0, 23);
      perHour[hour]++;
    }
    final heights = List<double>.filled(24, _baseHourHeight);
    for (int h = 0; h < 24; h++) {
      final n = perHour[h];
      if (n > 1) {
        final needed = _hourLabelPad + n * _minCardHeight + (n - 1) * _cardGap;
        if (needed > _baseHourHeight) heights[h] = needed;
      }
    }
    // Expand single-habit hours so a card placed proportionally still fits
    for (final h in habits) {
      final s = h.startTimeMinutes ?? 0;
      final hour = (s ~/ 60).clamp(0, 23);
      if (perHour[hour] == 1) {
        final proportionalY = ((s % 60) / 60) * _baseHourHeight;
        final needed = proportionalY + _minCardHeight;
        if (needed > heights[hour]) heights[hour] = needed;
      }
    }
    final offsets = List<double>.filled(25, 0);
    for (int h = 0; h < 24; h++) {
      offsets[h + 1] = offsets[h] + heights[h];
    }
    _hourHeights = heights;
    _hourYOffsets = offsets;
    _habitsPerHour = perHour;
  }

  void _openHabitTimer(HabitItem habit) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => RoutineTimerScreen(habit: habit, onComplete: () => _loadHabits()),
      ),
    ).then((_) => _loadHabits());
  }

  // -----------------------------------------------------------------------
  // Build
  // -----------------------------------------------------------------------

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        RoutineCalendarHeader(
          selectedDate: _selectedDate,
          onDateSelected: _onDateSelected,
          routines: const [],
        ),
        if (_sunrise != null && _sunset != null)
          SunTimesHeader(
            sunrise: _sunrise!,
            sunset: _sunset!,
            currentTime: _currentTime,
            previewTime: _timelinePreviewTime,
            onRefreshLocation: _refreshLocation,
          ),
        _buildUntimedHabitsSection(),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportHeight = constraints.maxHeight;
              if (_lastCrossedHour == -1) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_timelineScrollController.hasClients &&
                      _lastCrossedHour == -1) {
                    _scrollToRelevantTime(animate: false);
                  }
                });
              }
              return _build24HourTimeline();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUntimedHabitsSection() {
    final habits = _untimedHabitsForDate;
    if (habits.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final completedCount =
        habits.where((h) => h.isCompletedForCurrentPeriod(_selectedDate)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
          child: Row(
            children: [
              Text(
                'Anytime',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '$completedCount / ${habits.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: habits.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final habit = habits[index];
              final isCompleted =
                  habit.isCompletedForCurrentPeriod(_selectedDate);
              final iconData =
                  habit.iconIndex != null && habit.iconIndex! < habitIcons.length
                      ? habitIcons[habit.iconIndex!].$1
                      : Icons.self_improvement;

              return GestureDetector(
                onTap: () => _openHabitTimer(habit),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.mossGreen.withOpacity(0.15)
                        : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.mossGreen.withOpacity(0.3)
                          : colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(iconData, size: 14,
                          color: isCompleted
                              ? AppColors.mossGreen
                              : colorScheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        habit.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isCompleted
                              ? AppColors.mossGreen
                              : colorScheme.onSurface,
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle_rounded, size: 14,
                            color: AppColors.mossGreen),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _build24HourTimeline() {
    final habitsForDate = _timedHabitsForDate;
    _computeHourLayout(habitsForDate);
    final totalHeight = _hourYOffsets[24];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitCards = _buildPositionedHabitCards(habitsForDate, isDark);
    final effectiveHeight =
        _timelineMaxY > totalHeight ? _timelineMaxY + 20 : totalHeight;

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    return RefreshIndicator(
      onRefresh: _loadHabits,
      child: SingleChildScrollView(
        controller: _timelineScrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Container(
          height: effectiveHeight,
          color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
          child: Stack(
            children: [
              ..._buildHourLines(isDark),
              if (isToday)
                _buildCurrentTimeIndicator(isDark)
              else
                _buildDateAnchorLine(isDark),
              ...habitCards,
              if (habitsForDate.isEmpty && _untimedHabitsForDate.isEmpty)
                Positioned(
                  top: _hourYOffsets[7],
                  left: 56,
                  right: 16,
                  child: _buildEmptyTimelineHint(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTimelineHint() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_outlined, size: 40,
              color: colorScheme.onSurfaceVariant.withOpacity(0.6)),
          const SizedBox(height: 12),
          Text('No habits yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Create habits with a timer & start time to see them here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7))),
        ],
      ),
    );
  }

  List<Widget> _buildHourLines(bool isDark) {
    final List<Widget> hourWidgets = [];
    final totalHeight = _hourYOffsets[24];

    // Vertical timeline rail
    hourWidgets.add(Positioned(
      top: 0,
      bottom: 0,
      left: 52,
      width: 2,
      child: Container(
        height: totalHeight,
        decoration: BoxDecoration(
          color: isDark ? Colors.white24 : Colors.black12,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    ));

    for (int hour = 0; hour < 24; hour++) {
      final yPosition = _hourYOffsets[hour];
      final hourHeight = _hourHeights[hour];
      final hourLabel = _formatHourLabel(hour);
      final now = DateTime.now();
      final isCurrentHour = now.hour == hour &&
          _selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day;

      // Full hour line + label
      hourWidgets.add(Positioned(
        top: yPosition,
        left: 0,
        right: 0,
        height: hourHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(hourLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrentHour ? FontWeight.w700 : FontWeight.w600,
                      color: isCurrentHour
                          ? AppColors.medium
                          : (isDark ? Colors.white70 : Colors.grey[700]!),
                    )),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7, right: 16),
                child: Container(
                  height: 1,
                  color: isDark ? Colors.white24 : Colors.grey[300]!,
                ),
              ),
            ),
          ],
        ),
      ));

      // Half hour line + label
      final halfY = yPosition + hourHeight / 2;
      final halfLabel = _formatHalfHourLabel(hour);

      hourWidgets.add(Positioned(
        top: halfY,
        left: 0,
        right: 0,
        height: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(halfLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white38 : Colors.grey[500]!,
                    )),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5, right: 16),
                child: CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: _DottedLinePainter(
                    color: isDark ? Colors.white12 : Colors.grey[200]!,
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
    }
    return hourWidgets;
  }

  /// Visible anchor line at 6 AM for non-today dates so the timeline feels present.
  Widget _buildDateAnchorLine(bool isDark) {
    final yPosition = _hourYOffsets[6];
    return Positioned(
      top: yPosition - 4,
      left: 48,
      right: 16,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.medium.withOpacity(0.6),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.medium.withOpacity(0.5),
                    AppColors.medium.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(bool isDark) {
    final now = DateTime.now();
    final hour = now.hour.clamp(0, 23);
    final yPosition = _hourYOffsets[hour] + (now.minute / 60) * _hourHeights[hour];

    return Positioned(
      top: yPosition - 6,
      left: 48,
      right: 16,
      child: AnimatedBuilder(
        animation: _currentTimeIndicatorController,
        builder: (context, child) {
          final pulseValue = _currentTimeIndicatorController.value;
          return Row(children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3 + pulseValue * 0.3),
                    blurRadius: 4 + pulseValue * 4,
                    spreadRadius: pulseValue * 2,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Colors.red, Colors.red.withOpacity(0.3)]),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.2 + pulseValue * 0.2),
                      blurRadius: 2 + pulseValue * 2,
                    ),
                  ],
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }

  List<Widget> _buildPositionedHabitCards(List<HabitItem> habits, bool isDark) {
    final List<Widget> cards = [];
    final scrollOffset =
        _timelineScrollController.hasClients ? _timelineScrollController.offset : 0.0;

    _timelineMaxY = _hourYOffsets[24];
    if (habits.isEmpty) return cards;

    final cardData = habits.map((h) {
      final s = h.startTimeMinutes ?? 0;
      final startHour = (s ~/ 60).clamp(0, 23);
      final minuteInHour = s % 60;
      final hourHeight = _hourHeights[startHour];
      final duration = h.timeBound?.durationMinutes ?? 0;
      final double yTop;
      if (_habitsPerHour[startHour] > 1) {
        yTop = _hourYOffsets[startHour] + _hourLabelPad;
      } else {
        yTop = _hourYOffsets[startHour] + (minuteInHour / 60) * hourHeight;
      }
      final cardHeight = ((duration / 60) * _baseHourHeight).clamp(_minCardHeight, 200.0);
      return (yTop: yTop, cardHeight: cardHeight);
    }).toList();

    final adjustedY = List<double>.filled(habits.length, 0);
    adjustedY[0] = cardData[0].yTop;
    for (int i = 1; i < habits.length; i++) {
      final prevBottom = adjustedY[i - 1] + cardData[i - 1].cardHeight;
      final naturalY = cardData[i].yTop;
      adjustedY[i] = naturalY < prevBottom + _cardGap ? prevBottom + _cardGap : naturalY;
    }

    final lastIdx = habits.length - 1;
    _timelineMaxY = adjustedY[lastIdx] + cardData[lastIdx].cardHeight;

    for (int i = 0; i < habits.length; i++) {
      final habit = habits[i];
      final yPosition = adjustedY[i];
      final cardHeight = cardData[i].cardHeight;

      final cardCenter = yPosition + cardHeight / 2;
      final viewportCenter = scrollOffset + _viewportHeight / 2;
      final distanceFromCenter = (cardCenter - viewportCenter).abs();
      final normalizedDistance = (distanceFromCenter / _viewportHeight).clamp(0.0, 1.0);
      final scale = 1.0 - (normalizedDistance * 0.05);
      final opacity = 1.0 - (normalizedDistance * 0.3);

      cards.add(Positioned(
        top: yPosition,
        left: 56,
        right: 24,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: opacity.clamp(0.7, 1.0),
          child: AnimatedScale(
            duration: const Duration(milliseconds: 200),
            scale: scale.clamp(0.95, 1.0),
            child: _TimelineHabitCard(
              habit: habit,
              selectedDate: _selectedDate,
              height: cardHeight,
              onTap: () => _openHabitTimer(habit),
              isDark: isDark,
            ),
          ),
        ),
      ));
    }
    return cards;
  }

  String _formatHourLabel(int hour) {
    if (hour == 0) return '12 am';
    if (hour == 12) return '12 pm';
    if (hour < 12) return '$hour am';
    return '${hour - 12} pm';
  }

  String _formatHalfHourLabel(int hour) {
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final suffix = hour < 12 ? 'am' : 'pm';
    return '$h12:30 $suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.standalone) {
      return Scaffold(body: _buildBody());
    }
    return _buildBody();
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _DottedLinePainter extends CustomPainter {
  final Color color;
  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
          Offset(startX, size.height / 2), Offset(startX + dashWidth, size.height / 2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) => oldDelegate.color != color;
}

class _TimelineHabitCard extends StatelessWidget {
  final HabitItem habit;
  final DateTime selectedDate;
  final double height;
  final VoidCallback onTap;
  final bool isDark;

  const _TimelineHabitCard({
    required this.habit,
    required this.selectedDate,
    required this.height,
    required this.onTap,
    required this.isDark,
  });

  static Color _categoryColor(String? category, bool isDark) {
    switch (category) {
      case 'Health':
        return isDark ? const Color(0xFF2E7D5B) : const Color(0xFFA8D5BA);
      case 'Fitness':
        return isDark ? const Color(0xFF33805E) : const Color(0xFFB8E6C8);
      case 'Mindfulness':
        return isDark ? const Color(0xFF8D5B3A) : const Color(0xFFF5C6AA);
      case 'Productivity':
        return isDark ? const Color(0xFF3565A0) : const Color(0xFFBBDEFB);
      case 'Learning':
        return isDark ? const Color(0xFF5E4B8A) : const Color(0xFFD1C4E9);
      case 'Relationships':
        return isDark ? const Color(0xFF8A4466) : const Color(0xFFF8BBD0);
      case 'Finance':
        return isDark ? const Color(0xFF8A7A30) : const Color(0xFFFFF9C4);
      case 'Creativity':
        return isDark ? const Color(0xFF7B4A8A) : const Color(0xFFE1BEE7);
      default:
        return isDark ? const Color(0xFF4A635A) : const Color(0xFFD5E8D4);
    }
  }

  String _formatTimeShort(int? minutes) {
    if (minutes == null) return '--:--';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final isPM = hours >= 12;
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    return '$hour12:${mins.toString().padLeft(2, '0')} ${isPM ? 'PM' : 'AM'}';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  bool get _compact => height < 64;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconIndex = habit.iconIndex;
    final iconData = iconIndex != null && iconIndex < habitIcons.length
        ? habitIcons[iconIndex].$1
        : Icons.self_improvement;
    final duration = habit.timeBound?.durationMinutes ?? 0;
    final startTime = habit.startTimeMinutes;
    final endTime = startTime != null ? startTime + duration : null;
    final isCompleted = habit.isCompletedOnDate(selectedDate);
    final tileColor = isCompleted
        ? AppColors.mossGreen
        : _categoryColor(habit.category, isDark);
    final textColor = _getContrastColor(tileColor);
    final subtitleColor = textColor.withOpacity(0.65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height.clamp(54, 200),
          margin: const EdgeInsets.only(bottom: 4),
          padding: EdgeInsets.symmetric(
            horizontal: _compact ? 10 : 12,
            vertical: _compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: tileColor.withOpacity(isDark ? 0.9 : 1.0),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: tileColor.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _compact ? _buildCompactRow(iconData, textColor, subtitleColor, startTime, endTime, duration, isCompleted) : _buildNormalRow(iconData, textColor, subtitleColor, startTime, endTime, duration, isCompleted),
        ),
      ),
    );
  }

  Widget _buildCompactRow(IconData iconData, Color textColor, Color subtitleColor, int? startTime, int? endTime, int duration, bool isCompleted) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, size: 16, color: textColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                habit.name,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatTimeShort(startTime)} – ${_formatTimeShort(endTime)}  ·  ${_formatDuration(duration)}',
                style: TextStyle(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (isCompleted) ...[
          const SizedBox(width: 6),
          Icon(Icons.check_circle, size: 20, color: textColor.withOpacity(0.7)),
        ],
      ],
    );
  }

  Widget _buildNormalRow(IconData iconData, Color textColor, Color subtitleColor, int? startTime, int? endTime, int duration, bool isCompleted) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(iconData, size: 18, color: textColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                habit.name,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    '${_formatTimeShort(startTime)} – ${_formatTimeShort(endTime)}',
                    style: TextStyle(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w500),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('·', style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor),
                    ),
                  ),
                  if (habit.actionSteps.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('·', style: TextStyle(color: subtitleColor, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${habit.actionSteps.length} steps',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (isCompleted) ...[
          const SizedBox(width: 8),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor.withOpacity(0.12),
            ),
            child: Icon(Icons.check, size: 15, color: textColor),
          ),
        ],
      ],
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? AppColors.darkest : AppColors.lightest;
  }
}
