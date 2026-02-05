import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine.dart';
import '../models/routine_todo_item.dart';
import '../services/routine_storage_service.dart';
import '../services/logical_date_service.dart';
import '../services/icon_service.dart';
import '../utils/app_typography.dart';
import '../widgets/circular_countdown_timer.dart';
import '../widgets/routine/confetti_overlay.dart';

class RoutineTimerScreen extends StatefulWidget {
  final Routine routine;
  final VoidCallback? onComplete;

  const RoutineTimerScreen({
    super.key,
    required this.routine,
    this.onComplete,
  });

  @override
  State<RoutineTimerScreen> createState() => _RoutineTimerScreenState();
}

class _RoutineTimerScreenState extends State<RoutineTimerScreen> {
  SharedPreferences? _prefs;
  bool _loading = true;
  late Routine _routine;
  int _currentTodoIndex = 0;

  late PageController _pageController;

  Timer? _tick;
  int _elapsedMs = 0;
  bool _running = false;
  bool _completionTriggered = false;

  final Map<int, int> _elapsedMsByIndex = {};
  int? _perTodoRunningIndex;
  Timer? _perTodoTick;

  // Celebration animation state
  bool _showCelebration = false;
  String? _celebratingTodoId;

  DateTime get _today => LogicalDateService.today();

  bool get _hasOverallTimer =>
      _routine.timeMode == 'overall' &&
      _routine.overallDurationMinutes != null &&
      _routine.overallDurationMinutes! > 0;

  int get _overallTargetMs =>
      (_routine.overallDurationMinutes ?? 0) * 60 * 1000;

  RoutineTodoItem? get _currentTodo {
    if (_routine.todos.isEmpty) return null;
    if (_currentTodoIndex >= _routine.todos.length) return null;
    return _routine.todos[_currentTodoIndex];
  }

  int get _firstIncompleteIndex {
    for (var i = 0; i < _routine.todos.length; i++) {
      if (!_routine.todos[i].isCompletedOnDate(_today)) return i;
    }
    return _routine.todos.length;
  }

  bool get _allComplete => _currentTodoIndex >= _routine.todos.length;

