class SkincarePlannerRow {
  final String id;
  final String task;
  final String productUsed;
  final String? note;

  const SkincarePlannerRow({
    required this.id,
    required this.task,
    required this.productUsed,
    this.note,
  });

  SkincarePlannerRow copyWith({
    String? id,
    String? task,
    String? productUsed,
    String? note,
    bool clearNote = false,
  }) {
    return SkincarePlannerRow(
      id: id ?? this.id,
      task: task ?? this.task,
      productUsed: productUsed ?? this.productUsed,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'task': task,
    'productUsed': productUsed,
    'note': note,
  };

  factory SkincarePlannerRow.fromJson(Map<String, dynamic> json) {
    return SkincarePlannerRow(
      id: (json['id'] as String?) ?? '',
      task: (json['task'] as String?) ?? '',
      productUsed: (json['productUsed'] as String?) ?? '',
      note: json['note'] as String?,
    );
  }
}

class SkincareRoutineSet {
  final String id;
  final String name;
  final List<SkincarePlannerRow> rows;

  const SkincareRoutineSet({
    required this.id,
    required this.name,
    this.rows = const [],
  });

  SkincareRoutineSet copyWith({
    String? id,
    String? name,
    List<SkincarePlannerRow>? rows,
  }) {
    return SkincareRoutineSet(
      id: id ?? this.id,
      name: name ?? this.name,
      rows: rows ?? this.rows,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'rows': rows.map((e) => e.toJson()).toList(),
  };

  factory SkincareRoutineSet.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SkincarePlannerRow.fromJson)
        .toList();
    return SkincareRoutineSet(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Routine Set',
      rows: rows,
    );
  }
}

class SkincareWeeklyDayPlan {
  final String dayKey;
  final String? morningSourceId;
  final String? eveningSourceId;
  final String? customTask;
  final String? customProduct;

  const SkincareWeeklyDayPlan({
    required this.dayKey,
    this.morningSourceId,
    this.eveningSourceId,
    this.customTask,
    this.customProduct,
  });

  SkincareWeeklyDayPlan copyWith({
    String? dayKey,
    String? morningSourceId,
    bool clearMorningSourceId = false,
    String? eveningSourceId,
    bool clearEveningSourceId = false,
    String? customTask,
    bool clearCustomTask = false,
    String? customProduct,
    bool clearCustomProduct = false,
  }) {
    return SkincareWeeklyDayPlan(
      dayKey: dayKey ?? this.dayKey,
      morningSourceId: clearMorningSourceId
          ? null
          : (morningSourceId ?? this.morningSourceId),
      eveningSourceId: clearEveningSourceId
          ? null
          : (eveningSourceId ?? this.eveningSourceId),
      customTask: clearCustomTask ? null : (customTask ?? this.customTask),
      customProduct: clearCustomProduct
          ? null
          : (customProduct ?? this.customProduct),
    );
  }

  Map<String, dynamic> toJson() => {
    'dayKey': dayKey,
    'morningSourceId': morningSourceId,
    'eveningSourceId': eveningSourceId,
    'customTask': customTask,
    'customProduct': customProduct,
  };

  factory SkincareWeeklyDayPlan.fromJson(Map<String, dynamic> json) {
    return SkincareWeeklyDayPlan(
      dayKey: (json['dayKey'] as String?) ?? '',
      morningSourceId: json['morningSourceId'] as String?,
      eveningSourceId: json['eveningSourceId'] as String?,
      customTask: json['customTask'] as String?,
      customProduct: json['customProduct'] as String?,
    );
  }
}

class SkincareMonthlyTrackerEntry {
  final String weekLabel;
  final String skinConcern;
  final String weeklyPlanId;

  const SkincareMonthlyTrackerEntry({
    required this.weekLabel,
    required this.skinConcern,
    required this.weeklyPlanId,
  });

