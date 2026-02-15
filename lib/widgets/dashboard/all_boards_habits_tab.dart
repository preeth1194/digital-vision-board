import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/habit_item.dart';
import '../../models/vision_board_info.dart';
import '../../models/vision_components.dart';
import '../../services/notifications_service.dart';
import '../../services/logical_date_service.dart';
import '../../services/sync_service.dart';
import '../../services/coins_service.dart';
import '../../screens/habit_timer_screen.dart';
import '../../screens/rhythmic_timer_screen.dart';
import '../../services/habit_geofence_tracking_service.dart';
import '../dialogs/goal_picker_sheet.dart';
import '../rituals/add_habit_modal.dart';
import '../rituals/coins_header.dart';
import '../rituals/coin_animation_overlay.dart';
import '../rituals/animated_habit_card.dart';
import '../rituals/habit_completion_sheet.dart';
import '../rituals/lottie_coin_overlay.dart';

class AllBoardsHabitsTab extends StatefulWidget {
  final List<VisionBoardInfo> boards;
  final Map<String, List<VisionComponent>> componentsByBoardId;
  final Future<void> Function(String boardId, List<VisionComponent> updated) onSaveBoardComponents;

  const AllBoardsHabitsTab({
    super.key,
    required this.boards,
    required this.componentsByBoardId,
    required this.onSaveBoardComponents,
  });

  @override
  State<AllBoardsHabitsTab> createState() => _AllBoardsHabitsTabState();
}

