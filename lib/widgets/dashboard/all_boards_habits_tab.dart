import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../utils/app_colors.dart';
import '../../screens/habit_timer_screen.dart';
import '../rituals/add_habit_modal.dart';
import '../rituals/daily_progress_header.dart';
import '../rituals/coin_animation_overlay.dart';
import '../rituals/animated_habit_card.dart';
import '../rituals/habit_completion_sheet.dart';
import '../routine/confetti_overlay.dart';

class AllBoardsHabitsTab extends StatefulWidget {
  final List<VisionBoardInfo> boards;
  final Map<String, List<VisionComponent>> componentsByBoardId;
  final Future<void> Function(String boardId, List<VisionComponent> updated) onSaveBoardComponents;
  final ValueNotifier<int>? coinNotifier;
  final GlobalKey? coinTargetKey;

  const AllBoardsHabitsTab({
    super.key,
    required this.boards,
    required this.componentsByBoardId,
    required this.onSaveBoardComponents,
    this.coinNotifier,
    this.coinTargetKey,
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
  double _scrollOffset = 0;
  Offset? _confettiOrigin;

  @override
  void initState() {
    super.initState();
    _localComponents = Map.from(widget.componentsByBoardId);
    _scrollController.addListener(_onScroll);
    _loadHabits();
  }

  Future<void> _loadHabits() async {
    final habits = await HabitStorageService.loadAll();
    if (mounted) setState(() => _habits = habits);
  }
  
  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  void didUpdateWidget(AllBoardsHabitsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.componentsByBoardId != oldWidget.componentsByBoardId) {
      if (_isSaving) return;
      _localComponents = Map.from(widget.componentsByBoardId);
      _loadHabits();
    }
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  static String _toIsoDate(DateTime d) => LogicalDateService.toIsoDate(d);

  String _boardTitle(String? boardId) {
    if (boardId == null) return '';
    return widget.boards
        .cast<VisionBoardInfo?>()
        .firstWhere((b) => b?.id == boardId, orElse: () => null)
        ?.title ?? '';
  }

  Future<void> _addHabitGlobal() async {
    final req = await showAddHabitModal(
      context,
      existingHabits: _habits,
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
      iconIndex: req.iconIndex,
      completedDates: const [],
      actionSteps: req.actionSteps,
      startTimeMinutes: req.startTimeMinutes,
    );

    await HabitStorageService.addHabit(newHabit);
    await _loadHabits();

    Future<void>(() async {
      if (!NotificationsService.shouldSchedule(newHabit)) return;
      final ok = await NotificationsService.requestPermissionsIfNeeded();
      if (!ok) return;
      await NotificationsService.scheduleHabitReminders(newHabit);
    });
  }

  Future<void> _handleHabitTap({
    required HabitItem habit,
    required GlobalKey cardKey,
    required bool isFlipped,
  }) async {
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return;
    
    final isCompleted = habit.isCompletedForCurrentPeriod(now);
    
    if (isCompleted) {
      await _toggleHabit(
        habit: habit,
        wasCompleted: true,
      );
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
      final RenderBox? cardBox = cardKey.currentContext?.findRenderObject() as RenderBox?;
      final RenderBox? targetBox = widget.coinTargetKey?.currentContext?.findRenderObject() as RenderBox?;
      
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
        _pendingAnimations.add(_PendingCoinAnimation(
          source: cardPosition,
          target: targetPosition,
          coins: earnedCoins,
        ));
      }

      final feedback = HabitCompletionFeedback(
        rating: result.mood ?? 0,
        note: result.note,
        coinsEarned: earnedCoins,
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
      final updatedFeedback =
          Map<String, HabitCompletionFeedback>.from(toggled.feedbackByDate);
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
            .map((id) => habit.actionSteps
                .where((s) => s.id == id)
                .map((s) => s.title)
                .firstOrNull)
            .whereType<String>()
            .toList();
        stepsText = 'Steps: $done/$total completed';
        if (stepNames.isNotEmpty) {
          stepsText += ' — ${stepNames.join(', ')}';
        }
      }

      final noteText = (feedback.note ?? '').trim();
      final dayLog = [moodText, stepsText, noteText]
          .where((s) => s.isNotEmpty)
          .join('\n');
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
      final components = _localComponents[habit.boardId!] ?? const <VisionComponent>[];
      if (components.isNotEmpty && habit.componentId != null) {
        final comp = components.cast<VisionComponent?>().firstWhere(
          (c) => c?.id == habit.componentId, orElse: () => null);
        if (comp != null) {
          final updatedHabits = comp.habits.map((h) => h.id == habit.id ? toggled : h).toList();
          final updatedComponent = comp.copyWithCommon(habits: updatedHabits);
          final updatedComponents = components.map((c) => c.id == comp.id ? updatedComponent : c).toList();
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
      final coinsToDeduct = savedFeedback?.coinsEarned ?? CoinsService.habitCompletionCoins;
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
    if (habit.timeBound?.enabled != true && habit.locationBound?.enabled != true) return;

    Future<void> onMarkCompleted() async {
      final latestHabit = _habits
          .where((h) => h.id == habit.id)
          .cast<HabitItem?>()
          .firstWhere((_) => true, orElse: () => null);
      if (latestHabit == null) return;
      final now2 = LogicalDateService.now();
      if (!latestHabit.isScheduledOnDate(now2)) return;
      if (latestHabit.isCompletedForCurrentPeriod(now2)) return;
      await _toggleHabit(
        habit: latestHabit,
        wasCompleted: false,
        completionType: CompletionType.habit,
        coinsEarned: CoinsService.habitCompletionCoins,
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HabitTimerScreen(
          habit: habit,
          onMarkCompleted: onMarkCompleted,
        ),
      ),
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
      locationBound: req.locationBound,
      chaining: req.chaining,
      cbtEnhancements: req.cbtEnhancements,
      iconIndex: req.iconIndex,
      actionSteps: req.actionSteps,
      startTimeMinutes: req.startTimeMinutes,
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
        content: Text('Are you sure you want to delete "${entry.habit.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await HabitStorageService.deleteHabit(entry.habit.id);
    await _loadHabits();

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

    // Calculate progress stats for today
    final scheduledToday = allHabits.where((e) => e.habit.isScheduledOnDate(now)).toList();
    final completedToday = scheduledToday.where((e) => e.habit.isCompletedForCurrentPeriod(now)).length;
    final totalScheduledToday = scheduledToday.length;

    // Best current streak across all habits
    int bestStreak = 0;
    for (final e in allHabits) {
      final s = e.habit.currentStreak;
      if (s > bestStreak) bestStreak = s;
    }

    return Stack(
      children: [
        // Main content
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Progress header
            SliverToBoxAdapter(
              child: DailyProgressHeader(
                completedCount: completedToday,
                totalCount: totalScheduledToday,
                bestStreak: bestStreak,
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
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No rituals yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add habits to start building\nyour daily rituals',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
              ),
            // Habits list with timeline
            if (allHabits.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = allHabits[index];
                      final now = LogicalDateService.now();
                      final scheduledToday = entry.habit.isScheduledOnDate(now);
                      final isCompleted = scheduledToday && 
                          entry.habit.isCompletedForCurrentPeriod(now);
                      final swipeKey = _swipeKeys.putIfAbsent(
                        entry.habit.id,
                        () => GlobalKey<_SwipeableHabitCardState>(),
                      );
                      final isFirst = index == 0;
                      final isLast = index == allHabits.length - 1;
                      
                      return _ScrollAnimatedItem(
                        index: index,
                        scrollOffset: _scrollOffset,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Timeline column
                                SizedBox(
                                  width: 40,
                                  child: Column(
                                    children: [
                                      // Top dashed line
                                      Expanded(
                                        child: isFirst
                                            ? const SizedBox()
                                            : const _TimelineDash(),
                                      ),
                                      // Checkpoint circle — opens completion sheet
                                      _TimelineCheckpoint(
                                        isCompleted: isCompleted,
                                        onTap: () => _handleHabitTap(
                                          habit: entry.habit,
                                          cardKey: swipeKey,
                                          isFlipped: swipeKey.currentState?.isFlipped ?? false,
                                        ),
                                      ),
                                      // Bottom dashed line
                                      Expanded(
                                        child: isLast
                                            ? const SizedBox()
                                            : const _TimelineDash(),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Card
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
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: allHabits.length,
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
        // FAB
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.of(context).viewPadding.bottom,
          child: FloatingActionButton(
            onPressed: _addHabitGlobal,
            tooltip: 'Add habit',
            child: const Icon(Icons.add),
          ),
        ),
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
        final horizontalOffset = (1.0 - scale) * (_isScrollingDown ? 2.0 : -2.0);
        
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
        final revealProgress =
            (revealOffset.abs() / _revealWidth).clamp(0.0, 1.0);
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
                                          ? Colors.blueGrey.shade700
                                          : colorScheme.primary
                                              .withValues(alpha: 0.85),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white,
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
                                        color: Colors.red.shade600,
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(24),
                                          bottomRight: Radius.circular(24),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.white,
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
                          isCompleted: widget.entry.habit.isCompletedForCurrentPeriod(
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
    final hasContent = cbt != null &&
        ((cbt.predictedObstacle?.isNotEmpty ?? false) ||
            (cbt.ifThenPlan?.isNotEmpty ?? false));

    final textColor = isDark ? Colors.white : AppColors.nearBlack;
    final subtitleColor =
        isDark ? Colors.white.withValues(alpha: 0.6) : AppColors.dimGrey;
    final accentColor = AppColors.completedOrange;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
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
                    color: accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
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
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'IF',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.red.shade400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cbt.predictedObstacle!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isCompleted
                                      ? textColor.withValues(alpha: 0.5)
                                      : textColor,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: isCompleted
                                      ? textColor.withValues(alpha: 0.5)
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
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'THEN',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green.shade400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                cbt.ifThenPlan!,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isCompleted
                                      ? textColor.withValues(alpha: 0.5)
                                      : textColor,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: isCompleted
                                      ? textColor.withValues(alpha: 0.5)
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Micro',
                      style: TextStyle(
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.3)
        : Colors.grey.shade400;

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
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade300;

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
