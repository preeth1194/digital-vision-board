import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import 'logical_date_service.dart';

/// Per-habit, per-logical-day runtime state for rhythmic timer (song-based mode).
///
/// Stored separately from [HabitItem] history to avoid bloating synced data.
final class RhythmicTimerStateService {
  RhythmicTimerStateService._();

  static const String _prefix = 'rhythmic_timer_state_v1';

  static String _key(String habitId, String isoDate) => '$_prefix:$habitId:$isoDate';

  static String _isoForDate(DateTime date) => LogicalDateService.toIsoDate(date);

  static Future<_RhythmicTimerState> _load({
    required SharedPreferences prefs,
    required String habitId,
    required String isoDate,
  }) async {
    final raw = prefs.getString(_key(habitId, isoDate));
    if (raw == null || raw.trim().isEmpty) return const _RhythmicTimerState();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return const _RhythmicTimerState();
      return _RhythmicTimerState.fromJson(decoded);
    } catch (_) {
      return const _RhythmicTimerState();
    }
  }

  static Future<void> _save({
    required SharedPreferences prefs,
    required String habitId,
    required String isoDate,
    required _RhythmicTimerState state,
  }) async {
    await prefs.setString(_key(habitId, isoDate), jsonEncode(state.toJson()));
  }

  /// Get current songs remaining for a habit on a given date.
  static Future<int> songsRemaining({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
  }) async {
    final iso = _isoForDate(logicalDate);
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    return s.songsRemaining;
  }

  /// Get current song title for a habit on a given date.
  static Future<String?> currentSongTitle({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
  }) async {
    final iso = _isoForDate(logicalDate);
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    return s.currentSongTitle;
  }

  /// Initialize song-based timer state.
  static Future<void> initialize({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    required int totalSongs,
  }) async {
    final iso = _isoForDate(logicalDate);
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    if (s.totalSongs > 0) {
      // Already initialized, don't overwrite
      return;
    }
    await _save(
      prefs: prefs,
      habitId: habitId,
      isoDate: iso,
      state: s.copyWith(
        totalSongs: totalSongs,
        songsRemaining: totalSongs,
      ),
    );
  }

  /// Decrement songs remaining when a track changes.
  static Future<int> decrementSong({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
  }) async {
    final iso = _isoForDate(logicalDate);
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    final nextRemaining = (s.songsRemaining - 1).clamp(0, s.totalSongs);
    await _save(
      prefs: prefs,
      habitId: habitId,
      isoDate: iso,
      state: s.copyWith(songsRemaining: nextRemaining),
    );
    return nextRemaining;
  }

  /// Update current song title.
  static Future<void> updateCurrentSong({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
    required String? songTitle,
  }) async {
    final iso = _isoForDate(logicalDate);
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    await _save(
      prefs: prefs,
      habitId: habitId,
      isoDate: iso,
      state: s.copyWith(currentSongTitle: songTitle),
    );
  }

  /// Reset timer state for a day.
  static Future<void> resetForDay({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
  }) async {
    final iso = _isoForDate(logicalDate);
    await prefs.remove(_key(habitId, iso));
  }

  /// Get all state for a habit on a given date.
  static Future<RhythmicTimerState> getState({
    required SharedPreferences prefs,
    required String habitId,
    required DateTime logicalDate,
  }) async {
    final iso = _isoForDate(logicalDate);
    final s = await _load(prefs: prefs, habitId: habitId, isoDate: iso);
    return RhythmicTimerState(
      songsRemaining: s.songsRemaining,
      currentSongTitle: s.currentSongTitle,
      totalSongs: s.totalSongs,
    );
  }
}

/// Public state object for rhythmic timer.
final class RhythmicTimerState {
  final int songsRemaining;
  final String? currentSongTitle;
  final int totalSongs;

  const RhythmicTimerState({
    required this.songsRemaining,
    this.currentSongTitle,
    required this.totalSongs,
  });
}

/// Internal state storage model.
final class _RhythmicTimerState {
  final int songsRemaining;
  final String? currentSongTitle;
  final int totalSongs;

  const _RhythmicTimerState({
    this.songsRemaining = 0,
    this.currentSongTitle,
    this.totalSongs = 0,
  });

  _RhythmicTimerState copyWith({
    int? songsRemaining,
    String? currentSongTitle,
    int? totalSongs,
    bool clearCurrentSongTitle = false,
  }) {
    return _RhythmicTimerState(
      songsRemaining: songsRemaining ?? this.songsRemaining,
      currentSongTitle: clearCurrentSongTitle
          ? null
          : (currentSongTitle ?? this.currentSongTitle),
      totalSongs: totalSongs ?? this.totalSongs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'songsRemaining': songsRemaining,
        'currentSongTitle': currentSongTitle,
        'totalSongs': totalSongs,
      };

  factory _RhythmicTimerState.fromJson(Map<String, dynamic> json) {
    return _RhythmicTimerState(
      songsRemaining: (json['songsRemaining'] as num?)?.toInt() ?? 0,
      currentSongTitle: json['currentSongTitle'] as String?,
      totalSongs: (json['totalSongs'] as num?)?.toInt() ?? 0,
    );
  }
}
