import 'package:flutter/material.dart';

/// Model representing a todo item within a routine.
class RoutineTodoItem {
  /// Unique identifier for the todo
  final String id;

  /// Title/name of the todo
  final String title;

  /// Material icon code point for this todo
  final int iconCodePoint;

  /// Order/sequence position in the routine (0-based)
  final int order;

  /// Duration in minutes (only used if routine timeMode is 'per_todo')
  final int? durationMinutes;

  /// Timer type: 'rhythmic' or 'regular' (only used if routine timeMode is 'per_todo')
  final String? timerType; // 'rhythmic' | 'regular'

  /// Whether to show reminder for this todo
  final bool reminderEnabled;

  /// Minutes since midnight (local time) for reminder
  final int? reminderMinutes;

  /// Display label for reminder time (e.g., "07:00 AM")
  final String? timeOfDay;

  /// List of dates when this todo was completed
  final List<DateTime> completedDates;

  const RoutineTodoItem({
    required this.id,
    required this.title,
    required this.iconCodePoint,
    required this.order,
    this.durationMinutes,
    this.timerType,
    this.reminderEnabled = false,
    this.reminderMinutes,
    this.timeOfDay,
    this.completedDates = const [],
  });

  RoutineTodoItem copyWith({
    String? id,
    String? title,
    int? iconCodePoint,
    int? order,
    int? durationMinutes,
    String? timerType,
    bool? reminderEnabled,
    int? reminderMinutes,
    String? timeOfDay,
    List<DateTime>? completedDates,
  }) {
    return RoutineTodoItem(
      id: id ?? this.id,
      title: title ?? this.title,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      order: order ?? this.order,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      timerType: timerType ?? this.timerType,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      completedDates: completedDates ?? this.completedDates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'iconCodePoint': iconCodePoint,
      'order': order,
      'durationMinutes': durationMinutes,
      'timerType': timerType,
      'reminderEnabled': reminderEnabled,
      'reminderMinutes': reminderMinutes,
      'timeOfDay': timeOfDay,
      'completedDates': completedDates
          .map((date) => date.toIso8601String().split('T')[0])
          .toList(), // Store as ISO-8601 date strings (YYYY-MM-DD)
    };
  }

  factory RoutineTodoItem.fromJson(Map<String, dynamic> json) {
    final List<dynamic> datesJson = json['completedDates'] as List<dynamic>? ?? [];
    final List<DateTime> dates = datesJson
        .map((dateStr) => DateTime.parse(dateStr as String))
        .toList();

    return RoutineTodoItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.check_circle_outline.codePoint,
      order: (json['order'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      timerType: json['timerType'] as String?,
      reminderEnabled: (json['reminderEnabled'] as bool?) ?? false,
      reminderMinutes: (json['reminderMinutes'] as num?)?.toInt(),
      timeOfDay: json['timeOfDay'] as String?,
      completedDates: dates,
    );
  }

  /// Check if the todo was completed on a specific date (date-only comparison)
  bool isCompletedOnDate(DateTime date) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    return completedDates.any((completedDate) {
      final normalized = DateTime(completedDate.year, completedDate.month, completedDate.day);
      return normalized == normalizedDate;
    });
  }

  /// Toggle completion for a specific date
  RoutineTodoItem toggleForDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final updatedDates = List<DateTime>.from(completedDates);
    final exists = updatedDates.any((d) {
      final normalizedD = DateTime(d.year, d.month, d.day);
      return normalizedD == normalized;
    });
    updatedDates.removeWhere((d) {
      final normalizedD = DateTime(d.year, d.month, d.day);
      return normalizedD == normalized;
    });
    if (!exists) {
      updatedDates.add(normalized);
    }
    return copyWith(completedDates: updatedDates);
  }

  @override
  String toString() {
    return 'RoutineTodoItem(id: $id, title: $title, order: $order)';
  }
}
