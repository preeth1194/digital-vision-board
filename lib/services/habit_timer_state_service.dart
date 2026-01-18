import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import 'logical_date_service.dart';

/// Per-habit, per-logical-day runtime state for time/location-bound habits.
///
/// Stored separately from [HabitItem] history to avoid bloating synced data.
final class HabitTimerStateService {
  HabitTimerStateService._();

  static const String _prefix = 'habit_timer_state_v1';

  static String _key(String habitId, String isoDate) => '$_prefix:$habitId:$isoDate';

  static String _isoForDate(DateTime date) => LogicalDateService.toIsoDate(date);

  static Future<_HabitDayTimerState> _load({
    required SharedPreferences prefs,
    required String habitId,
    required String isoDate,
  }) async {
    final raw = prefs.getString(_key(habitId, isoDate));
    if (raw == null || raw.trim().isEmpty) return const _HabitDayTimerState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const _HabitDayTimerState();
      return _HabitDayTimerState.fromJson(decoded);
    } catch (_) {
      return const _HabitDayTimerState();
    }
  }

  static Future<void> _save({
    required SharedPreferences prefs,
    required String habitId,
    required String isoDate,
    required _HabitDayTimerState state,
  }) async {
    await prefs.setString(_key(habitId, isoDate), jsonEncode(state.toJson()));
  }

  /// Returns the accumulated milliseconds (including current running interval if any).
  static Future<int> accumulatedMsNow({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    int? nowMs,
  }) async {
    final iso = _isoForDate(logicalDate);
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return s.accumulatedMsNow(nowMs: now);
  }

  static Future<bool> isRunning({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
  }) async {
    final iso = _isoForDate(logicalDate);
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    return s.runningSinceMs != null;
  }

  static Future<void> start({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    int? nowMs,
  }) async {
    final iso = _isoForDate(logicalDate);
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    // If already running, no-op.
    if (s.runningSinceMs != null) return;
    await _save(
      prefs: prefs,
      habitId: habitId,
      isoDate: iso,
      state: s.copyWith(runningSinceMs: now),
    );
  }

  static Future<void> pause({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    int? nowMs,
  }) async {
    final iso = _isoForDate(logicalDate);
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    final next = s.pause(nowMs: now);
    await _save(prefs: prefs, habitId: habitId, isoDate: iso, state: next);
  }

  static Future<void> resume({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    int? nowMs,
  }) async {
    // Resume is identical to start, but semantically clearer for the UI.
    await start(prefs: prefs, habitId: habitId, logicalDate: logicalDate, nowMs: nowMs);
  }

  /// Clears timer state for a day (does NOT change habit completion).
  static Future<void> resetForDay({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
  }) async {
    final iso = _isoForDate(logicalDate);
    await prefs.remove(_key(habitId, iso));
  }

  /// Adjusts today's accumulated time by [deltaMs] (can be negative).
  ///
  /// This is meant to correct mistakes (e.g. forgetting to pause).
  ///
  /// Behavior:
  /// - If running, we first pause to snapshot the current accumulated time.
  /// - Apply the delta (clamped to 0).
  /// - If [resumeIfWasRunning] is true, resume after adjustment.
  static Future<void> adjustAccumulated({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    required int deltaMs,
    bool resumeIfWasRunning = true,
    int? nowMs,
  }) async {
    final iso = _isoForDate(logicalDate);
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final s0 = await _load(prefs: prefs, habitId: habitId, isoDate: iso);

    final wasRunning = s0.runningSinceMs != null;
    final s1 = wasRunning ? s0.pause(nowMs: now) : s0;

    final nextAcc = (s1.accumulatedMs + deltaMs).clamp(0, 1 << 62);
    var next = s1.copyWith(accumulatedMs: nextAcc);
    if (resumeIfWasRunning && wasRunning) {
      next = next.copyWith(runningSinceMs: now);
    }

    await _save(prefs: prefs, habitId: habitId, isoDate: iso, state: next);
  }

  /// Replaces today's accumulated time with [accumulatedMs] (clamped to 0).
  static Future<void> setAccumulated({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    required int accumulatedMs,
    bool resumeIfWasRunning = true,
    int? nowMs,
  }) async {
    final iso = _isoForDate(logicalDate);
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final s0 = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    final wasRunning = s0.runningSinceMs != null;
    final s1 = wasRunning ? s0.pause(nowMs: now) : s0;
    var next = s1.copyWith(accumulatedMs: accumulatedMs.clamp(0, 1 << 62));
    if (resumeIfWasRunning && wasRunning) {
      next = next.copyWith(runningSinceMs: now);
    }
    await _save(prefs: prefs, habitId: habitId, isoDate: iso, state: next);
  }

  /// For location-bound habits: update "inside geofence" state using enter/exit events.
  ///
  /// If inside, we treat it like "running" and accumulate time between enter..exit.
  static Future<void> applyGeofenceEvent({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    required bool inside,
    int? eventMs,
  }) async {
    final iso = _isoForDate(logicalDate);
    final now = eventMs ?? DateTime.now().millisecondsSinceEpoch;
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    final next = s.applyInsideState(inside: inside, nowMs: now);
    await _save(prefs: prefs, habitId: habitId, isoDate: iso, state: next);
  }

  static int targetMsForHabit(HabitItem habit) {
    final tb = habit.timeBound;
    final lb = habit.locationBound;

    // Mixed: location gate + time requirement -> use timeBound duration as target.
    if (tb != null && tb.enabled) {
      return tb.durationMinutes * 60 * 1000;
    }

    // Location-only dwell: treat dwellMinutes as target.
    if (lb != null &&
        lb.enabled &&
        (lb.triggerMode == 'dwell' || lb.triggerMode == 'both') &&
        (lb.dwellMinutes != null && lb.dwellMinutes! > 0)) {
      return lb.dwellMinutes! * 60 * 1000;
    }

    return 0;
  }

  /// Returns true if target is reached (based on habit config) and should be marked complete.
  static Future<bool> hasReachedTarget({
    required SharedPreferences prefs,
    required HabitItem habit,
    required DateTime logicalDate,
    int? nowMs,
  }) async {
    final targetMs = targetMsForHabit(habit);
    if (targetMs <= 0) return false;
    final acc = await accumulatedMsNow(
      prefs: prefs,
      habitId: habit.id,
      logicalDate: logicalDate,
      nowMs: nowMs,
    );
    return acc >= targetMs;
  }

  /// Convenience: if target reached, return true (caller should mark the habit complete).
  static Future<bool> markCompletedIfReachedTarget({
    required SharedPreferences prefs,
    required HabitItem habit,
    required DateTime logicalDate,
    int? nowMs,
  }) async {
    final reached = await hasReachedTarget(
      prefs: prefs,
      habit: habit,
      logicalDate: logicalDate,
      nowMs: nowMs,
    );
    if (!reached) return false;
    // Stop running to avoid accumulating beyond target once completed.
    await pause(prefs: prefs, habitId: habit.id, logicalDate: logicalDate, nowMs: nowMs);
    return true;
  }
}

