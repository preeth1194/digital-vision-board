class NutritionCalculator {
  NutritionCalculator._();

  static const double activitySedentary = 1.2;
  static const double activityLight = 1.375;
  static const double activityModerate = 1.55;
  static const double activityVeryActive = 1.725;

  static const Map<String, double> activityMultipliers = {
    'sedentary': activitySedentary,
    'light': activityLight,
    'moderate': activityModerate,
    'very_active': activityVeryActive,
  };

  static const double breakfastRatio = 0.25;
  static const double lunchRatio = 0.30;
  static const double dinnerRatio = 0.35;
  static const double snackRatio = 0.10;

  static const Map<String, double> mealSplitRatios = {
    'breakfast': breakfastRatio,
    'lunch': lunchRatio,
    'dinner': dinnerRatio,
    'snack': snackRatio,
  };

  static const int weightLossSoftDelta = -300;
  static const int weightLossAggressiveDelta = -500;
  static const int weightGainDelta = 300;

  static double bmi({
    required double weightKg,
    required double heightCm,
  }) {
    if (weightKg <= 0 || heightCm <= 0) return 0;
    final heightM = heightCm / 100.0;
    if (heightM <= 0) return 0;
    return weightKg / (heightM * heightM);
  }

  static double bmrMifflinStJeor({
    required double weightKg,
    required double heightCm,
    required int ageYears,
    required String gender,
  }) {
    if (weightKg <= 0 || heightCm <= 0 || ageYears <= 0) return 0;
    final base = (10 * weightKg) + (6.25 * heightCm) - (5 * ageYears);
    if (gender == 'male') return base + 5;
    if (gender == 'female') return base - 161;
    return base - 78;
  }

  static double maintenanceCalories({
    required double bmr,
    required String activityLevel,
  }) {
    if (bmr <= 0) return 0;
    final multiplier = activityMultipliers[activityLevel] ?? activityModerate;
    return bmr * multiplier;
  }

  static int withCalorieAdjustment(int maintenance, int delta) {
    return (maintenance + delta).clamp(1000, 6000).toInt();
  }

  static Map<String, int> slotBudgets({
    required int targetCalories,
    Map<String, double>? ratios,
  }) {
    final resolved = ratios ?? mealSplitRatios;
    final breakfast = (targetCalories * (resolved['breakfast'] ?? breakfastRatio))
        .round();
    final lunch = (targetCalories * (resolved['lunch'] ?? lunchRatio)).round();
    final dinner = (targetCalories * (resolved['dinner'] ?? dinnerRatio)).round();
    final snack = targetCalories - breakfast - lunch - dinner;
    return {
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'snack': snack.clamp(0, targetCalories),
    };
  }
}
