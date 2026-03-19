import 'package:shared_preferences/shared_preferences.dart';

import 'coins_service.dart';

final class PresetHabitCreationGateResult {
  final bool canCreate;
  final bool isFreeCreation;
  final int totalCoins;
  final int requiredCoins;

  const PresetHabitCreationGateResult({
    required this.canCreate,
    required this.isFreeCreation,
    required this.totalCoins,
    required this.requiredCoins,
  });
}

final class PresetHabitCreationChargeResult {
  final bool usedFreeCreation;
  final int chargedCoins;
  final int totalCoins;

  const PresetHabitCreationChargeResult({
    required this.usedFreeCreation,
    required this.chargedCoins,
    required this.totalCoins,
  });
}

/// Handles preset habit creation pricing:
/// - First-ever preset creation is free.
/// - Every later preset creation costs coins.
final class PresetHabitCreationService {
  PresetHabitCreationService._();

  static const String _firstFreeUsedKey =
      'preset_habit_creation_first_free_used_v1';

  static Future<PresetHabitCreationGateResult> checkGate({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final freeUsed = p.getBool(_firstFreeUsedKey) ?? false;
    final totalCoins = await CoinsService.getTotalCoins(prefs: p);
    final requiredCoins = CoinsService.presetHabitCreationCoins;
    if (!freeUsed) {
      return PresetHabitCreationGateResult(
        canCreate: true,
        isFreeCreation: true,
        totalCoins: totalCoins,
        requiredCoins: 0,
      );
    }
    return PresetHabitCreationGateResult(
      canCreate: totalCoins >= requiredCoins,
      isFreeCreation: false,
      totalCoins: totalCoins,
      requiredCoins: requiredCoins,
    );
  }

  /// Call only after preset-driven habit creation succeeds.
  static Future<PresetHabitCreationChargeResult> applyChargeForSuccessfulCreate({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final freeUsed = p.getBool(_firstFreeUsedKey) ?? false;
    if (!freeUsed) {
      await p.setBool(_firstFreeUsedKey, true);
      final totalCoins = await CoinsService.getTotalCoins(prefs: p);
      return PresetHabitCreationChargeResult(
        usedFreeCreation: true,
        chargedCoins: 0,
        totalCoins: totalCoins,
      );
    }
    final chargedCoins = CoinsService.presetHabitCreationCoins;
    final totalCoins = await CoinsService.addCoins(-chargedCoins, prefs: p);
    return PresetHabitCreationChargeResult(
      usedFreeCreation: false,
      chargedCoins: chargedCoins,
      totalCoins: totalCoins,
    );
  }
}
