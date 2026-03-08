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
    );
  }
}
