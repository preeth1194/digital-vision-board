import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../services/habit_timer_state_service.dart';
import '../services/logical_date_service.dart';
import '../widgets/circular_countdown_timer.dart';

class HabitTimerScreen extends StatefulWidget {
  final HabitItem habit;
  final Future<void> Function()? onMarkCompleted;

  const HabitTimerScreen({
    super.key,
    required this.habit,
    this.onMarkCompleted,
  });

  @override
  State<HabitTimerScreen> createState() => _HabitTimerScreenState();
}

class _HabitTimerScreenState extends State<HabitTimerScreen> {
  SharedPreferences? _prefs;
  Timer? _tick;

  int _accMs = 0;
  bool _running = false;
  bool _completionTriggered = false;

  int get _targetMs => HabitTimerStateService.targetMsForHabit(widget.habit);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _prefs = p);

    await _refresh();
  }

  Future<void> _refresh() async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    final acc = await HabitTimerStateService.accumulatedMsNow(prefs: p, habitId: widget.habit.id, logicalDate: today);
    final running = await HabitTimerStateService.isRunning(prefs: p, habitId: widget.habit.id, logicalDate: today);
    final target = _targetMs;

    // If we hit (or exceed) the target while running, automatically stop the timer.
    // This prevents accidental over-counting past the intended daily goal.
    if (running && target > 0 && acc >= target) {
      await HabitTimerStateService.pause(prefs: p, habitId: widget.habit.id, logicalDate: today);
      final acc2 =
          await HabitTimerStateService.accumulatedMsNow(prefs: p, habitId: widget.habit.id, logicalDate: today);
      if (!mounted) return;
      setState(() {
        _accMs = acc2;
        _running = false;
      });
      _updateTicker();

      // Also mark the habit as completed (best-effort) via the provided callback.
      if (!_completionTriggered) {
        _completionTriggered = true;
        final cb = widget.onMarkCompleted;
        if (cb != null) {
          try {
            await cb();
          } catch (_) {
            // ignore
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Target reached — marked as completed.')),
          );
        }
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _accMs = acc;
      _running = running;
    });
    _updateTicker();
  }

  void _updateTicker() {
    if (!_running) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
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

  Future<void> _startPause() async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    
    // Optimistically update local state before async operations
    final wasRunning = _running;
    setState(() {
      _running = !_running;
    });
    
    try {
      if (wasRunning) {
        await HabitTimerStateService.pause(prefs: p, habitId: widget.habit.id, logicalDate: today);
      } else {
        await HabitTimerStateService.start(prefs: p, habitId: widget.habit.id, logicalDate: today);
      }
      // Refresh to sync with actual state
      await _refresh();
    } catch (e) {
      // Revert optimistic update on error
      if (!mounted) return;
      setState(() {
        _running = wasRunning;
      });
      // Still refresh to get actual state
      await _refresh();
    }
  }

  Future<void> _reset() async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    await HabitTimerStateService.resetForDay(prefs: p, habitId: widget.habit.id, logicalDate: today);
    await _refresh();
  }

  Future<void> _adjustMinutes(int deltaMinutes) async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();
    await HabitTimerStateService.adjustAccumulated(
      prefs: p,
      habitId: widget.habit.id,
      logicalDate: today,
      deltaMs: deltaMinutes * 60 * 1000,
      resumeIfWasRunning: true,
    );
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetMs;
    final acc = _accMs;
    final remaining = (target <= 0) ? 0 : (target - acc).clamp(0, target);
    
    // Calculate remaining progress for circular timer (1.0 = full, 0.0 = empty)
    final remainingProgress = target > 0 ? (1.0 - (acc / target).clamp(0.0, 1.0)) : 1.0;
    
    // Calculate circle size based on screen width (80% of screen, but with constraints)
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = (screenWidth * 0.8).clamp(250.0, 400.0);
    
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
          widget.habit.name,
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
          child: Column(
            children: [
              // Spacer to push content to center
              const Spacer(flex: 2),
              
              // Circular countdown timer
              CircularCountdownTimer(
                progress: remainingProgress,
                remainingText: _fmt(remaining),
                elapsedText: target > 0 ? 'Elapsed: ${_fmt(acc)}' : _fmt(acc),
                targetText: target > 0 ? 'Target: ${_fmt(target)}' : null,
                size: circleSize,
                strokeWidth: 20,
                backgroundColor: scheme.surfaceContainerHighest,
                progressColor: _running ? scheme.primary : scheme.primaryContainer,
                textColor: scheme.onSurface,
              ),
              
              // Status chip
              const SizedBox(height: 24),
              Chip(
                avatar: Icon(
                  _running ? Icons.play_circle_filled : Icons.pause_circle_filled,
                  size: 20,
                  color: _running ? scheme.primary : scheme.onSurfaceVariant,
                ),
                label: Text(
                  _running ? 'Running' : 'Paused',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _running ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                backgroundColor: _running 
                    ? scheme.primaryContainer 
                    : scheme.surfaceContainerHighest,
              ),
              
              // Spacer to push controls to bottom
              const Spacer(flex: 3),
              
              // Controls at bottom
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Start/Pause and Reset buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _prefs == null ? null : _startPause,
                            icon: Icon(_running ? Icons.pause : Icons.play_arrow, size: 28),
                            label: Text(
                              _running ? 'Pause' : 'Start',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _prefs == null ? null : _reset,
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('Reset'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Adjust time buttons
                    if (target > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Adjust time',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: _prefs == null ? null : () => _adjustMinutes(-5),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('-5m'),
                          ),
                          OutlinedButton(
                            onPressed: _prefs == null ? null : () => _adjustMinutes(-1),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('-1m'),
                          ),
                          OutlinedButton(
                            onPressed: _prefs == null ? null : () => _adjustMinutes(1),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('+1m'),
                          ),
                          OutlinedButton(
                            onPressed: _prefs == null ? null : () => _adjustMinutes(5),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('+5m'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

