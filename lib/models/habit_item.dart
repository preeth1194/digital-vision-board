/// Model representing a habit item with completion tracking.
class HabitItem {
  /// Unique identifier for the habit
  final String id;

  /// Name of the habit
  final String name;

  /// List of dates when this habit was completed (stored as date-only, no time)
  final List<DateTime> completedDates;

  const HabitItem({
    required this.id,
    required this.name,
    this.completedDates = const [],
  });

  /// Creates a copy of this habit with optional field overrides
  HabitItem copyWith({
    String? id,
    String? name,
    List<DateTime>? completedDates,
  }) {
    return HabitItem(
      id: id ?? this.id,
      name: name ?? this.name,
      completedDates: completedDates ?? this.completedDates,
    );
  }

  /// Converts to a map for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'completedDates': completedDates
          .map((date) => date.toIso8601String().split('T')[0])
          .toList(), // Store as ISO-8601 date strings (YYYY-MM-DD)
    };
  }

  /// Creates from a map (for deserialization)
  factory HabitItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> datesJson = json['completedDates'] as List<dynamic>? ?? [];
    final List<DateTime> dates = datesJson
        .map((dateStr) => DateTime.parse(dateStr as String))
        .toList();
    
    return HabitItem(
      id: json['id'] as String,
      name: json['name'] as String,
      completedDates: dates,
    );
  }

  /// Get the current streak count (consecutive days from today backwards)
  int get currentStreak {
    if (completedDates.isEmpty) return 0;

    // Normalize all dates to date-only (remove time component)
    final List<DateTime> normalizedDates = completedDates
        .map((date) => DateTime(date.year, date.month, date.day))
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending (most recent first)

    // Remove duplicates
    final List<DateTime> uniqueDates = normalizedDates.toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    if (uniqueDates.isEmpty) return 0;

    // Get today's date (normalized)
    final DateTime today = DateTime.now();
    final DateTime todayNormalized = DateTime(today.year, today.month, today.day);

    // Check if today or yesterday was completed (allows for checking streak even if today isn't done yet)
    int streak = 0;
    DateTime checkDate = todayNormalized;

    // If today is completed, start from today
    if (uniqueDates.contains(checkDate)) {
      streak = 1;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else if (uniqueDates.contains(checkDate.subtract(const Duration(days: 1)))) {
      // If yesterday was completed, start from yesterday
      streak = 1;
      checkDate = checkDate.subtract(const Duration(days: 2));
    } else {
      // No recent completion, streak is 0
      return 0;
    }

    // Count consecutive days backwards
    while (uniqueDates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Check if the habit was completed on a specific date (date-only comparison)
  bool isCompletedOnDate(DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    return completedDates.any((completedDate) {
      final DateTime normalizedCompleted = DateTime(
        completedDate.year,
        completedDate.month,
        completedDate.day,
      );
      return normalizedCompleted == normalizedDate;
    });
  }

  /// Toggle completion for today (adds if not present, removes if present)
  HabitItem toggleToday() {
    final DateTime today = DateTime.now();
    final DateTime todayNormalized = DateTime(today.year, today.month, today.day);

    final List<DateTime> updatedDates = List<DateTime>.from(completedDates);
    
    // Check if today is already in the list
    final bool isAlreadyCompleted = updatedDates.any((date) {
      final DateTime normalized = DateTime(date.year, date.month, date.day);
      return normalized == todayNormalized;
    });

    if (isAlreadyCompleted) {
      // Remove today's date
      updatedDates.removeWhere((date) {
        final DateTime normalized = DateTime(date.year, date.month, date.day);
        return normalized == todayNormalized;
      });
    } else {
      // Add today's date
      updatedDates.add(todayNormalized);
    }

    return copyWith(completedDates: updatedDates);
  }

  @override
  String toString() {
    return 'HabitItem(id: $id, name: $name, completedDates: ${completedDates.length})';
  }
}