  @override
  void initState() {
    super.initState();
    _routine = widget.routine;
    _currentTodoIndex = _firstIncompleteIndex;
    _pageController = PageController(initialPage: _currentTodoIndex.clamp(0, _routine.todos.length - 1));
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
    _updateTicker();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _perTodoTick?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _updateTicker() {
    if (!_running) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedMs += 1000;
        if (_overallTargetMs > 0 && _elapsedMs >= _overallTargetMs) {
          _elapsedMs = _overallTargetMs;
          _running = false;
          _tick?.cancel();
          _tick = null;
          if (!_completionTriggered) {
            _completionTriggered = true;
            widget.onComplete?.call();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Target reached')),
            );
          }
        }
      });
    });
  }

  void _updatePerTodoTicker() {
    final runningIndex = _perTodoRunningIndex;
    if (runningIndex == null) {
      _perTodoTick?.cancel();
      _perTodoTick = null;
      return;
    }
    if (runningIndex >= _routine.todos.length) return;
    final targetMs = (_routine.todos[runningIndex].durationMinutes ?? 0) * 60 * 1000;
    if (targetMs <= 0) return;
    _perTodoTick ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        final prev = _elapsedMsByIndex[runningIndex] ?? 0;
        final next = prev + 1000;
        _elapsedMsByIndex[runningIndex] = next.clamp(0, targetMs);
        if (next >= targetMs) {
          _perTodoRunningIndex = null;
          _perTodoTick?.cancel();
          _perTodoTick = null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Step time reached')),
          );
        }
      });
    });
  }

  static String _fmt(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return '${h}h ${m}m';
    }
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }

  void _startPauseOverall() {
    setState(() {
      _running = !_running;
      _updateTicker();
    });
  }

  void _resetOverall() {
    setState(() {
      _running = false;
      _elapsedMs = 0;
      _completionTriggered = false;
      _updateTicker();
    });
  }

  void _adjustOverallMinutes(int deltaMinutes) {
    setState(() {
      final deltaMs = deltaMinutes * 60 * 1000;
      _elapsedMs = (_elapsedMs + deltaMs).clamp(0, _overallTargetMs);
      _updateTicker();
    });
  }

  void _startPausePerTodo() {
    setState(() {
      if (_perTodoRunningIndex == _currentTodoIndex) {
        _perTodoRunningIndex = null;
      } else {
        _perTodoRunningIndex = _currentTodoIndex;
      }
      _updatePerTodoTicker();
    });
  }

  void _resetPerTodo() {
    setState(() {
      if (_perTodoRunningIndex == _currentTodoIndex) {
        _perTodoRunningIndex = null;
        _perTodoTick?.cancel();
        _perTodoTick = null;
      }
      _elapsedMsByIndex[_currentTodoIndex] = 0;
      _updatePerTodoTicker();
    });
  }

  int _getPerTodoElapsedMs(int index) => _elapsedMsByIndex[index] ?? 0;

  bool _isPerTodoRunning(int index) => _perTodoRunningIndex == index;

  /// Mark todo complete with celebration animation
  Future<void> _markTodoCompleteWithCelebration(RoutineTodoItem todo) async {
    // Trigger haptic feedback immediately
    HapticFeedback.mediumImpact();

    // Start celebration animation
    setState(() {
      _showCelebration = true;
      _celebratingTodoId = todo.id;
    });

    // Wait a moment for celebration to be visible, then mark complete
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    await _markTodoComplete(todo);
  }

  Future<void> _markTodoComplete(RoutineTodoItem todo) async {
    final wasCompleted = todo.isCompletedOnDate(_today);
    final updatedTodo = todo.toggleForDate(_today);
    setState(() {
      final index = _routine.todos.indexWhere((t) => t.id == todo.id);
      if (index >= 0) {
        final nextTodos = List<RoutineTodoItem>.from(_routine.todos);
        nextTodos[index] = updatedTodo;
        _routine = _routine.copyWith(todos: nextTodos);
      }
    });

    final prefs = _prefs;
    if (prefs != null) {
      final routines = await RoutineStorageService.loadRoutines(prefs: prefs);
      final updated = routines.map((r) => r.id == _routine.id ? _routine : r).toList();
      await RoutineStorageService.saveRoutines(updated, prefs: prefs);
    }

    if (!mounted) return;

    // Only auto-advance if we just completed (not uncompleted)
    if (!wasCompleted) {
      final nextIndex = _firstIncompleteIndex;
      
      // Wait for celebration to finish before moving to next
      await Future.delayed(const Duration(milliseconds: 800));
      
      if (!mounted) return;
      setState(() {
        _currentTodoIndex = nextIndex;
        _updatePerTodoTicker();
      });
      if (nextIndex < _routine.todos.length && _pageController.hasClients) {
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }

      if (_allComplete && mounted) {
        // Show a more celebratory message for completing all
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Amazing! Routine complete!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else {
      // Uncompleting - stay on current page
      setState(() {
        _updatePerTodoTicker();
      });
    }
  }

  Widget _buildPageIndicatorDots() {
    final scheme = Theme.of(context).colorScheme;
    final count = _routine.todos.length;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isCurrent = i == _currentTodoIndex;
          return GestureDetector(
            onTap: () {
              if (_pageController.hasClients) {
                _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
              setState(() => _currentTodoIndex = i);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                isCurrent ? Icons.circle : Icons.circle_outlined,
                size: isCurrent ? 10 : 8,
                color: isCurrent ? scheme.primary : scheme.outline,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTodoCard(int index, RoutineTodoItem todo) {
    final scheme = Theme.of(context).colorScheme;
    final isCompleted = todo.isCompletedOnDate(_today);
    final isCelebrating = _showCelebration && _celebratingTodoId == todo.id;
    final icon = IconService.iconFromCodePoint(todo.iconCodePoint);
    final total = _routine.todos.length;

    // Colors
    const successColor = Color(0xFF4CAF50);

    return Padding(
      key: ValueKey(todo.id),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Stack(
        children: [
          // Modern list tile card
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isCompleted
                  ? successColor.withValues(alpha: 0.08)
                  : scheme.surfaceContainerHighest,
              border: Border.all(
                color: isCompleted
                    ? successColor.withValues(alpha: 0.3)
                    : scheme.outlineVariant.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isCompleted
                    ? () => _markTodoComplete(todo)
                    : () => _markTodoCompleteWithCelebration(todo),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Checkbox / Icon area
                      GestureDetector(
                        onTap: isCompleted
                            ? () => _markTodoComplete(todo)
                            : () => _markTodoCompleteWithCelebration(todo),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? successColor
                                : scheme.primaryContainer.withValues(alpha: 0.6),
                            boxShadow: isCompleted
                                ? [
                                    BoxShadow(
                                      color: successColor.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            isCompleted ? Icons.check_rounded : icon,
                            size: isCompleted ? 28 : 26,
                            color: isCompleted ? Colors.white : scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            Text(
                              todo.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isCompleted
                                    ? scheme.onSurface.withValues(alpha: 0.6)
                                    : scheme.onSurface,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: scheme.onSurface.withValues(alpha: 0.4),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Subtitle row
                            Row(
                              children: [
                                // Step indicator
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${index + 1}/$total',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                                if (todo.durationMinutes != null) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${todo.durationMinutes} min',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                if (isCompleted) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: successColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Done',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: successColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Action indicator
                      const SizedBox(width: 8),
                      Icon(
                        isCompleted ? Icons.refresh_rounded : Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Confetti overlay
          if (isCelebrating)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConfettiOverlay(
                  onComplete: () {
                    if (mounted) {
                      setState(() {
                        _showCelebration = false;
                        _celebratingTodoId = null;
                      });
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }


  int get _currentPageTargetMs {
    if (_hasOverallTimer) return _overallTargetMs;
    final todo = _currentTodo;
    if (todo?.durationMinutes == null || todo!.durationMinutes! <= 0) return 0;
    return todo.durationMinutes! * 60 * 1000;
  }

  int get _currentPageElapsedMs {
    if (_hasOverallTimer) return _elapsedMs;
    return _getPerTodoElapsedMs(_currentTodoIndex);
  }

  bool get _currentPageRunning {
    if (_hasOverallTimer) return _running;
    return _isPerTodoRunning(_currentTodoIndex);
  }

  Widget _buildBigTimerSection() {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = (screenWidth * 0.75).clamp(220.0, 360.0);
    final target = _hasOverallTimer ? _overallTargetMs : _currentPageTargetMs;
    final acc = _currentPageElapsedMs;
    final remaining = (target <= 0) ? 0 : (target - acc).clamp(0, target);
    final remainingProgress = target > 0 ? (1.0 - (acc / target).clamp(0.0, 1.0)) : 1.0;
    final running = _currentPageRunning;

    if (target <= 0 && !_hasOverallTimer) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No timer for this step',
          style: AppTypography.body(context).copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularCountdownTimer(
          progress: remainingProgress,
          remainingText: _fmt(remaining),
          elapsedText: 'Elapsed: ${_fmt(acc)}',
          targetText: 'Target: ${_fmt(target)}',
          size: circleSize,
          strokeWidth: 16,
          backgroundColor: scheme.surfaceContainerHighest,
          progressColor: running ? scheme.primary : scheme.primaryContainer,
          textColor: scheme.onSurface,
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _hasOverallTimer ? _startPauseOverall : _startPausePerTodo,
              icon: Icon(running ? Icons.pause : Icons.play_arrow, size: 22),
              label: Text(running ? 'Pause' : 'Start'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _hasOverallTimer ? _resetOverall : _resetPerTodo,
              icon: const Icon(Icons.restart_alt, size: 20),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        if (_hasOverallTimer && target > 0) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(onPressed: () => _adjustOverallMinutes(-5), child: const Text('-5m')),
              OutlinedButton(onPressed: () => _adjustOverallMinutes(-1), child: const Text('-1m')),
              OutlinedButton(onPressed: () => _adjustOverallMinutes(1), child: const Text('+1m')),
              OutlinedButton(onPressed: () => _adjustOverallMinutes(5), child: const Text('+5m')),
            ],
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.routine.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _routine.title,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.surfaceContainerHighest,
            ],
          ),
        ),
        child: SafeArea(
          child: _routine.todos.isEmpty
              ? Column(
                  children: [
                    if (_hasOverallTimer) ...[
                      const Spacer(flex: 1),
                      _buildBigTimerSection(),
                    ],
                    const Spacer(flex: 2),
                    Text(
                      'No todos in routine',
                      style: AppTypography.body(context).copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const Spacer(flex: 3),
                  ],
                )
              : Column(
                  children: [
                    const SizedBox(height: 16),
                    _buildBigTimerSection(),
                    _buildPageIndicatorDots(),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _routine.todos.length,
                        onPageChanged: (int page) {
                          setState(() => _currentTodoIndex = page);
                        },
                        itemBuilder: (context, index) {
                          return _buildTodoCard(index, _routine.todos[index]);
                        },
                      ),
                    ),
                    if (_allComplete)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.done_all),
                          label: const Text('Done'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size(double.infinity, 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
