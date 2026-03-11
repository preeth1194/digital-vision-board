import 'dart:math' show pi;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/habit_item.dart';
import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../services/habit_storage_service.dart';
import '../../services/notifications_service.dart';
import '../../services/logical_date_service.dart';
import '../../services/sync_service.dart';
import '../../services/coins_service.dart';
import '../../services/journal_book_storage_service.dart';
import '../../services/journal_storage_service.dart';
import '../../services/ad_service.dart';
import '../../services/ad_free_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../../screens/routine_timer_screen.dart';
import '../rituals/add_habit_modal.dart';
import '../rituals/coin_animation_overlay.dart';
import '../rituals/animated_habit_card.dart';
import '../rituals/habit_completion_sheet.dart';
import '../routine/confetti_overlay.dart';
import '../ads/reward_ad_card.dart';
import '../habits/off_schedule_completion_dialog.dart';

enum _HabitQuickFilter {
  all,
  today,
  upcoming,
  weekly,
  timer,
  location,
  completed,
}

class AllBoardsHabitsTab extends StatefulWidget {
  final List<VisionBoardInfo> boards;
  final Map<String, List<VisionComponent>> componentsByBoardId;
  final Future<void> Function(String boardId, List<VisionComponent> updated)
  onSaveBoardComponents;
  final ValueNotifier<int>? coinNotifier;
  final GlobalKey? coinTargetKey;
  final VoidCallback? onSwitchToRoutine;
  final bool showCalendarMode;
  final ValueChanged<bool>? onCalendarModeChanged;

  const AllBoardsHabitsTab({
    super.key,
    required this.boards,
    required this.componentsByBoardId,
    required this.onSaveBoardComponents,
    this.coinNotifier,
    this.coinTargetKey,
    this.onSwitchToRoutine,
    this.showCalendarMode = false,
    this.onCalendarModeChanged,
  });

  @override
  State<AllBoardsHabitsTab> createState() => _AllBoardsHabitsTabState();
}

class _AllBoardsHabitsTabState extends State<AllBoardsHabitsTab> {
  final List<_PendingCoinAnimation> _pendingAnimations = [];
  late Map<String, List<VisionComponent>> _localComponents;
  List<HabitItem> _habits = [];
  bool _isSaving = false;
  final Map<String, GlobalKey<_SwipeableHabitCardState>> _swipeKeys = {};
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final PageController _flexibleHabitsPageController = PageController();
  double _scrollOffset = 0;
  Offset? _confettiOrigin;
  DateTime _selectedCalendarDate = LogicalDateService.now();
  String _searchQuery = '';
  _HabitQuickFilter _activeFilter = _HabitQuickFilter.all;
  bool _isFilterExpanded = false;
  int _flexibleHabitPageIndex = 0;

  // Ad-related state
  static const int _freeHabitLimit = 3;
  String? _activeAdSession;
  int _adWatchedCount = 0;
  bool _shouldShowAds = true;

  @override
  void initState() {
    super.initState();
    _localComponents = Map.from(widget.componentsByBoardId);
    _scrollController.addListener(_onScroll);
    _loadHabits();
    _loadAdState();
  }

  Future<void> _loadAdState() async {
    final showAds = await AdFreeService.shouldShowAds();
    final session = await AdService.getActiveSession();
    int watched = 0;
    if (session != null) {
      watched = await AdService.getWatchedCount(session);
    }
    if (mounted) {
      setState(() {
        _shouldShowAds = showAds;
        _activeAdSession = session;
        _adWatchedCount = watched;
      });
    }
  }

  Future<void> _loadHabits() async {
    final habits = await HabitStorageService.loadAll();
    if (mounted) setState(() => _habits = habits);
    if (widget.coinNotifier != null) {
      final coins = await CoinsService.getTotalCoins();
      if (mounted) widget.coinNotifier!.value = coins;
    }
  }

  void _onScroll() {
    final nextOffset = _scrollController.offset;
    if ((nextOffset - _scrollOffset).abs() < 12) return;
    if (!mounted) return;
    setState(() {
      _scrollOffset = nextOffset;
    });
  }

  @override
  void didUpdateWidget(AllBoardsHabitsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.componentsByBoardId != oldWidget.componentsByBoardId) {
      if (_isSaving) return;
      _localComponents = Map.from(widget.componentsByBoardId);
      _loadHabits();
      _loadAdState();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _flexibleHabitsPageController.dispose();
    super.dispose();
  }

  static String _toIsoDate(DateTime d) => LogicalDateService.toIsoDate(d);

  String _boardTitle(String? boardId) {
    if (boardId == null) return '';
    return widget.boards
            .cast<VisionBoardInfo?>()
            .firstWhere((b) => b?.id == boardId, orElse: () => null)
            ?.title ??
        '';
  }

  Future<void> _addHabitGlobal() async {
    // Gate: non-subscribed users with 3+ habits must watch ads first
    if (_habits.length >= _freeHabitLimit && _shouldShowAds) {
      // Session already complete — let user proceed to add the habit
      if (_activeAdSession != null &&
          _adWatchedCount >= AdService.requiredAdsPerHabit) {
        // Fall through to _proceedToAddHabit()
      } else if (_activeAdSession != null) {
        // Session in progress — tell user to watch the ads on the card above
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Watch ${AdService.requiredAdsPerHabit - _adWatchedCount} more ad(s) to unlock a new habit.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      } else {
        // No session yet — create one so the ad card appears
        final sessionKey =
            'habit_unlock_${DateTime.now().millisecondsSinceEpoch}';
        await AdService.setActiveSession(sessionKey);
        if (!mounted) return;
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
    }

    await _proceedToAddHabit();
  }

  Future<void> _proceedToAddHabit() async {
    final req = await showAddHabitModal(context, existingHabits: _habits);
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
    await _loadHabits();

    // Clear the completed ad session
    if (_activeAdSession != null) {
      await AdService.clearSession(_activeAdSession!);
      await AdService.setActiveSession(null);
      setState(() {
        _activeAdSession = null;
        _adWatchedCount = 0;
      });
    }

    Future<void>(() async {
      if (!NotificationsService.shouldSchedule(newHabit)) return;
      final ok = await NotificationsService.requestPermissionsIfNeeded();
      if (!ok) return;
      await NotificationsService.scheduleHabitReminders(newHabit);
    });
  }

  Future<void> _onRewardAdWatched() async {
    if (_activeAdSession == null) return;
    final newCount = await AdService.incrementWatchedCount(_activeAdSession!);
    if (mounted) {
      setState(() => _adWatchedCount = newCount);
    }
  }

  void _onAllAdsWatched() {
    _proceedToAddHabit();
  }

  Future<void> _handleHabitTap({
    required HabitItem habit,
    required GlobalKey cardKey,
    required bool isFlipped,
  }) async {
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) {
      final choice = await showOffScheduleCompletionDialog(
        context: context,
        habit: habit,
      );
      if (!mounted) return;
      if (choice == OffScheduleCompletionChoice.cancel) return;
      if (choice == OffScheduleCompletionChoice.changeSchedule) {
        await _editHabit(
          _HabitEntry(
            boardId: habit.boardId ?? '',
            boardTitle: _boardTitle(habit.boardId),
            habit: habit,
          ),
        );
        return;
      }
    }

    final isCompleted = habit.isCompletedForCurrentPeriod(now);

    if (isCompleted) {
      await _toggleHabit(habit: habit, wasCompleted: true);
    } else {
      // Determine coins based on card flip state
      final completionType = isFlipped
          ? CompletionType.copingPlan
          : CompletionType.habit;
      final coins = CoinsService.getCoinsForCompletionType(completionType);

      final isFullHabit = completionType == CompletionType.habit;

      // Show completion sheet with base coins (bonuses computed inside)
      final result = await showHabitCompletionSheet(
        context,
        habit: habit,
        baseCoins: coins,
        isFullHabit: isFullHabit,
      );
      if (result == null) return;

      final earnedCoins = result.coinsEarned;

      // Get card position for confetti and coin flying animation
      final RenderBox? cardBox =
          cardKey.currentContext?.findRenderObject() as RenderBox?;
      final RenderBox? targetBox =
          widget.coinTargetKey?.currentContext?.findRenderObject()
              as RenderBox?;

      Offset? cardPosition;
      Offset? targetPosition;

      if (cardBox != null) {
        cardPosition = cardBox.localToGlobal(
          Offset(cardBox.size.width / 2, cardBox.size.height / 2),
        );
      }
      if (targetBox != null) {
        targetPosition = targetBox.localToGlobal(
          Offset(targetBox.size.width / 2, targetBox.size.height / 2),
        );
      }

      if (!mounted) return;

      // Convert coin target (app bar) position to local coordinates relative
      // to the Stack so the confetti overlay bursts at the coin badge.
      Offset? localConfettiOrigin = targetPosition;
      if (targetPosition != null) {
        final RenderBox? stackBox = context.findRenderObject() as RenderBox?;
        if (stackBox != null) {
          localConfettiOrigin = stackBox.globalToLocal(targetPosition);
        }
      }

      // Show confetti celebration anchored to the coin badge in the app bar
      setState(() => _confettiOrigin = localConfettiOrigin);

      // Queue flying coin animation
      if (cardPosition != null && targetPosition != null) {
        _pendingAnimations.add(
          _PendingCoinAnimation(
            source: cardPosition,
            target: targetPosition,
            coins: earnedCoins,
          ),
        );
      }

      final feedback = HabitCompletionFeedback(
        rating: result.mood ?? 0,
        note: result.note,
        coinsEarned: earnedCoins,
        trackingValue: result.trackingValue,
        stepSetsByStepId: result.stepSetsById,
        stepRepsByStepId: result.stepRepsById,
      );

      await _toggleHabit(
        habit: habit,
        wasCompleted: false,
        completionType: completionType,
        coinsEarned: earnedCoins,
        feedback: feedback,
        completedStepIds: result.completedStepIds,
        audioPath: result.audioPath,
        capturedImagePaths: result.imagePaths,
      );

      // Show interstitial ad after completion if user should see ads
      if (_shouldShowAds && mounted) {
        AdService.showInterstitialAd();
      }
    }
  }

