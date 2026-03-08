/// A single food item logged within a calorie entry.
class FoodLogItem {
  final String foodName;
  final double qty; // quantity in servings (1.0 = 1 serving)
  final String qtyUnit; // e.g. 'serving', 'g', 'ml', 'cup'
  final int calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final double? sodiumMg;
  final double? sugarG;

  const FoodLogItem({
    required this.foodName,
    this.qty = 1.0,
    this.qtyUnit = 'serving',
    required this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.sodiumMg,
    this.sugarG,
  });

  bool get hasMacros =>
      proteinG != null || carbsG != null || fatG != null;

  FoodLogItem copyWith({
    String? foodName,
    double? qty,
    String? qtyUnit,
    int? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    double? sodiumMg,
    double? sugarG,
  }) {
    return FoodLogItem(
      foodName: foodName ?? this.foodName,
      qty: qty ?? this.qty,
      qtyUnit: qtyUnit ?? this.qtyUnit,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      fiberG: fiberG ?? this.fiberG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      sugarG: sugarG ?? this.sugarG,
    );
  }

  Map<String, dynamic> toJson() => {
    'foodName': foodName,
    'qty': qty,
    'qtyUnit': qtyUnit,
    'calories': calories,
    if (proteinG != null) 'proteinG': proteinG,
    if (carbsG != null) 'carbsG': carbsG,
    if (fatG != null) 'fatG': fatG,
    if (fiberG != null) 'fiberG': fiberG,
    if (sodiumMg != null) 'sodiumMg': sodiumMg,
    if (sugarG != null) 'sugarG': sugarG,
  };

  factory FoodLogItem.fromJson(Map<String, dynamic> json) => FoodLogItem(
    foodName: (json['foodName'] as String?) ?? '',
    qty: (json['qty'] as num?)?.toDouble() ?? 1.0,
    qtyUnit: (json['qtyUnit'] as String?) ?? 'serving',
    calories: (json['calories'] as num?)?.toInt() ?? 0,
    proteinG: (json['proteinG'] as num?)?.toDouble(),
    carbsG: (json['carbsG'] as num?)?.toDouble(),
    fatG: (json['fatG'] as num?)?.toDouble(),
    fiberG: (json['fiberG'] as num?)?.toDouble(),
    sodiumMg: (json['sodiumMg'] as num?)?.toDouble(),
    sugarG: (json['sugarG'] as num?)?.toDouble(),
  );
}

class CalorieEntry {
  final String dateKey; // 'yyyy-MM-dd'
  final int calories;
  final int goal;
  final List<FoodLogItem> foodItems;

  const CalorieEntry({
    required this.dateKey,
    required this.calories,
    this.goal = 2000,
    this.foodItems = const [],
  });

  CalorieEntry copyWith({
    int? calories,
    int? goal,
    List<FoodLogItem>? foodItems,
  }) => CalorieEntry(
        dateKey: dateKey,
        calories: calories ?? this.calories,
        goal: goal ?? this.goal,
        foodItems: foodItems ?? this.foodItems,
      );

  /// Aggregate macros across all food items that have macro data.
  double get totalProteinG =>
      foodItems.fold(0.0, (acc, f) => acc + (f.proteinG ?? 0));
  double get totalCarbsG =>
      foodItems.fold(0.0, (acc, f) => acc + (f.carbsG ?? 0));
  double get totalFatG =>
      foodItems.fold(0.0, (acc, f) => acc + (f.fatG ?? 0));

  bool get hasMacroData => foodItems.any((f) => f.hasMacros);

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'calories': calories,
        'goal': goal,
        'foodItems': foodItems.map((f) => f.toJson()).toList(),
      };

  factory CalorieEntry.fromJson(Map<String, dynamic> json) {
    final rawItems = json['foodItems'];
    final items = (rawItems is List)
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(FoodLogItem.fromJson)
              .toList()
        : const <FoodLogItem>[];
    return CalorieEntry(
      dateKey: json['dateKey'] as String,
      calories: (json['calories'] as num).toInt(),
      goal: (json['goal'] as num?)?.toInt() ?? 2000,
      foodItems: items,
    );
  }

  static String todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
