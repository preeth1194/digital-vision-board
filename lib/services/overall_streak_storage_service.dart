import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'logical_date_service.dart';

/// Streak data structure.
final class StreakData {
  final String startDate; // ISO date (YYYY-MM-DD)
  final int count;

  const StreakData({required this.startDate, required this.count});

  Map<String, dynamic> toJson() => {
        'startDate': startDate,
        'count': count,
      };

  factory StreakData.fromJson(Map<String, dynamic> json) => StreakData(
        startDate: json['startDate'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// Service for tracking overall goal streak (maintained if at least one habit is completed per day).
final class OverallStreakStorageService {
  OverallStreakStorageService._();

  static const String _key = 'dv_overall_streak_v1';

  /// Load current streak data.
  static Future<StreakData> loadStreak({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      return const StreakData(startDate: '', count: 0);
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return StreakData.fromJson(json);
    } catch (_) {
      return const StreakData(startDate: '', count: 0);
    }
  }

  /// Save streak data.
  static Future<void> saveStreak(StreakData streak, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(streak.toJson()));
  }

  /// Update streak based on whether at least one habit was completed today.
  /// Returns the updated streak count.
  static Future<int> updateStreak(bool hasCompletionToday, {SharedPreferences? prefs}) async {
    final now = LogicalDateService.now();
    final todayIso = LogicalDateService.toIsoDate(now);
    final current = await loadStreak(prefs: prefs);

    if (!hasCompletionToday) {
      // No completion today - reset streak
      if (current.count > 0) {
        await saveStreak(const StreakData(startDate: '', count: 0), prefs: prefs);
      }
      return 0;
    }

    // Has completion today
    if (current.count == 0) {
      // Starting a new streak
      await saveStreak(StreakData(startDate: todayIso, count: 1), prefs: prefs);
      return 1;
    }

    // Continuing existing streak
    final startDate = LogicalDateService.parseIsoDate(current.startDate);
    final today = LogicalDateService.today();
    final daysDiff = today.difference(startDate).inDays;

    if (daysDiff == current.count) {
      // Streak continues - today is the next day
      await saveStreak(StreakData(startDate: current.startDate, count: current.count + 1), prefs: prefs);
      return current.count + 1;
    } else if (daysDiff < current.count) {
      // This shouldn't happen, but handle gracefully
      // Streak might have been updated incorrectly, reset
      await saveStreak(StreakData(startDate: todayIso, count: 1), prefs: prefs);
      return 1;
    } else {
      // Gap detected - reset streak
      await saveStreak(StreakData(startDate: todayIso, count: 1), prefs: prefs);
      return 1;
    }
  }

  /// Calculate current streak count based on completion history.
  /// This is a helper that can recalculate streak from scratch if needed.
  static Future<int> calculateStreakFromCompletions(
    Set<String> completedDates, {
    SharedPreferences? prefs,
  }) async {
    if (completedDates.isEmpty) {
      await saveStreak(const StreakData(startDate: '', count: 0), prefs: prefs);
      return 0;
    }

    final today = LogicalDateService.today();
    final todayIso = LogicalDateService.toIsoDate(today);
    
    // Sort dates descending
    final sortedDates = completedDates.toList()..sort((a, b) => b.compareTo(a));
    
    // Check if today or yesterday is completed
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayIso = LogicalDateService.toIsoDate(yesterday);
    
    if (!completedDates.contains(todayIso) && !completedDates.contains(yesterdayIso)) {
      // No recent completion - streak is 0
      await saveStreak(const StreakData(startDate: '', count: 0), prefs: prefs);
      return 0;
    }

    // Find consecutive days backwards from today or yesterday
    int streak = 0;
    DateTime checkDate = completedDates.contains(todayIso) ? today : yesterday;
    String checkIso = LogicalDateService.toIsoDate(checkDate);

    while (completedDates.contains(checkIso)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
      checkIso = LogicalDateService.toIsoDate(checkDate);
    }

    if (streak > 0) {
      final startDate = checkDate.add(Duration(days: streak));
      await saveStreak(StreakData(startDate: LogicalDateService.toIsoDate(startDate), count: streak), prefs: prefs);
    } else {
      await saveStreak(const StreakData(startDate: '', count: 0), prefs: prefs);
    }

    return streak;
  }
}