  Future<void> _toggleHabit({
    required HabitItem habit,
    required bool wasCompleted,
    CompletionType? completionType,
    int? coinsEarned,
    HabitCompletionFeedback? feedback,
    List<String> completedStepIds = const [],
    String? audioPath,
    List<String> capturedImagePaths = const [],
  }) async {
    final now = LogicalDateService.now();
    var toggled = habit.toggleForDate(now);

    if (!wasCompleted && feedback != null) {
      final iso = _toIsoDate(now);
      final updatedFeedback = Map<String, HabitCompletionFeedback>.from(
        toggled.feedbackByDate,
      );
      updatedFeedback[iso] = feedback;
      toggled = toggled.copyWith(feedbackByDate: updatedFeedback);

      final moodLabels = ['', 'Awful', 'Bad', 'Okay', 'Good', 'Great'];
      final moodText = feedback.rating > 0 && feedback.rating <= 5
          ? 'Mood: ${moodLabels[feedback.rating]} (${feedback.rating}/5)'
          : '';

      // Build step completion summary with count
      String stepsText = '';
      if (completedStepIds.isNotEmpty && habit.actionSteps.isNotEmpty) {
        final total = habit.actionSteps.length;
        final done = completedStepIds.length;
        final stepNames = completedStepIds
            .map(
              (id) => habit.actionSteps
                  .where((s) => s.id == id)
                  .map((s) => s.title)
                  .firstOrNull,
            )
            .whereType<String>()
            .toList();
        stepsText = 'Steps: $done/$total completed';
        if (stepNames.isNotEmpty) {
          stepsText += ' — ${stepNames.join(', ')}';
        }
      }

      String trackingText = '';
      if (feedback.trackingValue != null && habit.trackingSpec != null) {
        final v = feedback.trackingValue!;
        final display = v == v.roundToDouble()
            ? v.toInt().toString()
            : v.toStringAsFixed(1);
        final unit = habit.trackingSpec!.unitLabel;
        trackingText = 'Tracked: $display $unit';
      }

      String setsRepsText = '';
      if (completedStepIds.isNotEmpty &&
          (feedback.stepSetsByStepId.isNotEmpty ||
              feedback.stepRepsByStepId.isNotEmpty)) {
        final perStepLogs = <String>[];
        for (final stepId in completedStepIds) {
          final step = habit.actionSteps
              .where((s) => s.id == stepId)
              .cast<HabitActionStep?>()
              .firstWhere((_) => true, orElse: () => null);
          if (step == null) continue;
          final sets = feedback.stepSetsByStepId[stepId];
          final reps = feedback.stepRepsByStepId[stepId];
          if (sets == null && reps == null) continue;
          final metric = sets != null && reps != null
              ? '${sets}x$reps'
              : (sets != null ? '$sets sets' : '$reps reps');
          perStepLogs.add('${step.title}: $metric');
        }
        if (perStepLogs.isNotEmpty) {
          setsRepsText = 'Sets/Reps: ${perStepLogs.join(' | ')}';
        }
      }

      final noteText = (feedback.note ?? '').trim();
      final dayLog = [
        moodText,
        trackingText,
        stepsText,
        setsRepsText,
        noteText,
      ].where((s) => s.isNotEmpty).join('\n');
      final hasMedia = audioPath != null || capturedImagePaths.isNotEmpty;
      if (dayLog.isNotEmpty || hasMedia) {
        JournalStorageService.appendOrCreateGoalLog(
          habitId: habit.id,
          habitName: habit.name,
          dayLog: dayLog.isEmpty ? 'Completed' : dayLog,
          bookId: JournalBookStorageService.goalLogsBookId,
          audioPaths: audioPath != null ? [audioPath] : null,
          imagePaths: capturedImagePaths.isNotEmpty ? capturedImagePaths : null,
        );
      }
    }

    // Save to HabitStorageService (source of truth)
    await HabitStorageService.updateHabit(toggled);

    // Optimistic local update
    setState(() {
      final idx = _habits.indexWhere((h) => h.id == habit.id);
      if (idx != -1) _habits[idx] = toggled;
    });

    // Backward compat: update component storage if habit belongs to a board
    if (habit.boardId != null && habit.boardId!.isNotEmpty) {
      final components =
          _localComponents[habit.boardId!] ?? const <VisionComponent>[];
      if (components.isNotEmpty && habit.componentId != null) {
        final comp = components.cast<VisionComponent?>().firstWhere(
          (c) => c?.id == habit.componentId,
          orElse: () => null,
        );
        if (comp != null) {
          final updatedHabits = comp.habits
              .map((h) => h.id == habit.id ? toggled : h)
              .toList();
          final updatedComponent = comp.copyWithCommon(habits: updatedHabits);
          final updatedComponents = components
              .map((c) => c.id == comp.id ? updatedComponent : c)
              .toList();
          _isSaving = true;
          await widget.onSaveBoardComponents(habit.boardId!, updatedComponents);
          _localComponents[habit.boardId!] = updatedComponents;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _isSaving = false;
            });
          });
        }
      }
    }

    // Sync
    final iso = _toIsoDate(now);
    Future<void>(() async {
      await SyncService.enqueueHabitCompletion(
        boardId: habit.boardId ?? '',
        componentId: habit.componentId ?? '',
        habitId: habit.id,
        logicalDate: iso,
        deleted: wasCompleted,
      );
    });

    // Award coins on completion, or deduct on uncheck
    if (!wasCompleted && coinsEarned != null && coinsEarned > 0) {
      final newTotal = await CoinsService.addCoins(coinsEarned);

      final streakBonus = await CoinsService.checkAndAwardStreakBonus(
        habit.id,
        toggled.currentStreak,
      );

      if (mounted) {
        widget.coinNotifier?.value = streakBonus ?? newTotal;

        HapticFeedback.heavyImpact();

        if (streakBonus != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.celebration, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text('Streak bonus! +${CoinsService.streakBonusCoins} coins'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else if (wasCompleted) {
      // Deduct the exact coins that were earned for this completion
      final iso = _toIsoDate(now);
      final savedFeedback = habit.feedbackByDate[iso];
      final coinsToDeduct =
          savedFeedback?.coinsEarned ?? CoinsService.habitCompletionCoins;
      final newTotal = await CoinsService.addCoins(-coinsToDeduct);

      if (mounted) {
        final clamped = newTotal < 0 ? 0 : newTotal;
        widget.coinNotifier?.value = clamped;
        HapticFeedback.lightImpact();
      }
    }
  }

  void _openTimerForHabit(_HabitEntry entry) {
    final habit = entry.habit;
    if (habit.timeBound?.enabled != true &&
        habit.locationBound?.enabled != true)
      return;

    final referenceDate = widget.showCalendarMode
        ? _selectedCalendarDate
        : LogicalDateService.now();
    final isCompleted = habit.isCompletedForCurrentPeriod(referenceDate);
    if (isCompleted) {
      _showTimelineCompletionDetails(habit, referenceDate);
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
            await _handleTimerCompletion(habit, completedStepIds);
          }
        });
  }

  void _showTimelineCompletionDetails(HabitItem habit, DateTime selectedDate) {
    final iso =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    final feedback = habit.feedbackByDate[iso];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) =>
          _TimelineCompletionDetailsSheet(habit: habit, feedback: feedback),
    );
  }

  void _handleTimelineSlotTap(int minutesFromMidnight) {
    final currentCount = _habits.length;
    if (currentCount >= _freeHabitLimit && _shouldShowAds) {
      if (_activeAdSession == null) {
        final sessionKey =
            'habit_unlock_${DateTime.now().millisecondsSinceEpoch}';
        AdService.setActiveSession(sessionKey);
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
    final hour = (minutesFromMidnight ~/ 60).clamp(0, 23);
    final minute = minutesFromMidnight % 60;
    _openAddHabitAtTime(TimeOfDay(hour: hour, minute: minute));
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
    await _loadHabits();

    if (_activeAdSession != null) {
      await AdService.clearSession(_activeAdSession!);
      await AdService.setActiveSession(null);
      setState(() {
        _activeAdSession = null;
        _adWatchedCount = 0;
      });
    }
  }

  Future<void> _handleTimerCompletion(
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

    await _toggleHabit(
      habit: latestHabit,
      wasCompleted: false,
      completionType: CompletionType.habit,
      coinsEarned: result.coinsEarned,
      feedback: HabitCompletionFeedback(
        rating: result.mood ?? 0,
        note: result.note,
        coinsEarned: result.coinsEarned,
        trackingValue: result.trackingValue,
        stepSetsByStepId: result.stepSetsById,
        stepRepsByStepId: result.stepRepsById,
      ),
      completedStepIds: result.completedStepIds,
      audioPath: result.audioPath,
      capturedImagePaths: result.imagePaths,
    );
  }

  Future<void> _editHabit(_HabitEntry entry) async {
    final req = await showAddHabitModal(
      context,
      existingHabits: _habits,
      initialHabit: entry.habit,
    );
    if (req == null || !mounted) return;

    final updatedHabit = entry.habit.copyWith(
      name: req.name,
      category: req.category,
      frequency: req.frequency,
      weeklyDays: req.weeklyDays,
      deadline: req.deadline,
      afterHabitId: req.afterHabitId,
      timeOfDay: req.timeOfDay,
      reminderMinutes: req.reminderMinutes,
      reminderEnabled: req.reminderEnabled,
      timeBound: req.timeBound,
      clearTimeBound: req.timeBound == null,
      locationBound: req.locationBound,
      trackingSpec: req.trackingSpec,
      clearTrackingSpec: req.trackingSpec == null,
      chaining: req.chaining,
      cbtEnhancements: req.cbtEnhancements,
      iconIndex: req.iconIndex,
      actionSteps: req.actionSteps,
      startTimeMinutes: req.startTimeMinutes,
      templateId: req.templateId,
      templateVersion: req.templateVersion,
      clearStartTimeMinutes: req.startTimeMinutes == null,
    );

    await HabitStorageService.updateHabit(updatedHabit);
    await _loadHabits();

    if (NotificationsService.shouldSchedule(updatedHabit)) {
      await NotificationsService.scheduleHabitReminders(updatedHabit);
    }

    HapticFeedback.mediumImpact();
  }

  Future<void> _deleteHabit(_HabitEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit'),
        content: Text(
          'Are you sure you want to delete "${entry.habit.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await HabitStorageService.deleteHabit(entry.habit.id);
    await _loadHabits();

    if (_habits.length < _freeHabitLimit && _activeAdSession != null) {
      await AdService.clearSession(_activeAdSession!);
      await AdService.setActiveSession(null);
      setState(() {
        _activeAdSession = null;
        _adWatchedCount = 0;
      });
    }

    await NotificationsService.cancelHabitReminders(entry.habit);

    HapticFeedback.mediumImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${entry.habit.name}" deleted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onAnimationComplete(int index) {
    setState(() {
      if (index < _pendingAnimations.length) {
        _pendingAnimations.removeAt(index);
      }
    });
    // Refresh coin count in the AppBar after animation
    CoinsService.getTotalCoins().then((coins) {
      if (mounted) widget.coinNotifier?.value = coins;
    });
  }

  Widget _buildSectionLabel(String label, {Widget? trailing}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.bodySmall(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildViewModeAction({
    required String label,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        widget.onCalendarModeChanged?.call(!widget.showCalendarMode);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.bodySmall(context).copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesQuery(_HabitEntry entry) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;
    final habit = entry.habit;
    final name = habit.name.toLowerCase();
    final category = (habit.category ?? '').toLowerCase();
    final board = entry.boardTitle.toLowerCase();
    return name.contains(q) || category.contains(q) || board.contains(q);
  }

  bool _matchesFilter(_HabitEntry entry, DateTime now) {
    final habit = entry.habit;
    switch (_activeFilter) {
      case _HabitQuickFilter.all:
        return true;
      case _HabitQuickFilter.today:
        return habit.isScheduledOnDate(now);
      case _HabitQuickFilter.upcoming:
        return !habit.isScheduledOnDate(now);
      case _HabitQuickFilter.weekly:
        return habit.isWeekly;
      case _HabitQuickFilter.timer:
        return habit.timeBound?.enabled == true;
      case _HabitQuickFilter.location:
        return habit.locationBound?.enabled == true;
      case _HabitQuickFilter.completed:
        return habit.isCompletedForCurrentPeriod(now);
    }
  }

  String _filterLabel(_HabitQuickFilter filter) {
    switch (filter) {
      case _HabitQuickFilter.all:
        return 'All';
      case _HabitQuickFilter.today:
        return 'Today';
      case _HabitQuickFilter.upcoming:
        return 'Upcoming';
      case _HabitQuickFilter.weekly:
        return 'Weekly';
      case _HabitQuickFilter.timer:
        return 'Timer';
      case _HabitQuickFilter.location:
        return 'Location';
      case _HabitQuickFilter.completed:
        return 'Completed';
    }
  }

  void _resetSearchAndFilters() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _activeFilter = _HabitQuickFilter.all;
      _isFilterExpanded = false;
    });
  }

  List<_HabitQuickFilter> _filterOptions() {
    return const <_HabitQuickFilter>[
      _HabitQuickFilter.today,
      _HabitQuickFilter.upcoming,
      _HabitQuickFilter.weekly,
      _HabitQuickFilter.timer,
      _HabitQuickFilter.location,
      _HabitQuickFilter.completed,
    ];
  }

  Widget _buildPinnedControlsRow() {
    if (widget.showCalendarMode) {
      return const SizedBox.shrink();
    }
    final hasFilter = _activeFilter != _HabitQuickFilter.all;
    final showClear = _searchQuery.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search habits',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showClear)
                          IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                        IconButton(
                          tooltip: _isFilterExpanded
                              ? 'Hide filters'
                              : 'Show filters',
                          onPressed: () {
                            setState(() {
                              _isFilterExpanded = !_isFilterExpanded;
                            });
                          },
                          icon: Badge(
                            isLabelVisible: hasFilter,
                            label: const Text('1'),
                            child: Icon(
                              _isFilterExpanded
                                  ? Icons.expand_less
                                  : Icons.tune,
                            ),
                          ),
                        ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterStrip() {
    final options = <_HabitQuickFilter>[
      _HabitQuickFilter.all,
      ..._filterOptions(),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: options
              .map(
                (filter) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_filterLabel(filter)),
                    selected: _activeFilter == filter,
                    onSelected: (_) {
                      setState(() {
                        _activeFilter = filter;
                        _isFilterExpanded = false;
                      });
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildControlsSummaryRow() {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    final hasFilter = _activeFilter != _HabitQuickFilter.all;
    final hasActiveControls = hasSearch || hasFilter;
    if (!hasActiveControls) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              hasSearch && hasFilter
                  ? 'Search + ${_filterLabel(_activeFilter)} filter active'
                  : hasSearch
                  ? 'Search active'
                  : '${_filterLabel(_activeFilter)} filter active',
              style: AppTypography.bodySmall(context),
            ),
          ),
          TextButton(
            onPressed: _resetSearchAndFilters,
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
  }

  void _setSelectedCalendarDate(DateTime date) {
    setState(() {
      _selectedCalendarDate = DateTime(date.year, date.month, date.day);
    });
  }

  Future<void> _openCalendarDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedCalendarDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null || !mounted) return;
    _setSelectedCalendarDate(picked);
  }

  DateTime _weekStart(DateTime date) {
    final weekday = date.weekday % 7; // 0=Sun, 1=Mon, ..., 6=Sat
    return DateTime(date.year, date.month, date.day - weekday);
  }

  Widget _buildTimelineDateHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selectedCalendarDate;
    final todayNow = LogicalDateService.now();
    final today = DateTime(todayNow.year, todayNow.month, todayNow.day);
    final monthText = DateFormat('MMMM yyyy').format(selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.58),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _openCalendarDatePicker,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.14)
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                monthText,
                                style: AppTypography.bodySmall(context).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => _setSelectedCalendarDate(today),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Today',
                          style: AppTypography.caption(context).copyWith(
                            color: colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: _MonthWeekScroller(
                    selectedDate: _selectedCalendarDate,
                    onDateSelected: _setSelectedCalendarDate,
                    today: today,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isTimedHabit(HabitItem habit) {
    if (habit.startTimeMinutes == null) return false;
    final tb = habit.timeBound;
    return tb != null && tb.enabled && tb.durationMinutes > 0;
  }

  int _habitDurationMinutes(HabitItem habit) {
    final tb = habit.timeBound;
    if (tb == null || !tb.enabled) return 0;
    return tb.durationMinutes;
  }

  String _formatMinutesLabel(int minutes) {
    final clamped = minutes.clamp(0, 23 * 60 + 59);
    final hour = clamped ~/ 60;
    final minute = clamped % 60;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatHourLabel(int hour) {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$hour12 $period';
  }

  Future<_TimelineScheduleSelection?> _showTimelineScheduleDialog({
    required int initialStartMinutes,
    required HabitItem habit,
  }) {
    const durationOptions = <int>[15, 30, 45, 60, 90, 120];
    final initialDuration = _habitDurationMinutes(habit) > 0
        ? _habitDurationMinutes(habit)
        : 30;
    final roundedStart = (initialStartMinutes ~/ 15) * 15;
    final clampedStart = roundedStart.clamp(0, 23 * 60 + 45);
    final startOptions = List<int>.generate(96, (index) => index * 15);
    final normalizedInitialDuration = durationOptions.contains(initialDuration)
        ? initialDuration
        : 30;
    return showDialog<_TimelineScheduleSelection>(
      context: context,
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        var selectedStart =
            startOptions.contains(clampedStart) ? clampedStart : startOptions[0];
        var selectedDuration = normalizedInitialDuration;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.46),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.white.withValues(alpha: 0.62),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Set start time & duration',
                        style: AppTypography.heading3(context).copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Start time',
                        style: AppTypography.caption(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: selectedStart,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.28),
                            ),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.26),
                        ),
                        items: startOptions
                            .map(
                              (minutes) => DropdownMenuItem<int>(
                                value: minutes,
                                child: Text(_formatMinutesLabel(minutes)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedStart = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Duration',
                        style: AppTypography.caption(
                          context,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: selectedDuration,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: colorScheme.outline.withValues(alpha: 0.28),
                            ),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.white.withValues(alpha: 0.26),
                        ),
                        items: durationOptions
                            .map(
                              (minutes) => DropdownMenuItem<int>(
                                value: minutes,
                                child: Text(
                                  minutes >= 60
                                      ? '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)} hr'
                                      : '$minutes min',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => selectedDuration = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: () {
                              Navigator.of(ctx).pop(
                                _TimelineScheduleSelection(
                                  startMinutes: selectedStart,
                                  durationMinutes: selectedDuration,
                                ),
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _hasTimelineConflict({
    required HabitItem movingHabit,
    required int startMinutes,
    required int durationMinutes,
    required DateTime selectedDate,
  }) {
    final endMinutes = startMinutes + durationMinutes;
    for (final h in _habits) {
      if (h.id == movingHabit.id) continue;
      if (!h.isScheduledOnDate(selectedDate)) continue;
      if (!_isTimedHabit(h)) continue;
      final otherStart = h.startTimeMinutes ?? 0;
      final otherEnd = otherStart + _habitDurationMinutes(h);
      if (startMinutes < otherEnd && endMinutes > otherStart) {
        return true;
      }
    }
    return false;
  }

  Future<void> _handleFlexibleDrop(
    _FlexibleHabitDragData data,
    int startMinutes,
  ) async {
    final selection = await _showTimelineScheduleDialog(
      initialStartMinutes: startMinutes,
      habit: data.habit,
    );
    if (selection == null || !mounted) return;

    if (_hasTimelineConflict(
      movingHabit: data.habit,
      startMinutes: selection.startMinutes,
      durationMinutes: selection.durationMinutes,
      selectedDate: _selectedCalendarDate,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This time overlaps with another time-bound habit.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final existingTimeBound = data.habit.timeBound;
    final nextTimeBound = existingTimeBound == null
        ? HabitTimeBoundSpec(
            enabled: true,
            duration: selection.durationMinutes,
            unit: 'minutes',
          )
        : existingTimeBound.copyWith(
            enabled: true,
            duration: selection.durationMinutes,
            unit: 'minutes',
          );
    final updatedHabit = data.habit.copyWith(
      startTimeMinutes: selection.startMinutes,
      timeBound: nextTimeBound,
    );

    await HabitStorageService.updateHabit(updatedHabit);
    await _loadHabits();

    if (!mounted) return;
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${updatedHabit.name} scheduled at ${_formatMinutesLabel(selection.startMinutes)}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildTimelineHabitChip(_HabitEntry entry) {
    final habit = entry.habit;
    final colorScheme = Theme.of(context).colorScheme;
    final duration = _habitDurationMinutes(habit);
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: InkWell(
        onTap: () => _openTimerForHabit(entry),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall(
                    context,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${duration}m',
                style: AppTypography.caption(
                  context,
                ).copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlexibleHabitCard(_HabitEntry entry) {
    final habit = entry.habit;
    final now = LogicalDateService.now();
    final isCompleted = habit.isCompletedForCurrentPeriod(now);
    final cardKey = GlobalKey();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget buildCard({
      required bool attachAnchorKey,
      required bool interactive,
    }) {
      return Row(
        key: attachAnchorKey ? cardKey : null,
        children: [
          _TimelineCheckpoint(
            isCompleted: isCompleted,
            onTap: interactive
                ? () => _handleHabitTap(
                    habit: habit,
                    cardKey: cardKey,
                    isFlipped: false,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white.withValues(alpha: 0.34),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.drag_indicator_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          habit.name,
                          style: AppTypography.bodySmall(context).copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Flexible',
                        style: AppTypography.caption(
                          context,
                        ).copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Draggable<_FlexibleHabitDragData>(
      data: _FlexibleHabitDragData(habit),
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: buildCard(attachAnchorKey: false, interactive: false),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: buildCard(attachAnchorKey: false, interactive: false),
      ),
      child: buildCard(attachAnchorKey: true, interactive: true),
    );
  }

  Widget _buildFlexibleHabitsStickyCarousel({
    required List<_HabitEntry> flexibleHabits,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visibleIndex = flexibleHabits.isEmpty
        ? 0
        : _flexibleHabitPageIndex
              .clamp(0, flexibleHabits.length - 1)
              .toInt();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
                  child: Row(
                    children: [
                      Text(
                        'Flexible Habits',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      _buildViewModeAction(
                        label: 'List',
                        icon: Icons.view_list_rounded,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _flexibleHabitsPageController,
                    itemCount: flexibleHabits.length,
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() => _flexibleHabitPageIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        child: _buildFlexibleHabitCard(flexibleHabits[index]),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Swipe to scroll, drag and drop in timeline',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(
                            context,
                          ).copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      if (flexibleHabits.length > 1)
                        Row(
                          children: List.generate(flexibleHabits.length, (index) {
                            final isActive = index == visibleIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              width: isActive ? 14 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            );
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarTimeline({required List<_HabitEntry> timedHabits}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const leftLabelWidth = 52.0;
    const contentLeft = 60.0;
    const rightPad = 16.0;
    const hourHeight = 80.0;
    const minCardHeight = 54.0;
    const cardGap = 6.0;
    final totalHeight = 24 * hourHeight;

    final sortedHabits = [...timedHabits]
      ..sort(
        (a, b) => (a.habit.startTimeMinutes ?? 0).compareTo(
          b.habit.startTimeMinutes ?? 0,
        ),
      );
    final positionedCards = <_TimelineCardLayout>[];
    double nextMinTop = 0;
    for (final entry in sortedHabits) {
      final start = (entry.habit.startTimeMinutes ?? 0).clamp(0, 23 * 60 + 59);
      final duration = _habitDurationMinutes(entry.habit).clamp(15, 180);
      final naturalTop = (start / 60.0) * hourHeight;
      final top = naturalTop < nextMinTop ? nextMinTop : naturalTop;
      final height = ((duration / 60.0) * hourHeight).clamp(
        minCardHeight,
        220.0,
      );
      nextMinTop = top + height + cardGap;
      positionedCards.add(
        _TimelineCardLayout(entry: entry, top: top, height: height),
      );
    }

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            bottom: 0,
            left: leftLabelWidth,
            width: 2,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.onSurface.withValues(alpha: 0.24)
                    : colorScheme.outlineVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          ...List.generate(24, (hour) {
            final y = hour * hourHeight;
            final slotStart = hour * 60;
            final halfLabel = '${(hour % 12 == 0 ? 12 : hour % 12)}:30';
            return Stack(
              children: [
                Positioned(
                  top: y,
                  left: 0,
                  right: 0,
                  height: hourHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: leftLabelWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2, top: 1),
                          child: Text(
                            _formatHourLabel(hour),
                            style: AppTypography.bodySmall(context).copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, right: 8),
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
                ),
                Positioned(
                  top: y + (hourHeight / 2),
                  left: 0,
                  right: 0,
                  height: 16,
                  child: Row(
                    children: [
                      SizedBox(
                        width: leftLabelWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6, top: 1),
                          child: Text(
                            halfLabel,
                            textAlign: TextAlign.left,
                            style: AppTypography.caption(context).copyWith(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.55,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Container(
                            height: 1,
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: y,
                  left: contentLeft,
                  right: rightPad,
                  height: hourHeight,
                  child: DragTarget<_FlexibleHabitDragData>(
                    onWillAcceptWithDetails: (_) => true,
                    onAcceptWithDetails: (details) {
                      _handleFlexibleDrop(details.data, slotStart);
                    },
                    builder: (context, candidates, rejected) {
                      final isHovered = candidates.isNotEmpty;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final localY = details.localPosition.dy.clamp(
                            0.0,
                            hourHeight,
                          );
                          final minuteOffset = ((localY / hourHeight) * 60)
                              .toInt();
                          final snapped = ((minuteOffset / 15).round() * 15)
                              .clamp(0, 59);
                          final tappedMinute = slotStart + snapped;
                          _handleTimelineSlotTap(tappedMinute);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            border: isHovered
                                ? Border.all(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.45,
                                    ),
                                  )
                                : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: isHovered
                              ? Center(
                                  child: Text(
                                    'Drop at ${_formatMinutesLabel(slotStart)}',
                                    style: AppTypography.caption(context)
                                        .copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }),
          if (timedHabits.isEmpty)
            Positioned(
              top: hourHeight * 7,
              left: contentLeft,
              right: rightPad,
              child: Text(
                'Drop flexible habits into a time slot',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall(context).copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...positionedCards.map(
            (item) => Positioned(
              top: item.top,
              left: contentLeft + 4,
              right: rightPad + 4,
              height: item.height,
              child: _buildTimelineHabitChip(item.entry),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitTimelineRow({
    required _HabitEntry entry,
    required int index,
    required bool isFirst,
    required bool isLast,
  }) {
    final now = LogicalDateService.now();
    final scheduledToday = entry.habit.isScheduledOnDate(now);
    final isCompleted = entry.habit.isCompletedForCurrentPeriod(now);
    final swipeKey = _swipeKeys.putIfAbsent(
      entry.habit.id,
      () => GlobalKey<_SwipeableHabitCardState>(),
    );
    return _ScrollAnimatedItem(
      index: index,
      scrollOffset: _scrollOffset,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Expanded(
                      child: isFirst ? const SizedBox() : const _TimelineDash(),
                    ),
                    _TimelineCheckpoint(
                      isCompleted: isCompleted,
                      onTap: () => _handleHabitTap(
                        habit: entry.habit,
                        cardKey: swipeKey,
                        isFlipped: swipeKey.currentState?.isFlipped ?? false,
                      ),
                    ),
                    Expanded(
                      child: isLast ? const SizedBox() : const _TimelineDash(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _SwipeableHabitCard(
                  key: swipeKey,
                  entry: entry,
                  onEdit: () => _editHabit(entry),
                  onDelete: () => _deleteHabit(entry),
                  child: AnimatedHabitCard(
                    key: ValueKey(entry.habit.id),
                    habit: entry.habit,
                    boardTitle: entry.boardTitle,
                    isCompleted: isCompleted,
                    isScheduledToday: scheduledToday,
                    coinsOnComplete: CoinsService.habitCompletionCoins,
                    index: index,
                    onTap: () => swipeKey.currentState?.toggleFlip(),
                    onIconTap: () => swipeKey.currentState?.toggleFlip(),
                    onLongPress: () => _openTimerForHabit(entry),
                    onDurationTap: () => _openTimerForHabit(entry),
                    adWatchedCount: null,
                    adTotalRequired: null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarModeContent({
    required List<_HabitEntry> dayHabits,
    required List<_HabitEntry> timedHabits,
    required ColorScheme colorScheme,
  }) {
    final selectedDateLabel = DateFormat('EEE, MMM d').format(
      _selectedCalendarDate,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionLabel('Timeline Habits'),
        _buildCalendarTimeline(timedHabits: timedHabits),
        if (timedHabits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'No time-bound habits for this date. Drag a flexible habit into the timeline.',
              style: AppTypography.bodySmall(
                context,
              ).copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        if (dayHabits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.search_off),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No habits scheduled for $selectedDateLabel.',
                        style: AppTypography.bodySmall(context),
                      ),
                    ),
                    TextButton(
                      onPressed: _resetSearchAndFilters,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildDefaultModeContent({
    required List<_HabitEntry> todayHabits,
    required List<_HabitEntry> upcomingHabits,
    required List<_HabitEntry> visibleHabits,
    required bool hasActiveSearchOrFilter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionLabel(
          'Today',
          trailing: _buildViewModeAction(
            label: 'Timeline',
            icon: Icons.timeline_rounded,
          ),
        ),
        if (todayHabits.isNotEmpty)
          ...todayHabits.asMap().entries.map((entry) {
            final index = entry.key;
            final habitEntry = entry.value;
            return _buildHabitTimelineRow(
              entry: habitEntry,
              index: index,
              isFirst: index == 0,
              isLast: index == todayHabits.length - 1,
            );
          })
        else if (!hasActiveSearchOrFilter)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('No habits scheduled for today.'),
          ),
        if (upcomingHabits.isNotEmpty) ...[
          _buildSectionLabel('Upcoming'),
          ...upcomingHabits.asMap().entries.map((entry) {
            final index = entry.key;
            final habitEntry = entry.value;
            return _buildHabitTimelineRow(
              entry: habitEntry,
              index: todayHabits.length + index,
              isFirst: index == 0,
              isLast: index == upcomingHabits.length - 1,
            );
          }),
        ],
        if (visibleHabits.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.search_off),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No habits match your search or filters.',
                        style: AppTypography.bodySmall(context),
                      ),
                    ),
                    TextButton(
                      onPressed: _resetSearchAndFilters,
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 100),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = LogicalDateService.now();

    // Gather all habits from standalone storage
    final List<_HabitEntry> allHabits = _habits.map((habit) {
      return _HabitEntry(
        boardId: habit.boardId ?? '',
        boardTitle: _boardTitle(habit.boardId),
        habit: habit,
      );
    }).toList();
    final filterDate = widget.showCalendarMode ? _selectedCalendarDate : now;
    final visibleHabits = allHabits
        .where(_matchesQuery)
        .where((e) => _matchesFilter(e, filterDate))
        .toList();
    final hasActiveSearchOrFilter =
        _searchQuery.trim().isNotEmpty ||
        _activeFilter != _HabitQuickFilter.all;
    final todayHabits = visibleHabits
        .where((e) => e.habit.isScheduledOnDate(now))
        .toList();
    final upcomingHabits = visibleHabits
        .where((e) => !e.habit.isScheduledOnDate(now))
        .toList();
    final selectedDateHabits = visibleHabits
        .where((e) => e.habit.isScheduledOnDate(_selectedCalendarDate))
        .toList();
    final timedHabits =
        selectedDateHabits.where((e) => _isTimedHabit(e.habit)).toList()..sort(
          (a, b) => (a.habit.startTimeMinutes ?? 0).compareTo(
            b.habit.startTimeMinutes ?? 0,
          ),
        );
    final flexibleHabits = selectedDateHabits
        .where((e) => !_isTimedHabit(e.habit))
        .toList();

    return Stack(
      children: [
        // Main content
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            if (widget.showCalendarMode)
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedBoxHeaderDelegate(
                  minExtentValue: MediaQuery.of(context).viewPadding.top + 6,
                  maxExtentValue: MediaQuery.of(context).viewPadding.top + 6,
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
            // Reward ad card (shown when user needs to watch ads for new habit)
            if (!widget.showCalendarMode &&
                _activeAdSession != null &&
                _shouldShowAds &&
                _adWatchedCount < AdService.requiredAdsPerHabit)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ).copyWith(top: 8),
                  child: RewardAdCard(
                    sessionKey: _activeAdSession!,
                    watchedCount: _adWatchedCount,
                    onAdWatched: _onRewardAdWatched,
                    onAllAdsWatched: _onAllAdsWatched,
                  ),
                ),
              ),
            if (allHabits.isNotEmpty)
              SliverToBoxAdapter(child: _buildPinnedControlsRow()),
            if (allHabits.isNotEmpty && _isFilterExpanded)
              SliverToBoxAdapter(child: _buildFilterStrip()),
            if (allHabits.isNotEmpty)
              SliverToBoxAdapter(child: _buildControlsSummaryRow()),
            if (allHabits.isNotEmpty && widget.showCalendarMode)
              SliverToBoxAdapter(child: _buildTimelineDateHeader()),
            if (allHabits.isNotEmpty &&
                widget.showCalendarMode &&
                _activeAdSession != null &&
                _shouldShowAds &&
                _adWatchedCount < AdService.requiredAdsPerHabit)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ).copyWith(bottom: 6),
                  child: RewardAdCard(
                    sessionKey: _activeAdSession!,
                    watchedCount: _adWatchedCount,
                    onAdWatched: _onRewardAdWatched,
                    onAllAdsWatched: _onAllAdsWatched,
                  ),
                ),
              ),
            if (allHabits.isNotEmpty &&
                widget.showCalendarMode &&
                flexibleHabits.isNotEmpty)
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedBoxHeaderDelegate(
                  minExtentValue: 156,
                  maxExtentValue: 156,
                  child: _buildFlexibleHabitsStickyCarousel(
                    flexibleHabits: flexibleHabits,
                  ),
                ),
              ),
            // Empty state
            if (allHabits.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        size: 64,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No habits yet',
                        style: AppTypography.heading2(
                          context,
                        ).copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to create your first habit\nand build your daily routine',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall(context).copyWith(
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            // Habits content with smooth mode transition
            if (allHabits.isNotEmpty)
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 520),
                  reverseDuration: const Duration(milliseconds: 420),
                  switchInCurve: Curves.easeInOutCubicEmphasized,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    final slide = Tween<Offset>(
                      begin: const Offset(0, 0.035),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: slide, child: child),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      widget.showCalendarMode ? 'calendar-mode' : 'list-mode',
                    ),
                    child: widget.showCalendarMode
                        ? _buildCalendarModeContent(
                            dayHabits: selectedDateHabits,
                            timedHabits: timedHabits,
                            colorScheme: colorScheme,
                          )
                        : _buildDefaultModeContent(
                            todayHabits: todayHabits,
                            upcomingHabits: upcomingHabits,
                            visibleHabits: visibleHabits,
                            hasActiveSearchOrFilter: hasActiveSearchOrFilter,
                          ),
                  ),
                ),
              ),
          ],
        ),
        // Simple confetti burst anchored to the completed card
        if (_confettiOrigin != null)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiOverlay(
                origin: _confettiOrigin,
                particleCount: 12,
                duration: const Duration(milliseconds: 900),
                onComplete: () {
                  if (mounted) setState(() => _confettiOrigin = null);
                },
              ),
            ),
          ),
        // Coin animations (flying coins to header)
        ..._pendingAnimations.asMap().entries.map((entry) {
          final index = entry.key;
          final anim = entry.value;
          return CoinAnimationOverlay(
            key: ValueKey('coin_anim_$index'),
            sourcePosition: anim.source,
            targetPosition: anim.target,
            coinCount: anim.coins,
            onComplete: () => _onAnimationComplete(index),
          );
        }),
      ],
    );
  }
}

class _HabitEntry {
  final String boardId;
  final String boardTitle;
  final HabitItem habit;

  _HabitEntry({
    required this.boardId,
    required this.boardTitle,
    required this.habit,
  });
}

class _PendingCoinAnimation {
  final Offset source;
  final Offset target;
  final int coins;

  _PendingCoinAnimation({
    required this.source,
    required this.target,
    required this.coins,
  });
}

class _FlexibleHabitDragData {
  final HabitItem habit;

  const _FlexibleHabitDragData(this.habit);
}

class _TimelineScheduleSelection {
  final int startMinutes;
  final int durationMinutes;

  const _TimelineScheduleSelection({
    required this.startMinutes,
    required this.durationMinutes,
  });
}

class _TimelineCardLayout {
  final _HabitEntry entry;
  final double top;
  final double height;

  const _TimelineCardLayout({
    required this.entry,
    required this.top,
    required this.height,
  });
}

class _PinnedBoxHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  _PinnedBoxHeaderDelegate({
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.child,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedBoxHeaderDelegate oldDelegate) {
    return minExtentValue != oldDelegate.minExtentValue ||
        maxExtentValue != oldDelegate.maxExtentValue ||
        child != oldDelegate.child;
  }
}

class _MonthWeekScroller extends StatefulWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime today;

  const _MonthWeekScroller({
    required this.selectedDate,
    required this.onDateSelected,
    required this.today,
  });

  @override
  State<_MonthWeekScroller> createState() => _MonthWeekScrollerState();
}

class _MonthWeekScrollerState extends State<_MonthWeekScroller> {
  late PageController _pageController;

  DateTime get _monthStart =>
      DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedWeekIndex());
  }

  @override
  void didUpdateWidget(covariant _MonthWeekScroller oldWidget) {
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
    final totalWeeks = (lastWeekStart.difference(firstWeekStart).inDays ~/ 7) + 1;
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
      if (!widget.selectedDate.isBefore(start) && !widget.selectedDate.isAfter(end)) {
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
        return _MonthWeekRow(
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

class _MonthWeekRow extends StatelessWidget {
  final DateTime weekStart;
  final int month;
  final DateTime selectedDate;
  final DateTime today;
  final ValueChanged<DateTime> onDateSelected;
  final bool Function(DateTime a, DateTime b) sameDay;

  const _MonthWeekRow({
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
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
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
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? colorScheme.onPrimary.withValues(alpha: 0.86)
                          : colorScheme.onSurfaceVariant
                                .withValues(alpha: inMonth ? 1 : 0.55),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${date.day}',
                    style: AppTypography.bodySmall(context).copyWith(
                      fontWeight: FontWeight.w700,
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

class _TimelineCompletionDetailsSheet extends StatelessWidget {
  final HabitItem habit;
  final HabitCompletionFeedback? feedback;

  const _TimelineCompletionDetailsSheet({
    required this.habit,
    required this.feedback,
  });

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
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final mood = feedback?.rating;
    final note = feedback?.note;
    final coins = feedback?.coinsEarned;
    final hasDetails =
        feedback != null &&
        ((mood != null && mood > 0 && _moodData.containsKey(mood)) ||
            (note != null && note.isNotEmpty));

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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.task_alt_rounded,
                    size: 24,
                    color: colorScheme.primary,
                  ),
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
                      horizontal: 10,
                      vertical: 6,
                    ),
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
                    borderRadius: BorderRadius.circular(14),
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
        top: isFirst ? 14 : 0,
        bottom: isLast ? 14 : 0,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Image.asset(
                moodAsset,
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                value,
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(fontWeight: FontWeight.w700, color: valueColor),
              ),
            ],
          ),
          if (!isLast) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
          ],
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
        top: isFirst ? 14 : 0,
        bottom: 14,
      ),
      child: Column(
        children: [
          if (!isFirst) ...[
            Divider(
              height: 1,
              color: colorScheme.outline.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.notes_rounded,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Note',
                      style: AppTypography.bodySmall(
                        context,
                      ).copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note,
                      style: AppTypography.bodySmall(
                        context,
                      ).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget that applies scroll-based micro-animations to list items
class _ScrollAnimatedItem extends StatefulWidget {
  final int index;
  final double scrollOffset;
  final Widget child;

  const _ScrollAnimatedItem({
    required this.index,
    required this.scrollOffset,
    required this.child,
  });

  @override
  State<_ScrollAnimatedItem> createState() => _ScrollAnimatedItemState();
}

class _ScrollAnimatedItemState extends State<_ScrollAnimatedItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _lastScrollOffset = 0;
  bool _isScrollingDown = false;

  // Estimated item height for calculating visibility
  static const double _itemHeight = 80.0;
  static const double _headerHeight = 120.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      value: 1.0,
    );
    _lastScrollOffset = widget.scrollOffset;
  }

  @override
  void didUpdateWidget(_ScrollAnimatedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.scrollOffset != oldWidget.scrollOffset) {
      final delta = widget.scrollOffset - _lastScrollOffset;
      final isScrollingNow = delta.abs() > 0.5;

      if (isScrollingNow) {
        _isScrollingDown = delta > 0;

        // Calculate velocity-based scale
        final velocity = delta.abs().clamp(0.0, 30.0) / 30.0;
        final targetScale = 1.0 - (velocity * 0.03); // Max 3% scale reduction

        // Apply subtle tilt based on scroll direction and item position
        if (!_controller.isAnimating) {
          _controller.value = targetScale;
        }
      } else if (_controller.value < 1.0) {
        // Spring back to normal when scrolling stops
        _controller.animateTo(
          1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
        );
      }

      _lastScrollOffset = widget.scrollOffset;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = _controller.value;

        // Calculate subtle rotation based on position and scroll direction
        final rotationFactor = _isScrollingDown ? 0.003 : -0.003;
        final rotation = (1.0 - scale) * rotationFactor * 10;

        // Subtle horizontal offset for parallax effect
        final horizontalOffset =
            (1.0 - scale) * (_isScrollingDown ? 2.0 : -2.0);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateX(rotation)
            ..scale(scale)
            ..translate(horizontalOffset, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Tracks which gesture the user initiated during a drag.
enum _DragMode { reveal, flip }

/// Swipeable wrapper for habit cards:
/// - Swipe left from main face → reveal edit & delete action icons
/// - Swipe right from main face → 3D card-flip to coping plan
/// - Swipe left from coping plan face → flip back to main
class _SwipeableHabitCard extends StatefulWidget {
  final _HabitEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  const _SwipeableHabitCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  @override
  State<_SwipeableHabitCard> createState() => _SwipeableHabitCardState();
}

class _SwipeableHabitCardState extends State<_SwipeableHabitCard>
    with TickerProviderStateMixin {
  // --- Reveal (swipe-left) animation ---
  late AnimationController _revealController;
  late Animation<double> _revealAnimation;
  double _dragExtent = 0;
  bool _isRevealOpen = false;

  // --- Flip animation ---
  late AnimationController _flipController;
  bool _isFlipped = false;

  /// Whether the card is currently showing the coping plan (back) face.
  bool get isFlipped => _isFlipped;

  /// Toggle the card flip from outside (e.g. icon tap).
  void toggleFlip() {
    if (_isFlipped) {
      _flipToFront();
    } else {
      _flipToBack();
    }
  }

  // --- Gesture routing ---
  _DragMode? _dragMode;

  static const double _revealWidth = 120.0;
  static const double _snapThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _revealAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
    );
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _revealController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  // ---- Reveal helpers ----

  void _animateRevealTo(double target) {
    _revealAnimation = Tween<double>(begin: _dragExtent, end: target).animate(
      CurvedAnimation(parent: _revealController, curve: Curves.easeOutCubic),
    );
    _revealController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _dragExtent = target;
          _isRevealOpen = target != 0;
        });
      }
    });
  }

  void _closeReveal() {
    if (_dragExtent != 0) _animateRevealTo(0);
  }

  // ---- Flip helpers ----

  void _flipToBack() {
    HapticFeedback.selectionClick();
    _flipController.forward().then((_) {
      if (mounted) setState(() => _isFlipped = true);
    });
  }

  void _flipToFront() {
    HapticFeedback.selectionClick();
    _flipController.reverse().then((_) {
      if (mounted) setState(() => _isFlipped = false);
    });
  }

  // ---- Unified drag handling ----

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final dx = details.delta.dx;

    if (_dragMode == null) {
      if (_isFlipped) {
        if (dx < 0) _dragMode = _DragMode.flip;
      } else if (_isRevealOpen) {
        _dragMode = _DragMode.reveal;
      } else {
        if (dx > 0) {
          _dragMode = _DragMode.flip;
        } else if (dx < 0) {
          _dragMode = _DragMode.reveal;
        }
      }
    }

    if (_dragMode == _DragMode.reveal && !_isFlipped) {
      setState(() {
        _dragExtent += dx;
        _dragExtent = _dragExtent.clamp(-_revealWidth, 0);
      });
    } else if (_dragMode == _DragMode.flip) {
      final flipDelta = dx / 200.0;
      final newVal = (_flipController.value + flipDelta).clamp(0.0, 1.0);
      _flipController.value = newVal;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (_dragMode == _DragMode.reveal && !_isFlipped) {
      if (velocity < -300 || _dragExtent.abs() > _snapThreshold) {
        _animateRevealTo(-_revealWidth);
      } else {
        _animateRevealTo(0);
      }
    } else if (_dragMode == _DragMode.flip) {
      if (_isFlipped) {
        if (velocity < -300 || _flipController.value < 0.5) {
          _flipToFront();
        } else {
          _flipToBack();
        }
      } else {
        if (velocity > 300 || _flipController.value > 0.5) {
          _flipToBack();
        } else {
          _flipToFront();
        }
      }
    }

    _dragMode = null;
  }

  void _onEditTap() {
    HapticFeedback.mediumImpact();
    _closeReveal();
    widget.onEdit();
  }

  void _onDeleteTap() {
    HapticFeedback.mediumImpact();
    _closeReveal();
    widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_revealController, _flipController]),
      builder: (context, _) {
        final revealOffset = _revealController.isAnimating
            ? _revealAnimation.value
            : _dragExtent;
        final revealProgress = (revealOffset.abs() / _revealWidth).clamp(
          0.0,
          1.0,
        );
        final flipValue = _flipController.value;
        final showBack = flipValue >= 0.5;

        // 3D Y-axis rotation
        final angle = flipValue * pi;
        final flipTransform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle);

        // Mirror-correct the back face so text isn't reversed
        if (showBack) {
          flipTransform.rotateY(pi);
        }

        return Stack(
          children: [
            // Action buttons revealed on the right (only visible on front face)
            if (!showBack)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Spacer(),
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 100),
                          opacity: revealProgress.clamp(0.0, 1.0),
                          child: SizedBox(
                            width: _revealWidth,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Edit button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _onEditTap,
                                    child: Container(
                                      color: isDark
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.primary.withValues(
                                              alpha: 0.85,
                                            ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.edit_outlined,
                                        color: colorScheme.onPrimary,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                                // Delete button
                                Expanded(
                                  child: GestureDetector(
                                    onTap: _onDeleteTap,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: colorScheme.error,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(24),
                                          bottomRight: Radius.circular(24),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: colorScheme.onPrimary,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Flippable card with optional reveal translate
            GestureDetector(
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onTap: _isRevealOpen
                  ? _closeReveal
                  : (_isFlipped ? _flipToFront : null),
              child: Transform.translate(
                offset: Offset(showBack ? 0 : revealOffset, 0),
                child: Transform(
                  alignment: Alignment.center,
                  transform: flipTransform,
                  child: showBack
                      ? _CopingPlanFace(
                          habit: widget.entry.habit,
                          isCompleted: widget.entry.habit
                              .isCompletedForCurrentPeriod(
                                LogicalDateService.now(),
                              ),
                        )
                      : widget.child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Coping plan back face
// =============================================================================

/// Back face of the flippable habit card showing the IF/THEN coping plan.
class _CopingPlanFace extends StatelessWidget {
  final HabitItem habit;
  final bool isCompleted;

  const _CopingPlanFace({required this.habit, this.isCompleted = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cbt = habit.cbtEnhancements;
    final hasContent =
        cbt != null &&
        ((cbt.predictedObstacle?.isNotEmpty ?? false) ||
            (cbt.ifThenPlan?.isNotEmpty ?? false));

    final textColor = colorScheme.onSurface;
    final subtitleColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.6)
        : colorScheme.onSurfaceVariant;
    final accentColor = AppColors.completedOrange;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.7),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: hasContent
                ? Row(
                    children: [
                      // Coping plan icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.25 : 0.12,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.psychology_rounded,
                          color: accentColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // IF trigger
                            if (cbt.predictedObstacle?.isNotEmpty ?? false) ...[
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.error.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'IF',
                                      style: AppTypography.caption(context)
                                          .copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.error,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      cbt.predictedObstacle!,
                                      style: AppTypography.bodySmall(context)
                                          .copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isCompleted
                                                ? textColor.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : textColor,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationColor: isCompleted
                                                ? textColor.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : null,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            // THEN action
                            if (cbt.ifThenPlan?.isNotEmpty ?? false)
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'THEN',
                                      style: AppTypography.caption(context)
                                          .copyWith(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: colorScheme.primary,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      cbt.ifThenPlan!,
                                      style: AppTypography.bodySmall(context)
                                          .copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isCompleted
                                                ? textColor.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : textColor,
                                            decoration: isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                            decorationColor: isCompleted
                                                ? textColor.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : null,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      // Micro version / reward chips
                      if (cbt.microVersion?.isNotEmpty ?? false) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Micro',
                            style: AppTypography.caption(context).copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Icon(
                        Icons.psychology_outlined,
                        color: subtitleColor,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'No coping plan set',
                        style: AppTypography.bodySmall(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Timeline widgets
// =============================================================================

/// Checkpoint circle for the timeline — orange with checkmark when completed,
/// grey outline when incomplete.
class _TimelineCheckpoint extends StatelessWidget {
  final bool isCompleted;
  final VoidCallback? onTap;
  const _TimelineCheckpoint({required this.isCompleted, this.onTap});

  static const _completedColor = AppColors.completedOrange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.3)
        : colorScheme.outline;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted ? _completedColor : Colors.transparent,
          border: Border.all(
            color: isCompleted ? _completedColor : borderColor,
            width: isCompleted ? 0 : 1.5,
          ),
        ),
        child: isCompleted
            ? Icon(Icons.check_rounded, color: colorScheme.onPrimary, size: 16)
            : null,
      ),
    );
  }
}

/// Vertical dashed line segment for the timeline.
class _TimelineDash extends StatelessWidget {
  const _TimelineDash();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? colorScheme.onSurface.withValues(alpha: 0.15)
        : colorScheme.outline;

    return SizedBox(
      width: 2,
      child: CustomPaint(
        painter: _DashedLinePainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Paints a vertical dashed line.
class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashHeight = 4.0;
    const gapHeight = 4.0;
    final centerX = size.width / 2;
    double y = 0;

    while (y < size.height) {
      canvas.drawLine(
        Offset(centerX, y),
        Offset(centerX, (y + dashHeight).clamp(0, size.height)),
        paint,
      );
      y += dashHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
