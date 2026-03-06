class MealPrepWeek {
  final String id;
  final String weekStartDateIso;
  final Map<String, List<String>> recipeIdsByDay;
  final String? notes;
  final List<String> linkedHabitIds;
  final int updatedAtMs;

  const MealPrepWeek({
    required this.id,
    required this.weekStartDateIso,
    this.recipeIdsByDay = const {},
    this.notes,
    this.linkedHabitIds = const [],
    required this.updatedAtMs,
  });

  MealPrepWeek copyWith({
    String? id,
    String? weekStartDateIso,
    Map<String, List<String>>? recipeIdsByDay,
    String? notes,
    bool clearNotes = false,
    List<String>? linkedHabitIds,
    int? updatedAtMs,
  }) {
    return MealPrepWeek(
      id: id ?? this.id,
      weekStartDateIso: weekStartDateIso ?? this.weekStartDateIso,
      recipeIdsByDay: recipeIdsByDay ?? this.recipeIdsByDay,
      notes: clearNotes ? null : (notes ?? this.notes),
      linkedHabitIds: linkedHabitIds ?? this.linkedHabitIds,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekStartDateIso': weekStartDateIso,
    'recipeIdsByDay': recipeIdsByDay,
    'notes': notes,
    'linkedHabitIds': linkedHabitIds,
    'updatedAtMs': updatedAtMs,
  };

  factory MealPrepWeek.fromJson(Map<String, dynamic> json) {
    final rawMap =
        (json['recipeIdsByDay'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final mapped = <String, List<String>>{};
    for (final entry in rawMap.entries) {
      final raw = entry.value;
      if (raw is List) {
        mapped[entry.key] = raw.whereType<String>().toList();
      }
    }
    final linked =
        (json['linkedHabitIds'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    return MealPrepWeek(
      id: json['id'] as String,
      weekStartDateIso: (json['weekStartDateIso'] as String?) ?? '',
      recipeIdsByDay: mapped,
      notes: json['notes'] as String?,
      linkedHabitIds: linked,
      updatedAtMs:
          (json['updatedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
