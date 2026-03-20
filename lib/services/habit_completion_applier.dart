import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import 'coins_service.dart';
import 'habit_storage_service.dart';
import 'logical_date_service.dart';
import 'sync_service.dart';

final class HabitToggleResult {
  final bool applied;
  final bool wasCompleted;
  final bool isCompleted;
  final int coinsDelta;
  final int? newCoinTotal;

  const HabitToggleResult({
    required this.applied,
    required this.wasCompleted,
    required this.isCompleted,
    required this.coinsDelta,
    required this.newCoinTotal,
  });

  const HabitToggleResult.notApplied()
    : applied = false,
      wasCompleted = false,
      isCompleted = false,
      coinsDelta = 0,
      newCoinTotal = null;
}

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
  ///
  /// [boardId] and [componentId] are optional. When omitted they are read from
  /// the persisted [HabitItem] itself (handy for widget-triggered toggles that
  /// only carry a habitId).
  static Future<HabitToggleResult> toggleForToday({
    String? boardId,
    String? componentId,
    required String habitId,
    required String logicalDateIso,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: p);

    final all = await HabitStorageService.loadAll(prefs: p);
    final idx = all.indexWhere((h) => h.id == habitId);
    if (idx == -1) return const HabitToggleResult.notApplied();

    final habit = all[idx];
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return const HabitToggleResult.notApplied();
    final wasCompleted = habit.isCompletedForCurrentPeriod(now);

    final updated = habit.toggleForDate(now);
    all[idx] = updated;
    await HabitStorageService.saveAll(all, prefs: p);

    await SyncService.enqueueHabitCompletion(
      boardId: boardId ?? habit.boardId ?? '',
      componentId: componentId ?? habit.componentId ?? '',
      habitId: habitId,
      logicalDate: logicalDateIso,
      deleted: wasCompleted,
      prefs: p,
    );

    var coinsDelta = 0;
    int? newCoinTotal;

    if (!wasCompleted) {
      newCoinTotal = await CoinsService.addCoins(
        CoinsService.habitCompletionCoins,
        prefs: p,
      );
      coinsDelta += CoinsService.habitCompletionCoins;
      final streakBonusTotal = await CoinsService.checkAndAwardStreakBonus(
        habit.id,
        updated.currentStreak,
        prefs: p,
      );
      if (streakBonusTotal != null) {
        newCoinTotal = streakBonusTotal;
        coinsDelta += CoinsService.streakBonusCoins;
      }
    } else {
      final savedFeedback = habit.feedbackByDate[logicalDateIso];
      final coinsToDeduct =
          savedFeedback?.coinsEarned ?? CoinsService.habitCompletionCoins;
      newCoinTotal = await CoinsService.addCoins(-coinsToDeduct, prefs: p);
      coinsDelta -= coinsToDeduct;
    }

    return HabitToggleResult(
      applied: true,
      wasCompleted: wasCompleted,
      isCompleted: !wasCompleted,
      coinsDelta: coinsDelta,
      newCoinTotal: newCoinTotal,
    );
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

  /// Stores completion feedback for today's logical date.
  static Future<bool> saveFeedbackForToday({
    required String habitId,
    required HabitCompletionFeedback feedback,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: p);

    final all = await HabitStorageService.loadAll(prefs: p);
    final idx = all.indexWhere((h) => h.id == habitId);
    if (idx == -1) return false;

    final habit = all[idx];
    final now = LogicalDateService.now();
    final iso = LogicalDateService.toIsoDate(now);
    final updatedFeedback = Map<String, HabitCompletionFeedback>.from(
      habit.feedbackByDate,
    );
    updatedFeedback[iso] = feedback;
    all[idx] = habit.copyWith(feedbackByDate: updatedFeedback);
    await HabitStorageService.saveAll(all, prefs: p);
    return true;
  }
}
