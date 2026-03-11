import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../models/habit_item.dart';
import '../widgets/rituals/habit_completion_sheet.dart';
import 'coins_service.dart';
import 'habit_completion_applier.dart';
import 'habit_storage_service.dart';
import 'logical_date_service.dart';

/// Routes notification taps to the appropriate UI (e.g. completion sheet).
final class NotificationRoutingService {
  NotificationRoutingService._();

  static Future<void> handleGeofenceCompletionTap({
    required String boardId,
    required String componentId,
    required String habitId,
  }) async {
    final ctx = DigitalVisionBoardApp.navigatorKey.currentContext;
    if (ctx == null) return;

    final prefs = await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: prefs);

    final habits = await HabitStorageService.loadAll(prefs: prefs);
    final idx = habits.indexWhere((h) => h.id == habitId);
    if (idx == -1) return;
    final habit = habits[idx];

    if (!ctx.mounted) return;

    final result = await showHabitCompletionSheet(
      ctx,
      habit: habit,
      baseCoins: CoinsService.habitCompletionCoins,
      isFullHabit: true,
    );

    if (result == null) return;

    final feedback = HabitCompletionFeedback(
      rating: result.mood ?? 0,
      note: result.note,
      coinsEarned: result.coinsEarned,
      trackingValue: result.trackingValue,
      stepSetsByStepId: result.stepSetsById,
      stepRepsByStepId: result.stepRepsById,
    );
    await HabitCompletionApplier.saveFeedbackForToday(
      habitId: habitId,
      feedback: feedback,
      prefs: prefs,
    );

    await CoinsService.addCoins(result.coinsEarned, prefs: prefs);
  }
}
