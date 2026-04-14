import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../services/ad_free_service.dart';
import '../services/ad_service.dart';
import '../services/coins_service.dart';
import '../services/habit_storage_service.dart';
import '../services/habit_progress_widget_snapshot_service.dart';
import '../services/logical_date_service.dart';
import '../utils/app_colors.dart';
import '../utils/app_spacing.dart';
import '../utils/app_typography.dart';
import '../widgets/ads/reward_ad_card.dart';
import '../widgets/rituals/add_habit_modal.dart';
import '../widgets/rituals/habit_completion_sheet.dart';
import '../widgets/routine/routine_calendar_header.dart';
import '../widgets/rituals/habit_form_constants.dart';
import 'routine_timer_screen.dart';

/// Habit timeline screen: calendar header, sun/moon arc, 24-hour timeline of
/// habits that have a start time and duration.
class RoutineScreen extends StatefulWidget {
  final bool standalone;
  final ValueNotifier<int>? dataVersion;

  const RoutineScreen({super.key, this.standalone = false, this.dataVersion});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  SharedPreferences? _prefs;
  List<HabitItem> _habits = [];
  late DateTime _selectedDate;

  late ScrollController _timelineScrollController;
  static const double _baseHourHeight = 80.0;
  static const double _minCardHeight = 54.0;
  static const double _cardGap = 6.0;
  static const double _hourLabelPad = 18.0;
  List<double> _hourYOffsets = List.generate(25, (i) => i * _baseHourHeight);
  List<double> _hourHeights = List.filled(24, _baseHourHeight);
  List<int> _habitsPerHour = List.filled(24, 0);
  final double _viewportHeight = 0;
  int _lastCrossedHour = -1;

