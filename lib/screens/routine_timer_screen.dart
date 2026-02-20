import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/habit_item.dart';
import '../models/habit_action_step.dart';
import '../services/icon_service.dart';
import '../utils/app_typography.dart';
import '../widgets/circular_countdown_timer.dart';
import '../widgets/routine/confetti_overlay.dart';

/// Full-screen timer screen for a habit with action steps.
class RoutineTimerScreen extends StatefulWidget {
  final HabitItem habit;
  final VoidCallback? onComplete;

  const RoutineTimerScreen({
    super.key,
    required this.habit,
    this.onComplete,
  });

  @override
  State<RoutineTimerScreen> createState() => _RoutineTimerScreenState();
}

class _RoutineTimerScreenState extends State<RoutineTimerScreen> {
  late HabitItem _habit;
  int _currentStepIndex = 0;
  late PageController _pageController;

  Timer? _tick;
  int _elapsedMs = 0;
  bool _running = false;
  bool _completionTriggered = false;

  bool _showCelebration = false;
  String? _celebratingStepId;

  // Track which steps are completed locally (by step id)
  final Set<String> _completedStepIds = {};

  List<HabitActionStep> get _steps => _habit.actionSteps;

  bool get _hasTimer {
    final tb = _habit.timeBound;
    return tb != null && tb.enabled && tb.durationMinutes > 0;
  }

  int get _targetMs => (_habit.timeBound?.durationMinutes ?? 0) * 60 * 1000;

  bool get _allStepsComplete =>
      _steps.isNotEmpty && _completedStepIds.length >= _steps.length;

  int get _firstIncompleteIndex {
    for (var i = 0; i < _steps.length; i++) {
      if (!_completedStepIds.contains(_steps[i].id)) return i;
    }
    return _steps.length;
  }

  @override
  void initState() {
    super.initState();
    _habit = widget.habit;
    _currentStepIndex = 0;
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _tick?.cancel();
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
        if (_targetMs > 0 && _elapsedMs >= _targetMs) {
          _elapsedMs = _targetMs;
          _running = false;
          _tick?.cancel();
          _tick = null;
          if (!_completionTriggered) {
            _completionTriggered = true;
            widget.onComplete?.call();
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Target reached')));
          }
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

  void _startPause() {
    setState(() {
      _running = !_running;
      _updateTicker();
    });
  }

  void _reset() {
    setState(() {
      _running = false;
      _elapsedMs = 0;
      _completionTriggered = false;
      _updateTicker();
    });
  }

  void _adjustMinutes(int deltaMinutes) {
    setState(() {
      final deltaMs = deltaMinutes * 60 * 1000;
      _elapsedMs = (_elapsedMs + deltaMs).clamp(0, _targetMs);
      _updateTicker();
    });
  }

  Future<void> _markStepCompleteWithCelebration(HabitActionStep step) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _showCelebration = true;
      _celebratingStepId = step.id;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _toggleStep(step);
  }

  void _toggleStep(HabitActionStep step) {
    final wasComplete = _completedStepIds.contains(step.id);
    setState(() {
      if (wasComplete) {
        _completedStepIds.remove(step.id);
      } else {
        _completedStepIds.add(step.id);
      }
    });

    if (!wasComplete) {
      // Auto-advance after celebration
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        final nextIndex = _firstIncompleteIndex;
        setState(() => _currentStepIndex = nextIndex);
        if (nextIndex < _steps.length && _pageController.hasClients) {
          _pageController.animateToPage(nextIndex,
              duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
        }
        if (_allStepsComplete && mounted && !_completionTriggered) {
          _completionTriggered = true;
          HapticFeedback.heavyImpact();
          widget.onComplete?.call();
          Navigator.of(context).pop(_completedStepIds.toList());
        }
      });
    }
  }

