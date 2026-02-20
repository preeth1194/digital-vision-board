import 'package:shared_preferences/shared_preferences.dart';

import '../models/challenge.dart';
import 'challenge_storage_service.dart';
import 'habit_storage_service.dart';
import 'logical_date_service.dart';

/// Evaluates daily completion for challenges and handles the restart-on-miss
/// mechanic. Should be called on app open and after habit completions.
class ChallengeProgressService {
  ChallengeProgressService._();

  /// Evaluate completion for all days from the challenge start up to yesterday.
  /// - If ALL habits were completed on a given day, mark it in completedDays.
  /// - If any day between the last completed day and yesterday was missed,
  ///   reset the challenge (restart from today, increment restartCount).
  ///
  /// Returns the updated [Challenge] (also persisted).
  static Future<Challenge> evaluateDay(
    Challenge challenge, {
    SharedPreferences? prefs,
  }) async {
    if (!challenge.isActive) return challenge;

    final p = prefs ?? await SharedPreferences.getInstance();
    final habits = await HabitStorageService.getHabitsByIds(
      challenge.habitIds,
      prefs: p,
    );
    if (habits.isEmpty) return challenge;

    final now = LogicalDateService.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime.parse(challenge.startDate);

    // Only evaluate up to yesterday; today is still in progress.
    final yesterday = today.subtract(const Duration(days: 1));
    if (yesterday.isBefore(startDate)) return challenge;

    final completedSet = challenge.completedDays.toSet();
    var updated = challenge;
    bool missed = false;

    // Walk each day from startDate to yesterday
    var current = startDate;
    while (!current.isAfter(yesterday)) {
      final iso = _toIso(current);

      if (completedSet.contains(iso)) {
        current = current.add(const Duration(days: 1));
        continue;
      }

      // Check if all habits were completed on this day
      final allDone = habits.every((h) => h.isCompletedOnDate(current));
      if (allDone) {
        completedSet.add(iso);
      } else {
        missed = true;
        break;
      }

      current = current.add(const Duration(days: 1));
    }

    if (missed) {
      // Restart: keep habits but reset progress
      updated = updated.copyWith(
        startDate: _toIso(today),
        completedDays: const [],
        restartCount: updated.restartCount + 1,
      );
    } else {
      // Also check today for completed status (bonus — mark eagerly)
      final todayIso = _toIso(today);
      if (!completedSet.contains(todayIso)) {
        final allDoneToday = habits.every((h) => h.isCompletedOnDate(today));
        if (allDoneToday) {
          completedSet.add(todayIso);
        }
      }
      updated = updated.copyWith(
        completedDays: completedSet.toList()..sort(),
      );
    }

    // Check if the challenge is now complete
    if (updated.currentDay >= updated.totalDays) {
      updated = updated.copyWith(isActive: false);
    }

    await ChallengeStorageService.updateChallenge(updated, prefs: p);

    return updated;
  }

  /// Quick check: are all challenge habits completed for today?
  static Future<bool> isAllDoneToday(
    Challenge challenge, {
    SharedPreferences? prefs,
  }) async {
    final habits = await HabitStorageService.getHabitsByIds(
      challenge.habitIds,
      prefs: prefs,
    );
    if (habits.isEmpty) return false;
    final now = LogicalDateService.now();
    final today = DateTime(now.year, now.month, now.day);
    return habits.every((h) => h.isCompletedOnDate(today));
  }

  static String _toIso(DateTime d) {
    final yyyy = d.year.toString().padLeft(4, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