  // Occupied Y-ranges for empty-slot detection
  List<(double top, double bottom)> _occupiedRanges = [];

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
    _selectedDate = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
  }

  @override
  void dispose() {
    widget.dataVersion?.removeListener(_onDataVersionChanged);
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
    if (hour != _lastCrossedHour && _lastCrossedHour != -1) {
      HapticFeedback.selectionClick();
    }
    _lastCrossedHour = hour;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadHabits();
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

  Future<void> _refreshWidgetSnapshotBestEffort() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await HabitProgressWidgetSnapshotService.refreshBestEffort(prefs: prefs);
  }

  void _onDateSelected(DateTime date) {
    setState(() => _selectedDate = DateTime(date.year, date.month, date.day));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToRelevantTime(),
    );
  }

  void _scrollToRelevantTime({bool animate = true}) {
    if (!_timelineScrollController.hasClients) return;
    final now = DateTime.now();
    final isToday =
        _selectedDate.year == now.year &&
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
    final maxScroll = (totalHeight - _viewportHeight).clamp(
      0.0,
      double.infinity,
    );
    final targetOffset = (yPosition - _viewportHeight / 3).clamp(
      0.0,
      maxScroll,
    );

    if (animate) {
      _timelineScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
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
          final d = DateTime(
            deadlineDate.year,
            deadlineDate.month,
            deadlineDate.day,
          );
          if (_selectedDate.isAfter(d)) return false;
        }
      }
      return true;
    }).toList()..sort(
      (a, b) => (a.startTimeMinutes ?? 0).compareTo(b.startTimeMinutes ?? 0),
    );
  }

  /// Habits with start time + duration — placed on the 24-hour timeline.
  List<HabitItem> get _timedHabitsForDate {
    return _habitsForSelectedDate.where((h) {
      if (h.startTimeMinutes == null) return false;
      final tb = h.timeBound;
      return tb != null && tb.enabled && tb.durationMinutes > 0;
    }).toList();
  }

  void _openHabitTimer(HabitItem habit) {
    final isCompleted = habit.isCompletedForCurrentPeriod(_selectedDate);
    if (isCompleted) {
      _showCompletionDetails(habit);
      return;
    }
    Navigator.of(context)
        .push<List<String>>(
          MaterialPageRoute(
            builder: (_) => RoutineTimerScreen(
              habit: habit,
              onComplete: () => _loadHabits(),
            ),
          ),
        )
        .then((completedStepIds) async {
          await _loadHabits();
          if (completedStepIds != null && mounted) {
            await _handleHabitCompletion(habit, completedStepIds);
          }
        });
  }

  Future<void> _handleHabitCompletion(
    HabitItem habit,
    List<String> completedStepIds,
  ) async {
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

    final iso =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final feedback = HabitCompletionFeedback(
      rating: result.mood ?? 0,
      note: result.note,
      coinsEarned: result.coinsEarned,
      trackingValue: result.trackingValue,
      stepSetsByStepId: result.stepSetsById,
      stepRepsByStepId: result.stepRepsById,
    );
    final updatedFeedback = Map<String, HabitCompletionFeedback>.from(
      toggled.feedbackByDate,
    );
    updatedFeedback[iso] = feedback;
    toggled = toggled.copyWith(feedbackByDate: updatedFeedback);

    await HabitStorageService.updateHabit(toggled);

    await CoinsService.addCoins(result.coinsEarned);

    await _loadHabits();
    await _refreshWidgetSnapshotBestEffort();
  }

  void _showCompletionDetails(HabitItem habit) {
    final iso =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final feedback = habit.feedbackByDate[iso];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _CompletionDetailsSheet(habit: habit, feedback: feedback),
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

  void _handleSlotTap(TimeOfDay time) {
    if (_habits.length >= _freeHabitLimit && _shouldShowAds) {
      if (_activeAdSession == null) {
        final sessionKey =
            'habit_unlock_${DateTime.now().millisecondsSinceEpoch}';
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
      templateId: req.templateId,
      templateVersion: req.templateVersion,
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
    await _refreshWidgetSnapshotBestEffort();
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
        Expanded(child: _buildPlannerList()),
      ],
    );
  }

  Widget _buildPlannerList() {
    final habitsForDate = _timedHabitsForDate;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadHabits,
      child: habitsForDate.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              children: [_buildEmptyTimelineHint()],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: habitsForDate.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final habit = habitsForDate[index];
                return _TimelineHabitCard(
                  habit: habit,
                  selectedDate: _selectedDate,
                  height: 78,
                  onTap: () => _openHabitTimer(habit),
                  isDark: isDark,
                );
              },
            ),
    );
  }

  Widget _buildEmptyTimelineHint() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cloudWhite.withValues(alpha: 0.08)
                : AppColors.cloudWhite.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.cloudWhite.withValues(alpha: 0.12)
                  : AppColors.cloudWhite.withValues(alpha: 0.7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? AppColors.pureBlack.withValues(alpha: 0.25)
                    : AppColors.pureBlack.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 40,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),
              Text(
                'No habits yet',
                style: AppTypography.body(context).copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap an empty time slot to create a habit',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) =>
      oldDelegate.color != color;
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
    final subtitleColor = textColor.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: height.clamp(54, 200),
                padding: EdgeInsets.symmetric(
                  horizontal: _compact ? 12 : 12,
                  vertical: _compact ? 8 : 8,
                ),
                decoration: BoxDecoration(
                  color: tileColor.withValues(alpha: isDark ? 0.7 : 0.75),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.cloudWhite.withValues(alpha: 0.12)
                        : AppColors.cloudWhite.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tileColor.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _compact
                    ? _buildCompactRow(
                        context,
                        iconData,
                        textColor,
                        subtitleColor,
                        startTime,
                        endTime,
                        duration,
                        isCompleted,
                      )
                    : _buildNormalRow(
                        context,
                        iconData,
                        textColor,
                        subtitleColor,
                        startTime,
                        endTime,
                        duration,
                        isCompleted,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactRow(
    BuildContext context,
    IconData iconData,
    Color textColor,
    Color subtitleColor,
    int? startTime,
    int? endTime,
    int duration,
    bool isCompleted,
  ) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, size: 16, color: textColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                habit.name,
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatTimeShort(startTime)} – ${_formatTimeShort(endTime)}  ·  ${_formatDuration(duration)}',
                style: AppTypography.caption(
                  context,
                ).copyWith(color: subtitleColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (isCompleted) ...[
          const SizedBox(width: 8),
          Icon(Icons.check_circle, size: 20, color: textColor.withValues(alpha: 0.7)),
        ],
      ],
    );
  }

  Widget _buildNormalRow(
    BuildContext context,
    IconData iconData,
    Color textColor,
    Color subtitleColor,
    int? startTime,
    int? endTime,
    int duration,
    bool isCompleted,
  ) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: textColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, size: 18, color: textColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                habit.name,
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(fontWeight: FontWeight.w600, color: textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '${_formatTimeShort(startTime)} – ${_formatTimeShort(endTime)}',
                    style: AppTypography.caption(context).copyWith(
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '·',
                      style: AppTypography.caption(context).copyWith(
                        color: subtitleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(duration),
                      style: AppTypography.caption(context).copyWith(
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                      ),
                    ),
                  ),
                  if (habit.actionSteps.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '·',
                        style: AppTypography.caption(context).copyWith(
                          color: subtitleColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${habit.actionSteps.length} steps',
                        style: AppTypography.caption(context).copyWith(
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
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
              color: textColor.withValues(alpha: 0.12),
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

  const _CompletionDetailsSheet({required this.habit, required this.feedback});

  static const _moodData = <int, (String, String, Color)>{
    1: ('assets/moods/awful.png', 'Awful', AppColors.moodAwful),
    2: ('assets/moods/bad.png', 'Bad', AppColors.moodBad),
    3: ('assets/moods/okay.png', 'Neutral', AppColors.moodNeutral),
    4: ('assets/moods/good.png', 'Good', AppColors.moodGood),
    5: ('assets/moods/great.png', 'Great', AppColors.moodGreat),
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final iconData =
        habit.iconIndex != null && habit.iconIndex! < habitIcons.length
        ? habitIcons[habit.iconIndex!].$1
        : Icons.self_improvement;

    final mood = feedback?.rating;
    final note = feedback?.note;
    final coins = feedback?.coinsEarned;
    final hasDetails =
        feedback != null &&
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(iconData, size: 24, color: colorScheme.primary),
                ),
                const SizedBox(width: 12),
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
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: colorScheme.primary,
                          ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colorScheme.tertiaryContainer.withValues(
                              alpha: 0.28,
                            )
                          : AppColors.seedChampagne,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: AppSpacing.coinChipSize,
                          height: AppSpacing.coinChipSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [AppColors.goldLight, AppColors.goldDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: isDark
                                  ? colorScheme.outline.withValues(alpha: 0.45)
                                  : colorScheme.surface.withValues(alpha: 0.9),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? AppColors.pureBlack.withValues(alpha: 0.24)
                                    : AppColors.forestDeep.withValues(
                                        alpha: 0.12,
                                      ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.monetization_on_rounded,
                              size: AppSpacing.coinChipIcon,
                              color: AppColors.cloudWhite,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+$coins',
                          style: AppTypography.bodySmall(context).copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? colorScheme.onTertiaryContainer
                                : AppColors.honeyText,
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
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (mood != null && mood > 0 && _moodData.containsKey(mood))
                      _buildDetailRow(
                        context,
                        moodAsset: _moodData[mood]!.$1,
                        label: 'Mood',
                        value: _moodData[mood]!.$2,
                        valueColor: _moodData[mood]!.$3,
                        colorScheme: colorScheme,
                        isFirst: true,
                        isLast: (note == null || note.isEmpty),
                      ),
                    if (note != null && note.isNotEmpty)
                      _buildNoteRow(
                        context,
                        note: note,
                        colorScheme: colorScheme,
                        isFirst:
                            mood == null ||
                            mood <= 0 ||
                            !_moodData.containsKey(mood),
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text('Done', style: AppTypography.button(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required String moodAsset,
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
        top: isFirst ? 16 : 0,
        bottom: isLast ? 16 : 0,
      ),
      child: Row(
        children: [
          Image.asset(moodAsset, width: 22, height: 22),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppTypography.secondary(
              context,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: AppTypography.bodySmall(
                context,
              ).copyWith(fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteRow(
    BuildContext context, {
    required String note,
    required ColorScheme colorScheme,
    required bool isFirst,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isFirst ? 16 : 8,
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.notes_rounded,
              size: 22,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              note,
              style: AppTypography.bodySmall(
                context,
              ).copyWith(color: colorScheme.onSurface, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
