import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../../services/habits/habit_timer_state_service.dart';
import '../../services/utils/logical_date_service.dart';

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
    if (_running) {
      await HabitTimerStateService.pause(prefs: p, habitId: widget.habit.id, logicalDate: today);
    } else {
      await HabitTimerStateService.start(prefs: p, habitId: widget.habit.id, logicalDate: today);
    }
    await _refresh();
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
    final progress = (target <= 0) ? null : (acc / target).clamp(0.0, 1.0);
    final remaining = (target <= 0) ? 0 : (target - acc).clamp(0, target);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.habit.timeBound?.enabled == true)
              const Text('Timer', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _fmt(acc),
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (_running)
                          const Chip(
                            label: Text('Running'),
                          )
                        else
                          const Chip(
                            label: Text('Paused'),
                          ),
                      ],
                    ),
                    if (target > 0) ...[
                      const SizedBox(height: 8),
                      Text('Target: ${_fmt(target)} • Remaining: ${_fmt(remaining)}',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(value: progress),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _prefs == null ? null : _startPause,
                            icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                            label: Text(_running ? 'Pause' : 'Start'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _prefs == null ? null : _reset,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Adjust time', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Use this if you forgot to pause.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(onPressed: _prefs == null ? null : () => _adjustMinutes(-5), child: const Text('-5m')),
                OutlinedButton(onPressed: _prefs == null ? null : () => _adjustMinutes(-1), child: const Text('-1m')),
                OutlinedButton(onPressed: _prefs == null ? null : () => _adjustMinutes(1), child: const Text('+1m')),
                OutlinedButton(onPressed: _prefs == null ? null : () => _adjustMinutes(5), child: const Text('+5m')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

