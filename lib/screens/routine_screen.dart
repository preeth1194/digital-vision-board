import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import '../models/grid_tile_model.dart';
import '../services/boards_storage_service.dart';
import '../services/vision_board_components_storage_service.dart';
import '../services/grid_tiles_storage_service.dart';
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

  const RoutineScreen({
    super.key,
    this.standalone = false,
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
  static const double _hourHeight = 70.0;
  static const double _totalTimelineHeight = _hourHeight * 24;
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
  }

  void _normalizeDate() {
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
  }

  @override
  void dispose() {
    _currentTimeTimer?.cancel();
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _currentTimeIndicatorController.dispose();
    super.dispose();
  }

  void _onTimelineScroll() {
    if (!_timelineScrollController.hasClients) return;

    final scrollOffset = _timelineScrollController.offset;
    final centerOffset = scrollOffset + _viewportHeight / 2;
    final centerHour = (centerOffset / _hourHeight).clamp(0.0, 23.99);

    final previewTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      centerHour.floor(), ((centerHour % 1) * 60).toInt(),
    );

    final currentCrossedHour = centerHour.floor();
    if (currentCrossedHour != _lastCrossedHour && _lastCrossedHour != -1) {
      HapticFeedback.selectionClick();
    }
    _lastCrossedHour = currentCrossedHour;

    setState(() => _timelinePreviewTime = previewTime);
  }

  void _scrollToCurrentTime({bool animate = true}) {
    if (!_timelineScrollController.hasClients) return;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    final targetOffset = (currentMinutes / 60) * _hourHeight - _viewportHeight / 2;
    final clampedOffset = targetOffset.clamp(0.0, _totalTimelineHeight - _viewportHeight);

    if (animate) {
      _timelineScrollController.animateTo(clampedOffset,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    } else {
      _timelineScrollController.jumpTo(clampedOffset);
    }
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadHabits();
    await _loadSunTimes();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadHabits() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    final List<HabitItem> all = [];
    for (final board in boards) {
      List<VisionComponent> components;
      if (board.layoutType == VisionBoardInfo.layoutGrid) {
        final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: prefs);
        components = tiles
            .where((t) => t.type != 'empty')
            .map((t) => ImageComponent(
                  id: t.id,
                  position: Offset.zero,
                  size: const Size(1, 1),
                  rotation: 0,
                  scale: 1,
                  zIndex: t.index,
                  imagePath: (t.type == 'image') ? (t.content ?? '') : '',
                  goal: t.goal,
                  habits: t.habits,
                ))
            .toList();
      } else {
        components = await VisionBoardComponentsStorageService.loadComponents(board.id, prefs: prefs);
      }
      for (final comp in components) {
        all.addAll(comp.habits);
      }
    }
    // Only keep habits with start time + duration
    final scheduled = all.where((h) {
      if (h.startTimeMinutes == null) return false;
      final tb = h.timeBound;
      return tb != null && tb.enabled && tb.durationMinutes > 0;
    }).toList();
    if (mounted) setState(() => _habits = scheduled);
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
  }

  /// Filter habits for the selected date based on frequency / weeklyDays.
  List<HabitItem> get _habitsForSelectedDate {
    return _habits.where((h) => h.isScheduledOnDate(_selectedDate)).toList()
      ..sort((a, b) => (a.startTimeMinutes ?? 0).compareTo(b.startTimeMinutes ?? 0));
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _viewportHeight = constraints.maxHeight;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_timelineScrollController.hasClients &&
                    _timelineScrollController.offset == 0 &&
                    _lastCrossedHour == -1) {
                  _scrollToCurrentTime(animate: false);
                }
              });
              return _build24HourTimeline();
            },
          ),
        ),
      ],
    );
  }

  Widget _build24HourTimeline() {
    final habitsForDate = _habitsForSelectedDate;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final habitCards = _buildPositionedHabitCards(habitsForDate, isDark);
    final effectiveHeight =
        _timelineMaxY > _totalTimelineHeight ? _timelineMaxY + 20 : _totalTimelineHeight;

    return RefreshIndicator(
      onRefresh: _loadHabits,
      child: SingleChildScrollView(
        controller: _timelineScrollController,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          height: effectiveHeight,
          child: Stack(
            children: [
              ..._buildHourLines(isDark),
              _buildCurrentTimeIndicator(isDark),
              ...habitCards,
              if (habitsForDate.isEmpty)
                Positioned(
                  top: _totalTimelineHeight / 2 - 60,
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
          Text('No scheduled habits',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Add a start time & duration to habits to see them here',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7))),
        ],
      ),
    );
  }

  List<Widget> _buildHourLines(bool isDark) {
    final List<Widget> hourWidgets = [];
    final scrollOffset =
        _timelineScrollController.hasClients ? _timelineScrollController.offset : 0.0;

    for (int hour = 0; hour < 24; hour++) {
      final yPosition = hour * _hourHeight;
      final hourLabel = _formatHourLabel(hour);
      final distanceFromCenter = (yPosition - (scrollOffset + _viewportHeight / 2)).abs();
      final opacity = (1.0 - (distanceFromCenter / _viewportHeight * 0.8)).clamp(0.4, 1.0);
      final now = DateTime.now();
      final isCurrentHour = now.hour == hour &&
          _selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day;

      hourWidgets.add(Positioned(
        top: yPosition,
        left: 0,
        right: 0,
        height: _hourHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: opacity,
                  child: Text(hourLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isCurrentHour ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrentHour
                            ? AppColors.medium
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      )),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 16),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: opacity * 0.5,
                  child: CustomPaint(
                    size: const Size(double.infinity, 1),
                    painter: _DottedLinePainter(
                        color: isDark ? Colors.grey[600]! : Colors.grey[300]!),
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

  Widget _buildCurrentTimeIndicator(bool isDark) {
    final now = DateTime.now();
    if (_selectedDate.year != now.year ||
        _selectedDate.month != now.month ||
        _selectedDate.day != now.day) {
      return const SizedBox.shrink();
    }
    final currentMinutes = now.hour * 60 + now.minute;
    final yPosition = (currentMinutes / 60) * _hourHeight;

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

    _timelineMaxY = _totalTimelineHeight;
    if (habits.isEmpty) return cards;

    const double gap = 6.0;

    final cardData = habits.map((h) {
      final s = h.startTimeMinutes ?? 0;
      final duration = h.timeBound?.durationMinutes ?? 0;
      final yTop = (s / 60) * _hourHeight;
      final cardHeight = ((duration / 60) * _hourHeight).clamp(60.0, 200.0);
      return (yTop: yTop, cardHeight: cardHeight);
    }).toList();

    final adjustedY = List<double>.filled(habits.length, 0);
    adjustedY[0] = cardData[0].yTop;
    for (int i = 1; i < habits.length; i++) {
      final prevBottom = adjustedY[i - 1] + cardData[i - 1].cardHeight;
      final naturalY = cardData[i].yTop;
      adjustedY[i] = naturalY < prevBottom + gap ? prevBottom + gap : naturalY;
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
        right: 8,
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

  String _formatTimeFromMinutes(int? minutes) {
    if (minutes == null) return '--:--';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final isPM = hours >= 12;
    final hour12 = hours == 0 ? 12 : (hours > 12 ? hours - 12 : hours);
    return '${hour12.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')} ${isPM ? 'PM' : 'AM'}';
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

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
        : colorScheme.primaryContainer;
    final textColor = _getContrastColor(tileColor);
    final subtitleColor = textColor.withOpacity(0.7);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height.clamp(60, 200),
          margin: const EdgeInsets.only(bottom: 4, right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconData, size: 18, color: textColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRect(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(habit.name,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.schedule, size: 12, color: subtitleColor),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '${_formatTimeFromMinutes(startTime)} - ${_formatTimeFromMinutes(endTime)}',
                            style: TextStyle(fontSize: 10, color: subtitleColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: textColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(duration),
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w500, color: subtitleColor),
                          ),
                        ),
                        if (habit.actionSteps.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${habit.actionSteps.length} steps',
                              style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w500, color: subtitleColor),
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (isCompleted)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: textColor.withOpacity(0.15),
                  ),
                  child: Icon(Icons.check, size: 14, color: textColor),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? AppColors.darkest : AppColors.lightest;
  }
}
