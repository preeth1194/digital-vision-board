import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../services/habit_timer_state_service.dart';
import '../services/logical_date_service.dart';
import '../services/rhythmic_timer_service.dart';
import '../services/rhythmic_timer_state_service.dart' show RhythmicTimerState, RhythmicTimerStateService;
import '../widgets/circular_countdown_timer.dart';

class RhythmicTimerScreen extends StatefulWidget {
  final HabitItem habit;
  final Future<void> Function()? onMarkCompleted;

  const RhythmicTimerScreen({
    super.key,
    required this.habit,
    this.onMarkCompleted,
  });

  @override
  State<RhythmicTimerScreen> createState() => _RhythmicTimerScreenState();
}

class _RhythmicTimerScreenState extends State<RhythmicTimerScreen> {
  SharedPreferences? _prefs;
  Timer? _tick;
  RhythmicTimerService? _rhythmicTimer;
  RhythmicTimerState? _songState;

  // Time-based state
  int _accMs = 0;
  bool _running = false;
  bool _completionTriggered = false;

  int get _targetMs => HabitTimerStateService.targetMsForHabit(widget.habit);
  bool get _isSongBased => widget.habit.timeBound?.isSongBased ?? false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _rhythmicTimer?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _prefs = p);

    if (_isSongBased) {
      _rhythmicTimer = RhythmicTimerService(
        habitId: widget.habit.id,
        habit: widget.habit,
        prefs: p,
        logicalDate: LogicalDateService.today(),
        onHabitComplete: () async {
          if (!_completionTriggered && widget.onMarkCompleted != null) {
            _completionTriggered = true;
            await widget.onMarkCompleted!();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All songs completed!')),
              );
            }
          }
        },
      );
      await _rhythmicTimer!.initialize();
    }

    await _refresh();
  }

  Future<void> _refresh() async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();

    if (_isSongBased) {
      final state = await _rhythmicTimer?.getCurrentState();
      if (!mounted) return;
      setState(() {
        _songState = state;
      });
    } else {
      final acc = await HabitTimerStateService.accumulatedMsNow(
        prefs: p,
        habitId: widget.habit.id,
        logicalDate: today,
      );
      final running = await HabitTimerStateService.isRunning(
        prefs: p,
        habitId: widget.habit.id,
        logicalDate: today,
      );
      final target = _targetMs;

      // If we hit (or exceed) the target while running, automatically stop the timer.
      if (running && target > 0 && acc >= target) {
        await HabitTimerStateService.pause(
          prefs: p,
          habitId: widget.habit.id,
          logicalDate: today,
        );
        final acc2 = await HabitTimerStateService.accumulatedMsNow(
          prefs: p,
          habitId: widget.habit.id,
          logicalDate: today,
        );
        if (!mounted) return;
        setState(() {
          _accMs = acc2;
          _running = false;
        });
        _updateTicker();

        // Mark the habit as completed
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
  }

  void _updateTicker() {
    if (!_running && !_isSongBased) {
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
      if (_isSongBased) {
        if (wasRunning) {
          await _rhythmicTimer?.pause();
        } else {
          await _rhythmicTimer?.start();
        }
      } else {
        if (wasRunning) {
          await HabitTimerStateService.pause(
            prefs: p,
            habitId: widget.habit.id,
            logicalDate: today,
          );
        } else {
          await HabitTimerStateService.start(
            prefs: p,
            habitId: widget.habit.id,
            logicalDate: today,
          );
        }
      }
      // Refresh to sync with actual state
      await _refresh();
    } catch (e) {
      // Revert optimistic update on error
      if (!mounted) return;
      setState(() {
        _running = wasRunning;
      });
      if (mounted && _isSongBased) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not ${wasRunning ? 'pause' : 'start'} timer: ${e.toString()}')),
        );
      }
      // Still refresh to get actual state
      await _refresh();
    }
  }

  Future<void> _reset() async {
    final p = _prefs;
    if (p == null) return;
    final today = LogicalDateService.today();

    if (_isSongBased) {
      await RhythmicTimerStateService.resetForDay(
        prefs: p,
        habitId: widget.habit.id,
        logicalDate: today,
      );
      await _rhythmicTimer?.initialize();
    } else {
      await HabitTimerStateService.resetForDay(
        prefs: p,
        habitId: widget.habit.id,
        logicalDate: today,
      );
    }
    await _refresh();
  }

  Future<void> _adjustMinutes(int deltaMinutes) async {
    if (_isSongBased) return; // Not applicable for song mode

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    
    // Calculate circle size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final circleSize = (screenWidth * 0.8).clamp(250.0, 400.0);
    
    // Prepare data for circular timer based on mode
    double remainingProgress;
    String remainingText;
    String? elapsedText;
    String? targetText;
    
    if (_isSongBased) {
      // Song-based mode
      if (_songState != null) {
        final totalSongs = _songState!.totalSongs;
        final songsRemaining = _songState!.songsRemaining;
        remainingProgress = totalSongs > 0 ? (songsRemaining / totalSongs).clamp(0.0, 1.0) : 1.0;
        remainingText = '$songsRemaining';
        elapsedText = 'of $totalSongs songs';
        targetText = _songState!.currentSongTitle != null ? _songState!.currentSongTitle : null;
      } else {
        remainingProgress = 1.0;
        remainingText = '0';
        elapsedText = 'songs';
        targetText = null;
      }
    } else {
      // Time-based mode
      final target = _targetMs;
      final acc = _accMs;
      final remaining = (target <= 0) ? 0 : (target - acc).clamp(0, target);
      remainingProgress = target > 0 ? (1.0 - (acc / target).clamp(0.0, 1.0)) : 1.0;
      remainingText = _fmt(remaining);
      elapsedText = target > 0 ? 'Elapsed: ${_fmt(acc)}' : _fmt(acc);
      targetText = target > 0 ? 'Target: ${_fmt(target)}' : null;
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
                remainingText: remainingText,
                elapsedText: elapsedText,
                targetText: targetText,
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
              
              // Song-based: Show current song title if available
              if (_isSongBased && _songState?.currentSongTitle != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Now Playing',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _songState!.currentSongTitle!,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
              
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
                    
                    // Adjust time buttons (only for time-based mode)
                    if (!_isSongBased && _targetMs > 0) ...[
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
