class MealPrepWeek {
  final String id;
  final String weekStartDateIso;
  final Map<String, Map<String, String>> recipeIdByDayAndSlot;
  final Map<String, List<String>> recipeIdsByDay;
  final String? notes;
  final List<String> linkedHabitIds;
  final int? bmiX10;
  final int? bmr;
  final int? maintenanceCalories;
  final int? targetCalories;
  final String? activityLevel;
  final String? dietPreference;
  final List<String> allergies;
  final int? generatedAtMs;
  final int updatedAtMs;

  const MealPrepWeek({
    required this.id,
    required this.weekStartDateIso,
    this.recipeIdByDayAndSlot = const {},
    this.recipeIdsByDay = const {},
    this.notes,
    this.linkedHabitIds = const [],
    this.bmiX10,
    this.bmr,
    this.maintenanceCalories,
    this.targetCalories,
    this.activityLevel,
    this.dietPreference,
    this.allergies = const [],
    this.generatedAtMs,
    required this.updatedAtMs,
  });

  MealPrepWeek copyWith({
    String? id,
    String? weekStartDateIso,
    Map<String, Map<String, String>>? recipeIdByDayAndSlot,
    Map<String, List<String>>? recipeIdsByDay,
    String? notes,
    bool clearNotes = false,
    List<String>? linkedHabitIds,
    int? bmiX10,
    bool clearBmiX10 = false,
    int? bmr,
    bool clearBmr = false,
    int? maintenanceCalories,
    bool clearMaintenanceCalories = false,
    int? targetCalories,
    bool clearTargetCalories = false,
    String? activityLevel,
    bool clearActivityLevel = false,
    String? dietPreference,
    bool clearDietPreference = false,
    List<String>? allergies,
    int? generatedAtMs,
    bool clearGeneratedAtMs = false,
    int? updatedAtMs,
  }) {
    return MealPrepWeek(
      id: id ?? this.id,
      weekStartDateIso: weekStartDateIso ?? this.weekStartDateIso,
      recipeIdByDayAndSlot: recipeIdByDayAndSlot ?? this.recipeIdByDayAndSlot,
      recipeIdsByDay: recipeIdsByDay ?? this.recipeIdsByDay,
      notes: clearNotes ? null : (notes ?? this.notes),
      linkedHabitIds: linkedHabitIds ?? this.linkedHabitIds,
      bmiX10: clearBmiX10 ? null : (bmiX10 ?? this.bmiX10),
      bmr: clearBmr ? null : (bmr ?? this.bmr),
      maintenanceCalories: clearMaintenanceCalories
          ? null
          : (maintenanceCalories ?? this.maintenanceCalories),
      targetCalories: clearTargetCalories
          ? null
          : (targetCalories ?? this.targetCalories),
      activityLevel: clearActivityLevel
          ? null
          : (activityLevel ?? this.activityLevel),
      dietPreference: clearDietPreference
          ? null
          : (dietPreference ?? this.dietPreference),
      allergies: allergies ?? this.allergies,
      generatedAtMs: clearGeneratedAtMs
          ? null
          : (generatedAtMs ?? this.generatedAtMs),
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekStartDateIso': weekStartDateIso,
    'recipeIdByDayAndSlot': recipeIdByDayAndSlot,
    'recipeIdsByDay': recipeIdsByDay,
    'notes': notes,
    'linkedHabitIds': linkedHabitIds,
    'bmiX10': bmiX10,
    'bmr': bmr,
    'maintenanceCalories': maintenanceCalories,
    'targetCalories': targetCalories,
    'activityLevel': activityLevel,
    'dietPreference': dietPreference,
    'allergies': allergies,
    'generatedAtMs': generatedAtMs,
    'updatedAtMs': updatedAtMs,
  };

  factory MealPrepWeek.fromJson(Map<String, dynamic> json) {
    final legacyRawMap =
        (json['recipeIdsByDay'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final legacyMapped = <String, List<String>>{};
    for (final entry in legacyRawMap.entries) {
      final raw = entry.value;
      if (raw is List) {
        legacyMapped[entry.key] = raw.whereType<String>().toList();
      }
    }

    final rawSlotMap =
        (json['recipeIdByDayAndSlot'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final slotMapped = <String, Map<String, String>>{};
    for (final dayEntry in rawSlotMap.entries) {
      final rawSlots = dayEntry.value;
      if (rawSlots is! Map) continue;
      final slotMap = <String, String>{};
      for (final slotEntry in rawSlots.entries) {
        final key = slotEntry.key.toString().trim().toLowerCase();
        final value = slotEntry.value?.toString().trim() ?? '';
        if (key.isEmpty || value.isEmpty) continue;
        slotMap[key] = value;
      }
      if (slotMap.isNotEmpty) {
        slotMapped[dayEntry.key] = slotMap;
      }
    }
    final migratedSlotMapped = slotMapped.isNotEmpty
        ? slotMapped
        : _migrateLegacyRecipes(legacyMapped);

    final linked =
        (json['linkedHabitIds'] as List<dynamic>?)
            ?.whereType<String>()
            .toList() ??
        const <String>[];
    final allergies =
        (json['allergies'] as List<dynamic>?)
            ?.whereType<String>()
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];
    return MealPrepWeek(
      id: json['id'] as String,
      weekStartDateIso: (json['weekStartDateIso'] as String?) ?? '',
      recipeIdByDayAndSlot: migratedSlotMapped,
      recipeIdsByDay: legacyMapped,
      notes: json['notes'] as String?,
      linkedHabitIds: linked,
      bmiX10: (json['bmiX10'] as num?)?.toInt(),
      bmr: (json['bmr'] as num?)?.toInt(),
      maintenanceCalories: (json['maintenanceCalories'] as num?)?.toInt(),
      targetCalories: (json['targetCalories'] as num?)?.toInt(),
      activityLevel: (json['activityLevel'] as String?)?.trim(),
      dietPreference: (json['dietPreference'] as String?)?.trim(),
      allergies: allergies,
      generatedAtMs: (json['generatedAtMs'] as num?)?.toInt(),
      updatedAtMs:
          (json['updatedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Map<String, Map<String, String>> _migrateLegacyRecipes(
    Map<String, List<String>> recipeIdsByDay,
  ) {
    const slotOrder = <String>['breakfast', 'lunch', 'dinner', 'snack'];
    final migrated = <String, Map<String, String>>{};
    for (final entry in recipeIdsByDay.entries) {
      final ids = entry.value;
      if (ids.isEmpty) continue;
      final daySlots = <String, String>{};
      for (int i = 0; i < ids.length && i < slotOrder.length; i++) {
        final recipeId = ids[i].trim();
        if (recipeId.isEmpty) continue;
        daySlots[slotOrder[i]] = recipeId;
      }
      if (daySlots.isNotEmpty) migrated[entry.key] = daySlots;
    }
    return migrated;
  }
}
