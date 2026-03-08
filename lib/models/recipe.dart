/// Nutritional macros per serving.
class RecipeMacros {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;
  final double sugarG;

  const RecipeMacros({
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.fiberG = 0,
    this.sodiumMg = 0,
    this.sugarG = 0,
  });

  RecipeMacros copyWith({
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fiberG,
    double? sodiumMg,
    double? sugarG,
  }) {
    return RecipeMacros(
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
    'calories': calories,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'fiberG': fiberG,
    'sodiumMg': sodiumMg,
    'sugarG': sugarG,
  };

  factory RecipeMacros.fromJson(Map<String, dynamic> json) => RecipeMacros(
    calories: (json['calories'] as num?)?.toDouble() ?? 0,
    proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
    carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
    fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
    fiberG: (json['fiberG'] as num?)?.toDouble() ?? 0,
    sodiumMg: (json['sodiumMg'] as num?)?.toDouble() ?? 0,
    sugarG: (json['sugarG'] as num?)?.toDouble() ?? 0,
  );

  bool get isEmpty =>
      calories == 0 &&
      proteinG == 0 &&
      carbsG == 0 &&
      fatG == 0;
}

class Recipe {
  final String id;
  final String title;
  final String cuisine; // e.g. 'Italian', 'Mexican', 'Indian'
  final List<String> ingredients;
  final List<String> methodSteps;
  final List<String> cookingMethods;
  final List<String> dietTags;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int servings;
  final String? notes;
  final String? imageUrl;
  final List<String> linkedHabitIds;
  final int updatedAtMs;

  /// Nutritional macros per serving (optional).
  final RecipeMacros? macros;

  /// True for built-in catalog recipes (cannot be deleted or edited directly).
  final bool isCatalog;

  const Recipe({
    required this.id,
    required this.title,
    this.cuisine = '',
    this.ingredients = const [],
    this.methodSteps = const [],
    this.cookingMethods = const [],
    this.dietTags = const [],
    this.prepTimeMinutes = 0,
    this.cookTimeMinutes = 0,
    this.servings = 1,
    this.notes,
    this.imageUrl,
    this.linkedHabitIds = const [],
    required this.updatedAtMs,
    this.macros,
    this.isCatalog = false,
  });

  Recipe copyWith({
    String? id,
    String? title,
    String? cuisine,
    List<String>? ingredients,
    List<String>? methodSteps,
    List<String>? cookingMethods,
    List<String>? dietTags,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    int? servings,
    String? notes,
    bool clearNotes = false,
    String? imageUrl,
    bool clearImage = false,
    List<String>? linkedHabitIds,
    int? updatedAtMs,
    RecipeMacros? macros,
    bool clearMacros = false,
    bool? isCatalog,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      cuisine: cuisine ?? this.cuisine,
      ingredients: ingredients ?? this.ingredients,
      methodSteps: methodSteps ?? this.methodSteps,
      cookingMethods: cookingMethods ?? this.cookingMethods,
      dietTags: dietTags ?? this.dietTags,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      servings: servings ?? this.servings,
      notes: clearNotes ? null : (notes ?? this.notes),
      imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
      linkedHabitIds: linkedHabitIds ?? this.linkedHabitIds,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      macros: clearMacros ? null : (macros ?? this.macros),
      isCatalog: isCatalog ?? this.isCatalog,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'cuisine': cuisine,
    'ingredients': ingredients,
    'methodSteps': methodSteps,
    'cookingMethods': cookingMethods,
    'dietTags': dietTags,
    'prepTimeMinutes': prepTimeMinutes,
    'cookTimeMinutes': cookTimeMinutes,
    'servings': servings,
    'notes': notes,
    'imageUrl': imageUrl,
    'linkedHabitIds': linkedHabitIds,
    'updatedAtMs': updatedAtMs,
    'macros': macros?.toJson(),
  };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    List<String> stringList(dynamic raw) {
      if (raw is! List) return const <String>[];
      return raw
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final rawMacros = json['macros'];
    final macros = (rawMacros is Map<String, dynamic>)
        ? RecipeMacros.fromJson(rawMacros)
        : null;

    return Recipe(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      cuisine: (json['cuisine'] as String?) ?? '',
      ingredients: stringList(json['ingredients']),
      methodSteps: stringList(json['methodSteps']),
      cookingMethods: stringList(json['cookingMethods']),
      dietTags: stringList(json['dietTags']),
      prepTimeMinutes: (json['prepTimeMinutes'] as num?)?.toInt() ?? 0,
      cookTimeMinutes: (json['cookTimeMinutes'] as num?)?.toInt() ?? 0,
      servings: (json['servings'] as num?)?.toInt() ?? 1,
      notes: json['notes'] as String?,
      imageUrl: json['imageUrl'] as String?,
      linkedHabitIds: stringList(json['linkedHabitIds']),
      updatedAtMs:
          (json['updatedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      macros: macros,
    );
  }
}
