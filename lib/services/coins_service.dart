import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing user coin balance.
/// Coins are awarded for completing habits and coping plans.
class CoinsService {
  static const String _coinsKey = 'user_total_coins';
  static const String _lastStreakBonusKey = 'last_streak_bonus_date';

  // Coin award amounts
  static const int copingPlanCoins = 1;
  static const int habitCompletionCoins = 2;
  static const int streakBonusCoins = 5;
  static const int streakBonusThreshold = 7; // Every 7 days
  static const int maxStepBonus = 5;
  static const int mediaBonusCoins = 2;
  static const int puzzle4x4Coins = 2;
  static const int puzzle8x8Coins = 5;

  /// Get the total coins accumulated by the user.
  static Future<int> getTotalCoins({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getInt(_coinsKey) ?? 0;
  }

  /// Add coins to the user's balance.
  /// Returns the new total. Negative amounts can be used to deduct coins.
  /// The balance will never go below zero.
  static Future<int> addCoins(int amount, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final current = p.getInt(_coinsKey) ?? 0;
    final newTotal = (current + amount).clamp(0, double.maxFinite.toInt());
    await p.setInt(_coinsKey, newTotal);
    return newTotal;
  }

  /// Award coins for completing a coping plan.
  static Future<int> awardCopingPlanCompletion({SharedPreferences? prefs}) async {
    return addCoins(copingPlanCoins, prefs: prefs);
  }

  /// Award coins for completing a habit.
  static Future<int> awardHabitCompletion({SharedPreferences? prefs}) async {
    return addCoins(habitCompletionCoins, prefs: prefs);
  }

  /// Check and award streak bonus if applicable.
  /// Should be called when a habit reaches a streak milestone.
  static Future<int?> checkAndAwardStreakBonus(
    String habitId,
    int currentStreak, {
    SharedPreferences? prefs,
  }) async {
    if (currentStreak <= 0 || currentStreak % streakBonusThreshold != 0) {
      return null;
    }

    final p = prefs ?? await SharedPreferences.getInstance();
    final key = '${_lastStreakBonusKey}_${habitId}_$currentStreak';
    final alreadyAwarded = p.getBool(key) ?? false;

    if (alreadyAwarded) return null;

    await p.setBool(key, true);
    return addCoins(streakBonusCoins, prefs: p);
  }

  /// Get coins earned for a specific completion type.
  static int getCoinsForCompletionType(CompletionType type) {
    switch (type) {
      case CompletionType.copingPlan:
        return copingPlanCoins;
      case CompletionType.habit:
        return habitCompletionCoins;
    }
  }

  /// Scaled bonus based on what fraction of action steps were completed.
  /// Returns 0 when there are no steps or none were completed.
  static int calculateStepBonus(int completedSteps, int totalSteps) {
    if (totalSteps <= 0 || completedSteps <= 0) return 0;
    return (completedSteps / totalSteps * maxStepBonus).round();
  }

  /// Flat bonus awarded when the user attaches any media (voice or photo).
  static int calculateMediaBonus(bool hasMedia) {
    return hasMedia ? mediaBonusCoins : 0;
  }

  /// Award coins for completing a puzzle based on grid size.
  static Future<int> awardPuzzleCompletion(int gridSize, {SharedPreferences? prefs}) async {
    final coins = gridSize >= 8 ? puzzle8x8Coins : puzzle4x4Coins;
    return addCoins(coins, prefs: prefs);
  }

  static int coinsForPuzzleGrid(int gridSize) {
    return gridSize >= 8 ? puzzle8x8Coins : puzzle4x4Coins;
  }
}

/// Type of completion for coin rewards.
enum CompletionType {
  copingPlan,
  habit,
}
