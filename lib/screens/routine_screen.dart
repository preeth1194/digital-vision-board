import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../services/ad_free_service.dart';
import '../services/ad_service.dart';
import '../services/coins_service.dart';
import '../services/habit_storage_service.dart';
import '../services/logical_date_service.dart';
import '../services/sun_times_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_typography.dart';
import '../widgets/ads/reward_ad_card.dart';
import '../widgets/rituals/add_habit_modal.dart';
import '../widgets/rituals/habit_completion_sheet.dart';
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

  // Occupied Y-ranges for empty-slot detection (populated by _buildPositionedHabitCards)
  List<(double top, double bottom)> _occupiedRanges = [];

  // Visual feedback for tapped time slot
  double? _tapHighlightY;

  // Ad gating state
  static const int _freeHabitLimit = 3;
  bool _shouldShowAds = true;
  String? _activeAdSession;
  int _adWatchedCount = 0;

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

  void _onDataVersionChanged() {
    _loadHabits();
    _loadAdState();
  }

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
    await _loadAdState();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadAdState() async {
    final showAds = await AdFreeService.shouldShowAds(prefs: _prefs);
    final session = await AdService.getActiveSession(prefs: _prefs);
    final watched = session != null
        ? await AdService.getWatchedCount(session, prefs: _prefs)
        : 0;
    if (mounted) {
      setState(() {
        _shouldShowAds = showAds;
        _activeAdSession = session;
        _adWatchedCount = watched;
      });
    }
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
    final isCompleted = habit.isCompletedForCurrentPeriod(_selectedDate);
    if (isCompleted) {
      _showCompletionDetails(habit);
      return;
    }
    Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => RoutineTimerScreen(habit: habit, onComplete: () => _loadHabits()),
      ),
    ).then((completedStepIds) async {
      await _loadHabits();
      if (completedStepIds != null && mounted) {
        await _handleHabitCompletion(habit, completedStepIds);
      }
    });
  }

  Future<void> _handleHabitCompletion(HabitItem habit, List<String> completedStepIds) async {
    final baseCoins = CoinsService.habitCompletionCoins;
    final result = await showHabitCompletionSheet(
      context,
      habit: habit,
      baseCoins: baseCoins,
      isFullHabit: true,
      preSelectedStepIds: completedStepIds,
    );
    if (result == null || !mounted) return;

    final now = LogicalDateService.now();
    final latestHabit = _habits
        .where((h) => h.id == habit.id)
        .cast<HabitItem?>()
        .firstWhere((_) => true, orElse: () => null);
    if (latestHabit == null) return;
    if (latestHabit.isCompletedForCurrentPeriod(now)) return;

    var toggled = latestHabit.toggleForDate(now);

    final iso = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final feedback = HabitCompletionFeedback(
      rating: result.mood ?? 0,
      note: result.note,
      coinsEarned: result.coinsEarned,
      trackingValue: result.trackingValue,
    );
    final updatedFeedback = Map<String, HabitCompletionFeedback>.from(toggled.feedbackByDate);
    updatedFeedback[iso] = feedback;
    toggled = toggled.copyWith(feedbackByDate: updatedFeedback);

    await HabitStorageService.updateHabit(toggled);

    await CoinsService.addCoins(result.coinsEarned);

    await _loadHabits();
  }

  void _showCompletionDetails(HabitItem habit) {
    final iso =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final feedback = habit.feedbackByDate[iso];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CompletionDetailsSheet(
        habit: habit,
        feedback: feedback,
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Time-slot tap handling
  // -----------------------------------------------------------------------

  TimeOfDay? _timeFromYOffset(double y) {
    int hour = _hourFromOffset(y);
    final fraction = _hourHeights[hour] > 0
        ? ((y - _hourYOffsets[hour]) / _hourHeights[hour]).clamp(0.0, 1.0)
        : 0.0;
    final rawMinute = (fraction * 60).toInt();
    final snappedMinute = (rawMinute / 15).round() * 15;
    final totalMinutes = hour * 60 + snappedMinute;
    final h = (totalMinutes ~/ 60).clamp(0, 23);
    final m = totalMinutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  bool _isSlotOccupied(double y) {
    for (final range in _occupiedRanges) {
      if (y >= range.$1 && y <= range.$2) return true;
    }
    return false;
  }

  void _onTimelineTap(TapUpDetails details) {
    final localY = details.localPosition.dy;
    final localX = details.localPosition.dx;
    if (localX < 56) return; // tapped on time labels area

    if (_isSlotOccupied(localY)) return;

    final time = _timeFromYOffset(localY);
    if (time == null) return;

    setState(() => _tapHighlightY = localY);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _tapHighlightY = null);
    });

    HapticFeedback.lightImpact();
    _handleSlotTap(time);
  }

  void _handleSlotTap(TimeOfDay time) {
    if (_habits.length >= _freeHabitLimit && _shouldShowAds) {
      if (_activeAdSession == null) {
        final sessionKey = 'habit_unlock_${DateTime.now().millisecondsSinceEpoch}';
        AdService.setActiveSession(sessionKey, prefs: _prefs);
        setState(() {
          _activeAdSession = sessionKey;
          _adWatchedCount = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watch 5 ads to unlock a new habit slot!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (_adWatchedCount < AdService.requiredAdsPerHabit) {
        final remaining = AdService.requiredAdsPerHabit - _adWatchedCount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Watch $remaining more ad(s) to unlock a new habit.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    _openAddHabitAtTime(time);
  }

  Future<void> _openAddHabitAtTime(TimeOfDay time) async {
    final req = await showAddHabitModal(
      context,
      existingHabits: _habits,
      initialStartTime: time,
      initialDurationMinutes: 30,
    );
    if (req == null || !mounted) return;

    final newHabit = HabitItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: req.name,
      category: req.category,
      frequency: req.frequency,
      weeklyDays: req.weeklyDays,
      deadline: req.deadline,
      afterHabitId: req.afterHabitId,
      timeOfDay: req.timeOfDay,
      reminderMinutes: req.reminderMinutes,
      reminderEnabled: req.reminderEnabled,
      chaining: req.chaining,
      cbtEnhancements: req.cbtEnhancements,
      timeBound: req.timeBound,
      locationBound: req.locationBound,
      trackingSpec: req.trackingSpec,
      iconIndex: req.iconIndex,
      completedDates: const [],
      actionSteps: req.actionSteps,
      startTimeMinutes: req.startTimeMinutes,
    );

    await HabitStorageService.addHabit(newHabit);

    if (_activeAdSession != null) {
      await AdService.clearSession(_activeAdSession!);
      await AdService.setActiveSession(null, prefs: _prefs);
      setState(() {
        _activeAdSession = null;
        _adWatchedCount = 0;
      });
    }

    await _loadHabits();
    await _loadAdState();
  }

  Future<void> _onRewardAdWatched() async {
    if (_activeAdSession == null) return;
    final newCount = await AdService.incrementWatchedCount(
      _activeAdSession!,
      prefs: _prefs,
    );
    if (mounted) setState(() => _adWatchedCount = newCount);
  }

  void _onAllAdsWatched() {
    // Ads complete — user can now tap an empty time slot
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Habit unlocked! Tap an empty time slot to create.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
        if (_activeAdSession != null && _shouldShowAds)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: RewardAdCard(
              sessionKey: _activeAdSession!,
              watchedCount: _adWatchedCount,
              onAdWatched: _onRewardAdWatched,
              onAllAdsWatched: _onAllAdsWatched,
            ),
          ),
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

  Widget _build24HourTimeline() {
    final habitsForDate = _timedHabitsForDate;
    _computeHourLayout(habitsForDate);
    final totalHeight = _hourYOffsets[24];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
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
          color: isDark
              ? colorScheme.onSurface.withValues(alpha: 0.03)
              : colorScheme.shadow.withValues(alpha: 0.02),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: _onTimelineTap,
            child: Stack(
              children: [
                ..._buildHourLines(isDark, colorScheme),
                if (isToday)
                  _buildCurrentTimeIndicator(isDark, colorScheme)
                else
                  _buildDateAnchorLine(colorScheme),
                ...habitCards,
                if (_tapHighlightY != null)
                  Positioned(
                    top: _tapHighlightY! - 1,
                    left: 56,
                    right: 24,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _tapHighlightY != null ? 1.0 : 0.0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                if (habitsForDate.isEmpty)
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
      ),
    );
  }

  Widget _buildEmptyTimelineHint() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_outlined, size: 40,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text('No habits yet',
              style: AppTypography.body(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Tap an empty time slot to create a habit',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  List<Widget> _buildHourLines(bool isDark, ColorScheme colorScheme) {
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
          color: isDark
              ? colorScheme.onSurface.withValues(alpha: 0.24)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                    style: AppTypography.bodySmall(context).copyWith(
                      fontWeight: isCurrentHour ? FontWeight.w700 : FontWeight.w600,
                      color: isCurrentHour
                          ? colorScheme.primary
                          : (isDark
                              ? colorScheme.onSurface.withValues(alpha: 0.7)
                              : colorScheme.onSurfaceVariant),
                    )),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7, right: 16),
                child: Container(
                  height: 1,
                  color: isDark
                      ? colorScheme.onSurface.withValues(alpha: 0.24)
                      : colorScheme.outlineVariant,
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
                    style: AppTypography.caption(context).copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: isDark
                          ? colorScheme.onSurface.withValues(alpha: 0.38)
                          : colorScheme.onSurfaceVariant,
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
                    color: isDark
                        ? colorScheme.onSurface.withValues(alpha: 0.12)
                        : colorScheme.outlineVariant,
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
  Widget _buildDateAnchorLine(ColorScheme colorScheme) {
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
              color: colorScheme.primary.withOpacity(0.6),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withOpacity(0.5),
                    colorScheme.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(bool isDark, ColorScheme colorScheme) {
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
                color: colorScheme.error,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.error.withOpacity(0.3 + pulseValue * 0.3),
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
                      colors: [
                    colorScheme.error,
                    colorScheme.error.withOpacity(0.3),
                  ]),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.error.withOpacity(0.2 + pulseValue * 0.2),
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
    if (habits.isEmpty) {
      _occupiedRanges = [];
      return cards;
    }

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

    _occupiedRanges = List.generate(habits.length, (i) {
      return (adjustedY[i], adjustedY[i] + cardData[i].cardHeight);
    });

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

  static Color _categoryColor(String? category, bool isDark) =>
      AppColors.categoryBgColor(category, isDark);

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
        ? colorScheme.primary
        : _categoryColor(habit.category, isDark);
    final textColor = _getContrastColor(colorScheme, tileColor);
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
          child: _compact ? _buildCompactRow(context, iconData, textColor, subtitleColor, startTime, endTime, duration, isCompleted) : _buildNormalRow(context, iconData, textColor, subtitleColor, startTime, endTime, duration, isCompleted),
        ),
      ),
    );
  }

  Widget _buildCompactRow(BuildContext context, IconData iconData, Color textColor, Color subtitleColor, int? startTime, int? endTime, int duration, bool isCompleted) {
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
                style: AppTypography.bodySmall(context).copyWith(fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatTimeShort(startTime)} – ${_formatTimeShort(endTime)}  ·  ${_formatDuration(duration)}',
                style: AppTypography.caption(context).copyWith(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.w500),
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

  Widget _buildNormalRow(BuildContext context, IconData iconData, Color textColor, Color subtitleColor, int? startTime, int? endTime, int duration, bool isCompleted) {
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
                style: AppTypography.bodySmall(context).copyWith(fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    '${_formatTimeShort(startTime)} – ${_formatTimeShort(endTime)}',
                    style: AppTypography.caption(context).copyWith(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w500),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('·', style: AppTypography.caption(context).copyWith(color: subtitleColor, fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: textColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: AppTypography.caption(context).copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor),
                    ),
                  ),
                  if (habit.actionSteps.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text('·', style: AppTypography.caption(context).copyWith(color: subtitleColor, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: textColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${habit.actionSteps.length} steps',
                        style: AppTypography.caption(context).copyWith(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor),
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

  Color _getContrastColor(ColorScheme colorScheme, Color color) {
    final luminance = color.computeLuminance();
    final isDark = colorScheme.brightness == Brightness.dark;
    if (luminance > 0.45) {
      return isDark ? colorScheme.surface : colorScheme.onSurface;
    } else {
      return isDark ? colorScheme.onSurface : colorScheme.surface;
    }
  }
}

// ---------------------------------------------------------------------------
// Completion details bottom sheet
// ---------------------------------------------------------------------------

class _CompletionDetailsSheet extends StatelessWidget {
  final HabitItem habit;
  final HabitCompletionFeedback? feedback;

  const _CompletionDetailsSheet({
    required this.habit,
    required this.feedback,
  });

  static const _moodData = <int, (IconData, String, Color)>{
    1: (Icons.sentiment_very_dissatisfied_rounded, 'Awful', AppColors.moodAwful),
    2: (Icons.sentiment_dissatisfied_rounded, 'Bad', AppColors.moodBad),
    3: (Icons.sentiment_neutral_rounded, 'Neutral', AppColors.moodNeutral),
    4: (Icons.sentiment_satisfied_rounded, 'Good', AppColors.moodGood),
    5: (Icons.sentiment_very_satisfied_rounded, 'Great', AppColors.moodGreat),
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final iconData =
        habit.iconIndex != null && habit.iconIndex! < habitIcons.length
            ? habitIcons[habit.iconIndex!].$1
            : Icons.self_improvement;

    final mood = feedback?.rating;
    final note = feedback?.note;
    final coins = feedback?.coinsEarned;
    final hasDetails = feedback != null &&
        ((mood != null && mood > 0 && _moodData.containsKey(mood)) ||
            (note != null && note.isNotEmpty) ||
            (coins != null && coins > 0));

    return Container(
      margin: const EdgeInsets.all(16),
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header: icon + name + status in a compact row
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(iconData, size: 24, color: colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.name,
                        style: AppTypography.heading3(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Completed',
                            style: AppTypography.caption(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (coins != null && coins > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.goldLight, AppColors.goldDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: AppColors.amberBorder,
                              width: 1,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.monetization_on_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+$coins',
                          style: AppTypography.bodySmall(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Detail rows inside a container
            if (hasDetails) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (mood != null &&
                        mood > 0 &&
                        _moodData.containsKey(mood))
                      _buildDetailRow(context,
                        icon: _moodData[mood]!.$1,
                        iconColor: _moodData[mood]!.$3,
                        label: 'Mood',
                        value: _moodData[mood]!.$2,
                        valueColor: _moodData[mood]!.$3,
                        colorScheme: colorScheme,
                        isFirst: true,
                        isLast: (note == null || note.isEmpty),
                      ),
                    if (note != null && note.isNotEmpty)
                      _buildNoteRow(context,
                        note: note,
                        colorScheme: colorScheme,
                        isFirst:
                            mood == null || mood <= 0 || !_moodData.containsKey(mood),
                      ),
                  ],
                ),
              ),
            ],

            if (!hasDetails) ...[
              const SizedBox(height: 24),
              Text(
                'No additional details recorded.',
                style: AppTypography.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Done',
                  style: AppTypography.button(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required ColorScheme colorScheme,
    required bool isFirst,
    required bool isLast,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 14 : 0,
        bottom: isLast ? 14 : 0,
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.secondary(context).copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: AppTypography.bodySmall(context).copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteRow(BuildContext context, {
    required String note,
    required ColorScheme colorScheme,
    required bool isFirst,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 14 : 6,
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.notes_rounded,
                size: 22, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: AppTypography.bodySmall(context).copyWith(
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