class _AllBoardsHabitsTabState extends State<AllBoardsHabitsTab> {
  int _totalCoins = 0;
  final GlobalKey _coinTargetKey = GlobalKey();
  final List<_PendingCoinAnimation> _pendingAnimations = [];
  late Map<String, List<VisionComponent>> _localComponents;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _localComponents = Map.from(widget.componentsByBoardId);
    _loadCoins();
    _scrollController.addListener(_onScroll);
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
      _localComponents = Map.from(widget.componentsByBoardId);
    }
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCoins() async {
    final coins = await CoinsService.getTotalCoins();
    if (mounted) setState(() => _totalCoins = coins);
  }

  static String _toIsoDate(DateTime d) => LogicalDateService.toIsoDate(d);

  Future<VisionBoardInfo?> _pickBoard() async {
    if (widget.boards.isEmpty) return null;
    return showModalBottomSheet<VisionBoardInfo?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.boards.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final b = widget.boards[i];
            return ListTile(
              title: Text(b.title),
              onTap: () => Navigator.of(ctx).pop(b),
            );
          },
        ),
      ),
    );
  }

  Future<void> _addHabitGlobal() async {
    if (widget.boards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a vision board first to add habits'),
        ),
      );
      return;
    }
    final board = await _pickBoard();
    if (board == null) return;
    final components = _localComponents[board.id] ?? const <VisionComponent>[];
    if (components.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add goals to "${board.title}" first'),
        ),
      );
      return;
    }
    if (!mounted) return;
    final selected = await showGoalPickerSheet(
      context,
      components: components,
      title: 'Select goal for habit',
    );
    if (selected == null) return;
    if (!mounted) return;
    final req = await showAddHabitModal(
      // ignore: use_build_context_synchronously
      context,
      existingHabits: selected.habits,
    );
    if (req == null) return;

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
      completedDates: const [],
    );

    final nextComponents = components.map((c) {
      if (c.id != selected.id) return c;
      return c.copyWithCommon(habits: [...c.habits, newHabit]);
    }).toList();

    await widget.onSaveBoardComponents(board.id, nextComponents);
    setState(() => _localComponents[board.id] = nextComponents);

    Future<void>(() async {
      await HabitGeofenceTrackingService.instance.configureForComponent(
        boardId: board.id,
        componentId: selected.id,
        habits: nextComponents.where((c) => c.id == selected.id).first.habits,
      );
    });

    Future<void>(() async {
      if (!newHabit.reminderEnabled || newHabit.reminderMinutes == null) return;
      final ok = await NotificationsService.requestPermissionsIfNeeded();
      if (!ok) return;
      await NotificationsService.scheduleHabitReminders(newHabit);
    });
  }

  Future<void> _handleHabitTap({
    required String boardId,
    required String boardTitle,
    required List<VisionComponent> components,
    required VisionComponent component,
    required HabitItem habit,
    required GlobalKey cardKey,
  }) async {
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return;
    
    final isCompleted = habit.isCompletedForCurrentPeriod(now);
    
    if (isCompleted) {
      // Uncomplete the habit
      await _toggleHabit(
        boardId: boardId,
        boardTitle: boardTitle,
        components: components,
        component: component,
        habit: habit,
        wasCompleted: true,
      );
    } else {
      // Show completion sheet
      final result = await showHabitCompletionSheet(context, habit: habit);
      if (result == null) return;
      
      // Get card position for coin flying animation (after Lottie)
      final RenderBox? cardBox = cardKey.currentContext?.findRenderObject() as RenderBox?;
      final RenderBox? targetBox = _coinTargetKey.currentContext?.findRenderObject() as RenderBox?;
      
      Offset? cardPosition;
      Offset? targetPosition;
      
      if (cardBox != null && targetBox != null) {
        cardPosition = cardBox.localToGlobal(
          Offset(cardBox.size.width / 2, cardBox.size.height / 2),
        );
        targetPosition = targetBox.localToGlobal(
          Offset(targetBox.size.width / 2, targetBox.size.height / 2),
        );
      }
      
      // Show fullscreen Lottie animation (covers app bar and bottom nav)
      if (!mounted) return;
      await showLottieCoinOverlay(
        // ignore: use_build_context_synchronously
        context,
        coinsEarned: result.coinsEarned,
        totalCoins: _totalCoins + result.coinsEarned,
        onComplete: () {
          // Add flying coin animation after Lottie completes
          if (cardPosition != null && targetPosition != null) {
            setState(() {
              _pendingAnimations.add(_PendingCoinAnimation(
                source: cardPosition!,
                target: targetPosition!,
                coins: result.coinsEarned,
              ));
            });
          }
        },
      );
      
      // Complete the habit after overlay is dismissed
      if (!mounted) return;
      await _toggleHabit(
        boardId: boardId,
        boardTitle: boardTitle,
        components: components,
        component: component,
        habit: habit,
        wasCompleted: false,
        completionType: result.completionType,
        coinsEarned: result.coinsEarned,
      );
    }
  }

  Future<void> _toggleHabit({
    required String boardId,
    required String boardTitle,
    required List<VisionComponent> components,
    required VisionComponent component,
    required HabitItem habit,
    required bool wasCompleted,
    CompletionType? completionType,
    int? coinsEarned,
  }) async {
    final now = LogicalDateService.now();
    final toggled = habit.toggleForDate(now);
    final updatedHabits = component.habits.map((h) => h.id == habit.id ? toggled : h).toList();
    final updatedComponent = component.copyWithCommon(habits: updatedHabits);
    final updatedComponents = components.map((c) => c.id == component.id ? updatedComponent : c).toList();
    
    await widget.onSaveBoardComponents(boardId, updatedComponents);
    setState(() {
      _localComponents[boardId] = updatedComponents;
    });

    // Sync
    final iso = _toIsoDate(now);
    Future<void>(() async {
      await SyncService.enqueueHabitCompletion(
        boardId: boardId,
        componentId: component.id,
        habitId: habit.id,
        logicalDate: iso,
        deleted: wasCompleted,
      );
    });

    // Award coins on completion, or deduct on uncheck
    if (!wasCompleted && coinsEarned != null && coinsEarned > 0) {
      final newTotal = await CoinsService.addCoins(coinsEarned);
      
      // Check for streak bonus
      final streakBonus = await CoinsService.checkAndAwardStreakBonus(
        habit.id,
        toggled.currentStreak,
      );
      
      if (mounted) {
        setState(() => _totalCoins = streakBonus ?? newTotal);
        
        HapticFeedback.heavyImpact();
        
        if (streakBonus != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.celebration, color: Color(0xFFFFD700)),
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
      // Deduct coins when unchecking a habit
      final coinsToDeduct = CoinsService.habitCompletionCoins;
      final newTotal = await CoinsService.addCoins(-coinsToDeduct);
      
      if (mounted) {
        setState(() => _totalCoins = newTotal < 0 ? 0 : newTotal);
        HapticFeedback.lightImpact();
      }
    }
  }

  Future<void> _editHabit(_HabitEntry entry) async {
    // Collect all existing habits for duplicate check
    final allHabits = <HabitItem>[];
    for (final components in _localComponents.values) {
      for (final comp in components) {
        allHabits.addAll(comp.habits);
      }
    }

    final req = await showAddHabitModal(
      context,
      existingHabits: allHabits,
      initialHabit: entry.habit,
    );
    if (req == null || !mounted) return;

    final updatedHabit = entry.habit.copyWith(
      name: req.name,
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
    );

    final updatedHabits = entry.component.habits
        .map((h) => h.id == entry.habit.id ? updatedHabit : h)
        .toList();
    final updatedComponent = entry.component.copyWithCommon(habits: updatedHabits);
    final updatedComponents = entry.components
        .map((c) => c.id == entry.component.id ? updatedComponent : c)
        .toList();

    await widget.onSaveBoardComponents(entry.boardId, updatedComponents);
    setState(() {
      _localComponents[entry.boardId] = updatedComponents;
    });

    // Update notifications if needed
    if (updatedHabit.reminderEnabled) {
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

    final updatedHabits = entry.component.habits
        .where((h) => h.id != entry.habit.id)
        .toList();
    final updatedComponent = entry.component.copyWithCommon(habits: updatedHabits);
    final updatedComponents = entry.components
        .map((c) => c.id == entry.component.id ? updatedComponent : c)
        .toList();

    await widget.onSaveBoardComponents(entry.boardId, updatedComponents);
    setState(() {
      _localComponents[entry.boardId] = updatedComponents;
    });

    // Cancel any scheduled notifications for this habit
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
    _loadCoins(); // Refresh coin count after animation
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = LogicalDateService.now();
    
    // Gather all habits across all boards
    final List<_HabitEntry> allHabits = [];
    for (final board in widget.boards) {
      final components = _localComponents[board.id] ?? const <VisionComponent>[];
      for (final component in components) {
        for (final habit in component.habits) {
          allHabits.add(_HabitEntry(
            boardId: board.id,
            boardTitle: board.title,
            components: components,
            component: component,
            habit: habit,
          ));
        }
      }
    }

    // Calculate progress stats for today
    final scheduledToday = allHabits.where((e) => e.habit.isScheduledOnDate(now)).toList();
    final completedToday = scheduledToday.where((e) => e.habit.isCompletedForCurrentPeriod(now)).length;
    final totalScheduledToday = scheduledToday.length;

    return Stack(
      children: [
        // Main content
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // Coins header with progress
            SliverToBoxAdapter(
              child: CoinsHeader(
                totalCoins: _totalCoins,
                coinTargetKey: _coinTargetKey,
                completedCount: completedToday,
                totalCount: totalScheduledToday,
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
            // Habits list
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
                      final cardKey = GlobalKey();
                      
                      return _ScrollAnimatedItem(
                        index: index,
                        scrollOffset: _scrollOffset,
                        child: _SwipeableHabitCard(
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
                            onTap: () => _handleHabitTap(
                              boardId: entry.boardId,
                              boardTitle: entry.boardTitle,
                              components: entry.components,
                              component: entry.component,
                              habit: entry.habit,
                              cardKey: cardKey,
                            ),
                            onLongPress: () {
                              // Navigate to timer if applicable
                              final habit = entry.habit;
                              if (habit.timeBound?.enabled == true || 
                                  habit.locationBound?.enabled == true) {
                                final isSongBased = habit.timeBound?.isSongBased ?? false;
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => isSongBased
                                        ? RhythmicTimerScreen(
                                            habit: habit,
                                            onMarkCompleted: () async {
                                              final latestComponents = 
                                                  _localComponents[entry.boardId] ?? 
                                                  const <VisionComponent>[];
                                              final latestComponent = latestComponents
                                                  .where((c) => c.id == entry.component.id)
                                                  .cast<VisionComponent?>()
                                                  .firstWhere((_) => true, orElse: () => null);
                                              if (latestComponent == null) return;
                                              final latestHabit = latestComponent.habits
                                                  .where((h) => h.id == habit.id)
                                                  .cast<HabitItem?>()
                                                  .firstWhere((_) => true, orElse: () => null);
                                              if (latestHabit == null) return;
                                              final now2 = LogicalDateService.now();
                                              if (!latestHabit.isScheduledOnDate(now2)) return;
                                              if (latestHabit.isCompletedForCurrentPeriod(now2)) return;
                                              await _toggleHabit(
                                                boardId: entry.boardId,
                                                boardTitle: entry.boardTitle,
                                                components: latestComponents,
                                                component: latestComponent,
                                                habit: latestHabit,
                                                wasCompleted: false,
                                                completionType: CompletionType.habit,
                                                coinsEarned: CoinsService.habitCompletionCoins,
                                              );
                                            },
                                          )
                                        : HabitTimerScreen(
                                            habit: habit,
                                            onMarkCompleted: () async {
                                              final latestComponents = 
                                                  _localComponents[entry.boardId] ?? 
                                                  const <VisionComponent>[];
                                              final latestComponent = latestComponents
                                                  .where((c) => c.id == entry.component.id)
                                                  .cast<VisionComponent?>()
                                                  .firstWhere((_) => true, orElse: () => null);
                                              if (latestComponent == null) return;
                                              final latestHabit = latestComponent.habits
                                                  .where((h) => h.id == habit.id)
                                                  .cast<HabitItem?>()
                                                  .firstWhere((_) => true, orElse: () => null);
                                              if (latestHabit == null) return;
                                              final now2 = LogicalDateService.now();
                                              if (!latestHabit.isScheduledOnDate(now2)) return;
                                              if (latestHabit.isCompletedForCurrentPeriod(now2)) return;
                                              await _toggleHabit(
                                                boardId: entry.boardId,
                                                boardTitle: entry.boardTitle,
                                                components: latestComponents,
                                                component: latestComponent,
                                                habit: latestHabit,
                                                wasCompleted: false,
                                                completionType: CompletionType.habit,
                                                coinsEarned: CoinsService.habitCompletionCoins,
                                              );
                                            },
                                          ),
                                  ),
                                );
                              }
                            },
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
  final List<VisionComponent> components;
  final VisionComponent component;
  final HabitItem habit;

  _HabitEntry({
    required this.boardId,
    required this.boardTitle,
    required this.components,
    required this.component,
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

/// Swipeable wrapper for habit cards with edit (left swipe) and delete (right swipe) actions
class _SwipeableHabitCard extends StatefulWidget {
  final _HabitEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  const _SwipeableHabitCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });

  @override
  State<_SwipeableHabitCard> createState() => _SwipeableHabitCardState();
}

class _SwipeableHabitCardState extends State<_SwipeableHabitCard> {
  double _dragExtent = 0;
  static const double _actionThreshold = 80;
  static const double _maxDrag = 100;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.delta.dx;
      _dragExtent = _dragExtent.clamp(-_maxDrag, _maxDrag);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() >= _actionThreshold) {
      if (_dragExtent > 0) {
        // Swiped right - Delete
        HapticFeedback.mediumImpact();
        widget.onDelete();
      } else {
        // Swiped left - Edit
        HapticFeedback.mediumImpact();
        widget.onEdit();
      }
    }
    // Reset position
    setState(() {
      _dragExtent = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent.abs() / _actionThreshold).clamp(0.0, 1.0);
    final isRightSwipe = _dragExtent > 0;

    return Stack(
      children: [
        // Background action indicators
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  // Delete action (right swipe reveals left side)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: isRightSwipe ? progress : 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 150),
                          scale: isRightSwipe ? 0.8 + (progress * 0.2) : 0.8,
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Edit action (left swipe reveals right side)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade600,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 150),
                        opacity: !isRightSwipe && _dragExtent != 0 ? progress : 0,
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 150),
                          scale: !isRightSwipe ? 0.8 + (progress * 0.2) : 0.8,
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Draggable card
        GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: AnimatedContainer(
            duration: _dragExtent == 0
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(_dragExtent, 0, 0),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