  Widget _buildPageIndicatorDots() {
    final scheme = Theme.of(context).colorScheme;
    final count = _steps.length;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final isCurrent = i == _currentStepIndex;
          return GestureDetector(
            onTap: () {
              if (_pageController.hasClients) {
                _pageController.animateToPage(i,
                    duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }
              setState(() => _currentStepIndex = i);
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

  Widget _buildStepCard(int index, HabitActionStep step) {
    final scheme = Theme.of(context).colorScheme;
    final isCompleted = _completedStepIds.contains(step.id);
    final isCelebrating = _showCelebration && _celebratingStepId == step.id;
    final icon = IconService.iconFromCodePoint(step.iconCodePoint);
    final total = _steps.length;
    final successColor = scheme.primary;

    return Padding(
      key: ValueKey(step.id),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Stack(
        children: [
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
                    color: scheme.shadow.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isCompleted
                    ? () => _toggleStep(step)
                    : () => _markStepCompleteWithCelebration(step),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: isCompleted
                            ? () => _toggleStep(step)
                            : () => _markStepCompleteWithCelebration(step),
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
                                        offset: const Offset(0, 2)),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            isCompleted ? Icons.check_rounded : icon,
                            size: isCompleted ? 28 : 26,
                            color: isCompleted ? scheme.onPrimary : scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              step.title.isEmpty ? 'Step ${index + 1}' : step.title,
                              style: AppTypography.body(context).copyWith(
                                fontWeight: FontWeight.w600,
                                color: isCompleted
                                    ? scheme.onSurface.withValues(alpha: 0.6)
                                    : scheme.onSurface,
                                decoration:
                                    isCompleted ? TextDecoration.lineThrough : null,
                                decorationColor:
                                    scheme.onSurface.withValues(alpha: 0.4),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${index + 1}/$total',
                                    style: AppTypography.caption(context).copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary)),
                              ),
                              if (isCompleted) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: successColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Done',
                                      style: AppTypography.caption(context).copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: successColor)),
                                ),
                              ],
                            ]),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isCompleted
                            ? Icons.refresh_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isCelebrating)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ConfettiOverlay(
                  onComplete: () {
                    if (mounted) {
                      setState(() {
                        _showCelebration = false;
                        _celebratingStepId = null;
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

  Widget _buildBigTimerSection() {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = (screenWidth * 0.75).clamp(220.0, 360.0);
    final target = _targetMs;
    final acc = _elapsedMs;
    final remaining = (target <= 0) ? 0 : (target - acc).clamp(0, target);
    final remainingProgress = target > 0 ? (1.0 - (acc / target).clamp(0.0, 1.0)) : 1.0;

    if (target <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text('No timer set',
            style: AppTypography.body(context).copyWith(color: scheme.onSurfaceVariant)),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      CircularCountdownTimer(
        progress: remainingProgress,
        remainingText: _fmt(remaining),
        elapsedText: 'Elapsed: ${_fmt(acc)}',
        targetText: 'Target: ${_fmt(target)}',
        size: circleSize,
        strokeWidth: 16,
        backgroundColor: scheme.surfaceContainerHighest,
        progressColor: _running ? scheme.primary : scheme.primaryContainer,
        textColor: scheme.onSurface,
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilledButton.icon(
          onPressed: _startPause,
          icon: Icon(_running ? Icons.pause : Icons.play_arrow, size: 22),
          label: Text(_running ? 'Pause' : 'Start'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.restart_alt, size: 20),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ]),
      if (target > 0) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton(onPressed: () => _adjustMinutes(-5), child: const Text('-5m')),
            OutlinedButton(onPressed: () => _adjustMinutes(-1), child: const Text('-1m')),
            OutlinedButton(onPressed: () => _adjustMinutes(1), child: const Text('+1m')),
            OutlinedButton(onPressed: () => _adjustMinutes(5), child: const Text('+5m')),
          ],
        ),
      ],
      const SizedBox(height: 16),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop()),
        title: Text(_habit.name,
            style: AppTypography.body(context).copyWith(fontWeight: FontWeight.w600)),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surface, scheme.surfaceContainerHighest],
          ),
        ),
        child: SafeArea(
          child: _steps.isEmpty
              ? Column(children: [
                  if (_hasTimer) ...[
                    const Spacer(flex: 1),
                    _buildBigTimerSection(),
                  ],
                  const Spacer(flex: 2),
                  Text('No action steps',
                      style: AppTypography.body(context)
                          .copyWith(color: scheme.onSurfaceVariant)),
                  const Spacer(flex: 3),
                ])
              : Column(children: [
                  const SizedBox(height: 16),
                  _buildBigTimerSection(),
                  _buildPageIndicatorDots(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _steps.length,
                      onPageChanged: (p) => setState(() => _currentStepIndex = p),
                      itemBuilder: (ctx, i) => _buildStepCard(i, _steps[i]),
                    ),
                  ),
                  if (_allStepsComplete)
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
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ]),
        ),
      ),
    );
  }
}
