/// A time-bound challenge that groups multiple habits and tracks aggregate
/// daily completion with an all-or-nothing restart mechanic (e.g. 75 Hard).
class Challenge {
  final String id;
  final String name;

  /// Template identifier (e.g. '75_hard').
  final String templateType;

  /// ISO-8601 date string (yyyy-MM-dd) for the challenge start.
  final String startDate;

  /// Total number of days the challenge runs.
  final int totalDays;

  /// IDs of the habits that comprise this challenge.
  final List<String> habitIds;

  /// ISO-8601 date strings of days where ALL habits were completed.
  final List<String> completedDays;

  /// Whether the challenge is currently active.
  final bool isActive;

  /// Number of times the user has restarted (missed a day).
  final int restartCount;

  /// Timestamp (ms since epoch) when the challenge was created.
  final int createdAtMs;

  const Challenge({
    required this.id,
    required this.name,
    required this.templateType,
    required this.startDate,
    required this.totalDays,
    required this.habitIds,
    this.completedDays = const [],
    this.isActive = true,
    this.restartCount = 0,
    required this.createdAtMs,
  });

  /// Current consecutive-day streak counting from the challenge start date.
  /// Only counts days that are consecutive from the start (no gaps).
  int get currentDay {
    if (completedDays.isEmpty) return 0;
    final start = DateTime.tryParse(startDate);
    if (start == null) return 0;

    final completedSet = completedDays.toSet();
    int streak = 0;
    var check = start;
    while (true) {
      final iso = '${check.year.toString().padLeft(4, '0')}-'
          '${check.month.toString().padLeft(2, '0')}-'
          '${check.day.toString().padLeft(2, '0')}';
      if (completedSet.contains(iso)) {
        streak++;
        check = check.add(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  /// Whether the challenge has been fully completed (all days done).
  bool get isCompleted => currentDay >= totalDays;

  /// Progress as a fraction 0.0 to 1.0.
  double get progress => totalDays > 0 ? (currentDay / totalDays).clamp(0.0, 1.0) : 0.0;

  /// The deadline date computed from startDate + totalDays.
  String get endDate {
    final start = DateTime.parse(startDate);
    final end = start.add(Duration(days: totalDays - 1));
    return end.toIso8601String().split('T')[0];
  }

  Challenge copyWith({
    String? id,
    String? name,
    String? templateType,
    String? startDate,
    int? totalDays,
    List<String>? habitIds,
    List<String>? completedDays,
    bool? isActive,
    int? restartCount,
    int? createdAtMs,
  }) {
    return Challenge(
      id: id ?? this.id,
      name: name ?? this.name,
      templateType: templateType ?? this.templateType,
      startDate: startDate ?? this.startDate,
      totalDays: totalDays ?? this.totalDays,
      habitIds: habitIds ?? this.habitIds,
      completedDays: completedDays ?? this.completedDays,
      isActive: isActive ?? this.isActive,
      restartCount: restartCount ?? this.restartCount,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'templateType': templateType,
        'startDate': startDate,
        'totalDays': totalDays,
        'habitIds': habitIds,
        'completedDays': completedDays,
        'isActive': isActive,
        'restartCount': restartCount,
        'createdAtMs': createdAtMs,
      };

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? '',
      templateType: (json['templateType'] as String?) ?? '',
      startDate: (json['startDate'] as String?) ?? '',
      totalDays: (json['totalDays'] as num?)?.toInt() ?? 0,
      habitIds: (json['habitIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      completedDays: (json['completedDays'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isActive: (json['isActive'] as bool?) ?? true,
      restartCount: (json['restartCount'] as num?)?.toInt() ?? 0,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}