  SkincareMonthlyTrackerEntry copyWith({
    String? weekLabel,
    String? skinConcern,
    String? weeklyPlanId,
  }) {
    return SkincareMonthlyTrackerEntry(
      weekLabel: weekLabel ?? this.weekLabel,
      skinConcern: skinConcern ?? this.skinConcern,
      weeklyPlanId: weeklyPlanId ?? this.weeklyPlanId,
    );
  }

  Map<String, dynamic> toJson() => {
    'weekLabel': weekLabel,
    'skinConcern': skinConcern,
    'weeklyPlanId': weeklyPlanId,
  };

  factory SkincareMonthlyTrackerEntry.fromJson(Map<String, dynamic> json) {
    return SkincareMonthlyTrackerEntry(
      weekLabel: (json['weekLabel'] as String?) ?? '',
      skinConcern: (json['skinConcern'] as String?) ?? '',
      weeklyPlanId: (json['weeklyPlanId'] as String?) ?? 'default_weekly_1',
    );
  }
}

class SkincareWeeklyPlan {
  final String id;
  final String name;
  final Map<String, SkincareWeeklyDayPlan> weeklyPlanByDay;

  const SkincareWeeklyPlan({
    required this.id,
    required this.name,
    this.weeklyPlanByDay = const {},
  });