final class _HabitDayTimerState {
  final int accumulatedMs;
  final int? runningSinceMs;
  final bool? lastKnownGeofenceInside;

  const _HabitDayTimerState({
    this.accumulatedMs = 0,
    this.runningSinceMs,
    this.lastKnownGeofenceInside,
  });

  _HabitDayTimerState copyWith({
    int? accumulatedMs,
    int? runningSinceMs,
    bool? lastKnownGeofenceInside,
    bool clearRunningSinceMs = false,
  }) {
    return _HabitDayTimerState(
      accumulatedMs: accumulatedMs ?? this.accumulatedMs,
      runningSinceMs: clearRunningSinceMs ? null : (runningSinceMs ?? this.runningSinceMs),
      lastKnownGeofenceInside: lastKnownGeofenceInside ?? this.lastKnownGeofenceInside,
    );
  }

  int accumulatedMsNow({required int nowMs}) {
    final base = accumulatedMs < 0 ? 0 : accumulatedMs;
    final start = runningSinceMs;
    if (start == null) return base;
    final delta = nowMs - start;
    return base + (delta < 0 ? 0 : delta);
  }

  _HabitDayTimerState pause({required int nowMs}) {
    final start = runningSinceMs;
    if (start == null) return this;
    final nextAcc = accumulatedMsNow(nowMs: nowMs);
    return copyWith(accumulatedMs: nextAcc, clearRunningSinceMs: true);
  }

  _HabitDayTimerState applyInsideState({required bool inside, required int nowMs}) {
    // If we flip from inside->outside, pause and accumulate.
    // If we flip from outside->inside, start running.
    final prev = lastKnownGeofenceInside;
    if (prev == inside) {
      return copyWith(lastKnownGeofenceInside: inside);
    }

    if (inside) {
      // Enter: start running.
      return copyWith(lastKnownGeofenceInside: true, runningSinceMs: nowMs);
    }

    // Exit: pause.
    final paused = pause(nowMs: nowMs);
    return paused.copyWith(lastKnownGeofenceInside: false);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'accumulatedMs': accumulatedMs,
        'runningSinceMs': runningSinceMs,
        'lastKnownGeofenceInside': lastKnownGeofenceInside,
      };

  factory _HabitDayTimerState.fromJson(Map<String, dynamic> json) {
    return _HabitDayTimerState(
      accumulatedMs: (json['accumulatedMs'] as num?)?.toInt() ?? 0,
      runningSinceMs: (json['runningSinceMs'] as num?)?.toInt(),
      lastKnownGeofenceInside: json['lastKnownGeofenceInside'] as bool?,
    );
  }
}

