import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import 'habit_storage_service.dart';
import 'logical_date_service.dart';
import 'sync_service.dart';

/// Marks habits completed in storage + enqueues sync, without requiring UI.
///
/// Used by background geofence/timer completion while the app is alive.
final class HabitCompletionApplier {
  HabitCompletionApplier._();

  static bool _isEligibleToday(HabitItem habit) {
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return false;
    if (habit.isCompletedForCurrentPeriod(now)) return false;
    return true;
  }

  /// Toggle completion for the current logical day and enqueue sync.
  static Future<bool> toggleForToday({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDateIso,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: p);

    final all = await HabitStorageService.loadAll(prefs: p);
    final idx = all.indexWhere((h) => h.id == habitId);
    if (idx == -1) return false;

    final habit = all[idx];
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return false;
    final wasCompleted = habit.isCompletedForCurrentPeriod(now);

    final updated = habit.toggleForDate(now);
    all[idx] = updated;
    await HabitStorageService.saveAll(all, prefs: p);

    await SyncService.enqueueHabitCompletion(
      boardId: boardId,
      componentId: componentId,
      habitId: habitId,
      logicalDate: logicalDateIso,
      deleted: wasCompleted,
      prefs: p,
    );
    return true;
  }

  static Future<bool> markCompleted({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDateIso,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: p);

    final all = await HabitStorageService.loadAll(prefs: p);
    final idx = all.indexWhere((h) => h.id == habitId);
    if (idx == -1) return false;

    final habit = all[idx];
    if (!_isEligibleToday(habit)) return false;

    final now = LogicalDateService.now();
    final updated = habit.toggleForDate(now);
    all[idx] = updated;
    await HabitStorageService.saveAll(all, prefs: p);

    await SyncService.enqueueHabitCompletion(
      boardId: boardId,
      componentId: componentId,
      habitId: habitId,
      logicalDate: logicalDateIso,
      deleted: false,
      prefs: p,
    );
    return true;
  }
}