  SkincareWeeklyPlan copyWith({
    String? id,
    String? name,
    Map<String, SkincareWeeklyDayPlan>? weeklyPlanByDay,
  }) {
    return SkincareWeeklyPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      weeklyPlanByDay: weeklyPlanByDay ?? this.weeklyPlanByDay,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'weeklyPlanByDay': weeklyPlanByDay.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory SkincareWeeklyPlan.fromJson(Map<String, dynamic> json) {
    final weeklyRaw =
        (json['weeklyPlanByDay'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final weekly = <String, SkincareWeeklyDayPlan>{};
    for (final day in SkincarePlanner.weekDays) {
      final raw = weeklyRaw[day];
      if (raw is Map<String, dynamic>) {
        weekly[day] = SkincareWeeklyDayPlan.fromJson(raw);
      } else {
        weekly[day] = SkincareWeeklyDayPlan(dayKey: day);
      }
    }
    return SkincareWeeklyPlan(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? 'Weekly Plan',
      weeklyPlanByDay: weekly,
    );
  }
}

class SkincarePlanner {
  final String id;
  final String title;
  final List<SkincareRoutineSet> morningRoutineSets;
  final List<SkincareRoutineSet> eveningRoutineSets;
  final String selectedMorningSetId;
  final String selectedEveningSetId;
  final bool morningRoutineEnabled;
  final bool eveningRoutineEnabled;
  final List<SkincareWeeklyPlan> weeklyPlans;
  final String selectedWeeklyPlanId;
  final List<String> productsToBuy;
  final String notes;
  final List<SkincareMonthlyTrackerEntry> monthlyTracker;
  final bool aiNoticeDismissed;
  final String selectedPresetId;
  final int updatedAtMs;

  const SkincarePlanner({
    required this.id,
    required this.title,
    this.morningRoutineSets = const [],
    this.eveningRoutineSets = const [],
    this.selectedMorningSetId = 'morning_set_1',
    this.selectedEveningSetId = 'evening_set_1',
    this.morningRoutineEnabled = true,
    this.eveningRoutineEnabled = true,
    this.weeklyPlans = const [],
    this.selectedWeeklyPlanId = 'default_weekly_1',
    this.productsToBuy = const [],
    this.notes = '',
    this.monthlyTracker = const [],
    this.aiNoticeDismissed = false,
    this.selectedPresetId = 'default_weekly',
    required this.updatedAtMs,
  });

  static const List<String> weekDays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  static String dayLabel(String dayKey) {
    if (dayKey.isEmpty) return dayKey;
    return dayKey[0].toUpperCase() + dayKey.substring(1);
  }

  SkincareRoutineSet get selectedMorningSet {
    for (final set in morningRoutineSets) {
      if (set.id == selectedMorningSetId) return set;
    }
    return morningRoutineSets.first;
  }

  SkincareRoutineSet get selectedEveningSet {
    for (final set in eveningRoutineSets) {
      if (set.id == selectedEveningSetId) return set;
    }
    return eveningRoutineSets.first;
  }

  List<SkincarePlannerRow> get morningRows => selectedMorningSet.rows;
  List<SkincarePlannerRow> get eveningRows => selectedEveningSet.rows;

  static Map<String, SkincareWeeklyDayPlan> blankWeeklyDayMap() {
    return {
      for (final d in weekDays) d: SkincareWeeklyDayPlan(dayKey: d),
    };
  }

  static Map<String, SkincareWeeklyDayPlan> defaultWeeklyDayMap() {
    return {
      'monday': const SkincareWeeklyDayPlan(
        dayKey: 'monday',
        morningSourceId: 'morning_set_1',
        eveningSourceId: 'evening_set_1',
      ),
      'tuesday': const SkincareWeeklyDayPlan(
        dayKey: 'tuesday',
        morningSourceId: 'morning_set_1',
        eveningSourceId: 'evening_set_1',
      ),
      'wednesday': const SkincareWeeklyDayPlan(
        dayKey: 'wednesday',
        morningSourceId: 'morning_set_1',
        eveningSourceId: 'evening_set_1',
      ),
      'thursday': const SkincareWeeklyDayPlan(
        dayKey: 'thursday',
        morningSourceId: 'morning_set_1',
        eveningSourceId: 'evening_set_1',
      ),
      'friday': const SkincareWeeklyDayPlan(
        dayKey: 'friday',
        morningSourceId: 'morning_set_1',
        eveningSourceId: 'evening_set_1',
      ),
      'saturday': const SkincareWeeklyDayPlan(
        dayKey: 'saturday',
        morningSourceId: 'morning_set_1',
        eveningSourceId: 'evening_set_1',
      ),
      'sunday': const SkincareWeeklyDayPlan(
        dayKey: 'sunday',
        morningSourceId: 'morning_set_1',
        eveningSourceId: 'evening_set_1',
      ),
    };
  }

  factory SkincarePlanner.defaultSeed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final morningRows = <SkincarePlannerRow>[
      const SkincarePlannerRow(id: 'am_1', task: 'Cleanser', productUsed: ''),
      const SkincarePlannerRow(id: 'am_2', task: 'Toner', productUsed: ''),
      const SkincarePlannerRow(id: 'am_3', task: 'Serum', productUsed: ''),
      const SkincarePlannerRow(id: 'am_4', task: 'Moisturizer', productUsed: ''),
      const SkincarePlannerRow(
        id: 'am_5',
        task: 'Sunscreen (SPF 30+)',
        productUsed: '',
      ),
    ];
    final eveningRows = <SkincarePlannerRow>[
      const SkincarePlannerRow(
        id: 'pm_mon',
        task: 'Exfoliation',
        productUsed: '',
        note: '1-2x a week',
      ),
      const SkincarePlannerRow(
        id: 'pm_tue',
        task: 'Cleansing',
        productUsed: '',
        note: 'Sheet mask / Overnight gel',
      ),
      const SkincarePlannerRow(
        id: 'pm_thu',
        task: 'Hydrating Mask',
        productUsed: '',
        note: 'Great for oily skin',
      ),
      const SkincarePlannerRow(
        id: 'pm_fri',
        task: 'Clay Mask / Detox',
        productUsed: '',
        note: 'Great for oily skin',
      ),
    ];
    const defaultWeeklyPlanId = 'default_weekly_1';
    return SkincarePlanner(
      id: 'skincare_default_planner',
      title: 'My Skincare Presets',
      morningRoutineSets: [
        SkincareRoutineSet(
          id: 'morning_set_1',
          name: 'Default Morning',
          rows: morningRows,
        ),
      ],
      eveningRoutineSets: [
        SkincareRoutineSet(
          id: 'evening_set_1',
          name: 'Default Evening',
          rows: eveningRows,
        ),
      ],
      selectedMorningSetId: 'morning_set_1',
      selectedEveningSetId: 'evening_set_1',
      morningRoutineEnabled: true,
      eveningRoutineEnabled: true,
      weeklyPlans: const [
        SkincareWeeklyPlan(
          id: defaultWeeklyPlanId,
          name: 'Default Weekly Plan',
          weeklyPlanByDay: {
            'monday': SkincareWeeklyDayPlan(
              dayKey: 'monday',
              morningSourceId: 'morning_set_1',
              eveningSourceId: 'evening_set_1',
            ),
            'tuesday': SkincareWeeklyDayPlan(
              dayKey: 'tuesday',
              morningSourceId: 'morning_set_1',
              eveningSourceId: 'evening_set_1',
            ),
            'wednesday': SkincareWeeklyDayPlan(
              dayKey: 'wednesday',
              morningSourceId: 'morning_set_1',
              eveningSourceId: 'evening_set_1',
            ),
            'thursday': SkincareWeeklyDayPlan(
              dayKey: 'thursday',
              morningSourceId: 'morning_set_1',
              eveningSourceId: 'evening_set_1',
            ),
            'friday': SkincareWeeklyDayPlan(
              dayKey: 'friday',
              morningSourceId: 'morning_set_1',
              eveningSourceId: 'evening_set_1',
            ),
            'saturday': SkincareWeeklyDayPlan(
              dayKey: 'saturday',
              morningSourceId: 'morning_set_1',
              eveningSourceId: 'evening_set_1',
            ),
            'sunday': SkincareWeeklyDayPlan(
              dayKey: 'sunday',
              morningSourceId: 'morning_set_1',
              eveningSourceId: 'evening_set_1',
            ),
          },
        ),
      ],
      selectedWeeklyPlanId: defaultWeeklyPlanId,
      productsToBuy: const ['Cleanser', 'Sunscreen', 'Treatment', 'Mask'],
      notes:
          'Drink more water\nChange pillowcase weekly\nDo not skip sunscreen\nAvoid touching your face',
      monthlyTracker: const [
        SkincareMonthlyTrackerEntry(
          weekLabel: 'Week 1',
          skinConcern: '',
          weeklyPlanId: defaultWeeklyPlanId,
        ),
        SkincareMonthlyTrackerEntry(
          weekLabel: 'Week 2',
          skinConcern: '',
          weeklyPlanId: defaultWeeklyPlanId,
        ),
        SkincareMonthlyTrackerEntry(
          weekLabel: 'Week 3',
          skinConcern: '',
          weeklyPlanId: defaultWeeklyPlanId,
        ),
      ],
      updatedAtMs: now,
    );
  }

  SkincarePlanner copyWith({
    String? id,
    String? title,
    List<SkincareRoutineSet>? morningRoutineSets,
    List<SkincareRoutineSet>? eveningRoutineSets,
    String? selectedMorningSetId,
    String? selectedEveningSetId,
    bool? morningRoutineEnabled,
    bool? eveningRoutineEnabled,
    List<SkincareWeeklyPlan>? weeklyPlans,
    String? selectedWeeklyPlanId,
    List<String>? productsToBuy,
    String? notes,
    List<SkincareMonthlyTrackerEntry>? monthlyTracker,
    bool? aiNoticeDismissed,
    String? selectedPresetId,
    int? updatedAtMs,
  }) {
    return SkincarePlanner(
      id: id ?? this.id,
      title: title ?? this.title,
      morningRoutineSets: morningRoutineSets ?? this.morningRoutineSets,
      eveningRoutineSets: eveningRoutineSets ?? this.eveningRoutineSets,
      selectedMorningSetId: selectedMorningSetId ?? this.selectedMorningSetId,
      selectedEveningSetId: selectedEveningSetId ?? this.selectedEveningSetId,
      morningRoutineEnabled: morningRoutineEnabled ?? this.morningRoutineEnabled,
      eveningRoutineEnabled: eveningRoutineEnabled ?? this.eveningRoutineEnabled,
      weeklyPlans: weeklyPlans ?? this.weeklyPlans,
      selectedWeeklyPlanId: selectedWeeklyPlanId ?? this.selectedWeeklyPlanId,
      productsToBuy: productsToBuy ?? this.productsToBuy,
      notes: notes ?? this.notes,
      monthlyTracker: monthlyTracker ?? this.monthlyTracker,
      aiNoticeDismissed: aiNoticeDismissed ?? this.aiNoticeDismissed,
      selectedPresetId: selectedPresetId ?? this.selectedPresetId,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'morningRoutineSets': morningRoutineSets.map((e) => e.toJson()).toList(),
    'eveningRoutineSets': eveningRoutineSets.map((e) => e.toJson()).toList(),
    'selectedMorningSetId': selectedMorningSetId,
    'selectedEveningSetId': selectedEveningSetId,
    'morningRoutineEnabled': morningRoutineEnabled,
    'eveningRoutineEnabled': eveningRoutineEnabled,
    'weeklyPlans': weeklyPlans.map((e) => e.toJson()).toList(),
    'selectedWeeklyPlanId': selectedWeeklyPlanId,
    'productsToBuy': productsToBuy,
    'notes': notes,
    'monthlyTracker': monthlyTracker.map((e) => e.toJson()).toList(),
    'aiNoticeDismissed': aiNoticeDismissed,
    'selectedPresetId': selectedPresetId,
    'updatedAtMs': updatedAtMs,
  };

  factory SkincarePlanner.fromJson(Map<String, dynamic> json) {
    final legacyMorning = (json['morningRows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SkincarePlannerRow.fromJson)
        .toList();
    final legacyEvening = (json['eveningRows'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SkincarePlannerRow.fromJson)
        .toList();
    final morningSets = (json['morningRoutineSets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SkincareRoutineSet.fromJson)
        .toList();
    final eveningSets = (json['eveningRoutineSets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SkincareRoutineSet.fromJson)
        .toList();
    final products = (json['productsToBuy'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList();
    final monthly = (json['monthlyTracker'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SkincareMonthlyTrackerEntry.fromJson)
        .toList();
    final weeklyPlansRaw = (json['weeklyPlans'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SkincareWeeklyPlan.fromJson)
        .toList();

    List<SkincareRoutineSet> resolvedMorningSets = morningSets;
    if (resolvedMorningSets.isEmpty) {
      resolvedMorningSets = [
        SkincareRoutineSet(
          id: 'morning_set_1',
          name: 'Default Morning',
          rows: legacyMorning,
        ),
      ];
    }
    List<SkincareRoutineSet> resolvedEveningSets = eveningSets;
    if (resolvedEveningSets.isEmpty) {
      resolvedEveningSets = [
        SkincareRoutineSet(
          id: 'evening_set_1',
          name: 'Default Evening',
          rows: legacyEvening,
        ),
      ];
    }
    final morningSetIds = resolvedMorningSets.map((e) => e.id).toSet();
    final eveningSetIds = resolvedEveningSets.map((e) => e.id).toSet();
    final selectedMorningSetId =
        (json['selectedMorningSetId'] as String?) ??
        resolvedMorningSets.first.id;
    final selectedEveningSetId =
        (json['selectedEveningSetId'] as String?) ??
        resolvedEveningSets.first.id;
    bool morningRoutineEnabled =
        (json['morningRoutineEnabled'] as bool?) ?? true;
    bool eveningRoutineEnabled =
        (json['eveningRoutineEnabled'] as bool?) ?? true;
    if (!morningRoutineEnabled && !eveningRoutineEnabled) {
      morningRoutineEnabled = true;
    }

    // Backward-compatible migration from old single weekly plan shape.
    List<SkincareWeeklyPlan> resolvedWeeklyPlans = weeklyPlansRaw;
    if (resolvedWeeklyPlans.isEmpty) {
      final weeklyRaw =
          (json['weeklyPlanByDay'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final weekly = <String, SkincareWeeklyDayPlan>{};
      for (final day in weekDays) {
        final raw = weeklyRaw[day];
        if (raw is Map<String, dynamic>) {
          weekly[day] = SkincareWeeklyDayPlan.fromJson(raw);
        } else {
          weekly[day] = SkincareWeeklyDayPlan(dayKey: day);
        }
      }
      resolvedWeeklyPlans = [
        SkincareWeeklyPlan(
          id: 'default_weekly_1',
          name:
              (json['weeklyPlanName'] as String?)?.trim().isNotEmpty == true
              ? (json['weeklyPlanName'] as String).trim()
              : 'Default Weekly Plan',
          weeklyPlanByDay: weekly,
        ),
      ];
    }

    final selectedWeeklyPlanId =
        (json['selectedWeeklyPlanId'] as String?) ??
        resolvedWeeklyPlans.first.id;
    // Ensure day mappings target existing routine set ids.
    resolvedWeeklyPlans = resolvedWeeklyPlans.map((plan) {
      final nextMap = <String, SkincareWeeklyDayPlan>{};
      for (final day in weekDays) {
        final dayPlan =
            plan.weeklyPlanByDay[day] ?? SkincareWeeklyDayPlan(dayKey: day);
        nextMap[day] = dayPlan.copyWith(
          morningSourceId: !morningRoutineEnabled
              ? null
              : ((dayPlan.morningSourceId == null ||
                        (dayPlan.morningSourceId ?? '').trim().isEmpty)
                    ? null
                    : (morningSetIds.contains(dayPlan.morningSourceId)
                          ? dayPlan.morningSourceId
                          : resolvedMorningSets.first.id)),
          eveningSourceId: !eveningRoutineEnabled
              ? null
              : ((dayPlan.eveningSourceId == null ||
                        (dayPlan.eveningSourceId ?? '').trim().isEmpty)
                    ? null
                    : (eveningSetIds.contains(dayPlan.eveningSourceId)
                          ? dayPlan.eveningSourceId
                          : resolvedEveningSets.first.id)),
        );
      }
      return plan.copyWith(weeklyPlanByDay: nextMap);
    }).toList();

    final weeklyPlanIds = resolvedWeeklyPlans.map((e) => e.id).toSet();
    final resolvedMonthly = monthly
        .map(
          (entry) => weeklyPlanIds.contains(entry.weeklyPlanId)
              ? entry
              : entry.copyWith(weeklyPlanId: selectedWeeklyPlanId),
        )
        .toList();

    return SkincarePlanner(
      id: (json['id'] as String?) ?? 'skincare_default_planner',
      title: (json['title'] as String?) ?? 'My Skincare Presets',
      morningRoutineSets: resolvedMorningSets,
      eveningRoutineSets: resolvedEveningSets,
      selectedMorningSetId: morningSetIds.contains(selectedMorningSetId)
          ? selectedMorningSetId
          : resolvedMorningSets.first.id,
      selectedEveningSetId: eveningSetIds.contains(selectedEveningSetId)
          ? selectedEveningSetId
          : resolvedEveningSets.first.id,
      morningRoutineEnabled: morningRoutineEnabled,
      eveningRoutineEnabled: eveningRoutineEnabled,
      weeklyPlans: resolvedWeeklyPlans,
      selectedWeeklyPlanId: selectedWeeklyPlanId,
      productsToBuy: products,
      notes: (json['notes'] as String?) ?? '',
      monthlyTracker: resolvedMonthly,
      aiNoticeDismissed: (json['aiNoticeDismissed'] as bool?) ?? false,
      selectedPresetId: (json['selectedPresetId'] as String?) ?? 'default_weekly',
      updatedAtMs:
          (json['updatedAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}
