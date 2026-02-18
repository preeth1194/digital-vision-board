import 'package:flutter/material.dart';

import 'routine_todo_item.dart';

/// Model representing a routine with sequential todo items.
class Routine {
  final String id;
  final String title;
  final int createdAtMs;
  final int iconCodePoint; // Material icon code point
  final int tileColorValue; // ARGB color value
  final List<RoutineTodoItem> todos;
  
  /// Time mode: 'overall' for single timer for entire routine, 'per_todo' for individual timers
  final String timeMode; // 'overall' | 'per_todo'
  
  /// Overall duration in minutes (only used if timeMode is 'overall')
  final int? overallDurationMinutes;

  /// Spotify playlist ID for overall routine (only used if timeMode is 'overall')
  final String? overallPlaylistId;

  /// Timer type for overall mode: 'regular' | 'rhythmic' (only used if timeMode is 'overall')
  final String? overallTimerType;

  /// Occurrence type: 'daily' | 'weekdays' | 'interval'
  final String occurrenceType;

  /// Weekdays for 'weekdays' occurrence type (0=Mon, 1=Tue, ... 6=Sun)
  final List<int>? weekdays;

  /// Interval in days for 'interval' occurrence type
  final int? intervalDays;

  /// Start date for the routine (used for interval calculation)
  final DateTime? startDate;

  /// IDs of habits linked to this routine
  final List<String> linkedHabitIds;

  /// Start time in minutes since midnight (e.g. 8:51 PM = 20*60+51 = 1251)
  final int? startTimeMinutes;

  const Routine({
    required this.id,
    required this.title,
    required this.createdAtMs,
    required this.iconCodePoint,
    required this.tileColorValue,
    this.todos = const [],
    this.timeMode = 'overall',
    this.overallDurationMinutes,
    this.overallPlaylistId,
    this.overallTimerType,
    this.occurrenceType = 'daily',
    this.weekdays,
    this.intervalDays,
    this.startDate,
    this.linkedHabitIds = const [],
    this.startTimeMinutes,
  });

  Routine copyWith({
    String? id,
    String? title,
    int? createdAtMs,
    int? iconCodePoint,
    int? tileColorValue,
    List<RoutineTodoItem>? todos,
    String? timeMode,
    int? overallDurationMinutes,
    String? overallPlaylistId,
    String? overallTimerType,
    String? occurrenceType,
    List<int>? weekdays,
    int? intervalDays,
    DateTime? startDate,
    List<String>? linkedHabitIds,
    int? startTimeMinutes,
  }) {
    return Routine(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      tileColorValue: tileColorValue ?? this.tileColorValue,
      todos: todos ?? this.todos,
      timeMode: timeMode ?? this.timeMode,
      overallDurationMinutes: overallDurationMinutes ?? this.overallDurationMinutes,
      overallPlaylistId: overallPlaylistId ?? this.overallPlaylistId,
      overallTimerType: overallTimerType ?? this.overallTimerType,
      occurrenceType: occurrenceType ?? this.occurrenceType,
      weekdays: weekdays ?? this.weekdays,
      intervalDays: intervalDays ?? this.intervalDays,
      startDate: startDate ?? this.startDate,
      linkedHabitIds: linkedHabitIds ?? this.linkedHabitIds,
      startTimeMinutes: startTimeMinutes ?? this.startTimeMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAtMs': createdAtMs,
        'iconCodePoint': iconCodePoint,
        'tileColorValue': tileColorValue,
        'todos': todos.map((t) => t.toJson()).toList(),
        'timeMode': timeMode,
        'overallDurationMinutes': overallDurationMinutes,
        'overallPlaylistId': overallPlaylistId,
        'overallTimerType': overallTimerType,
        'occurrenceType': occurrenceType,
        'weekdays': weekdays,
        'intervalDays': intervalDays,
        'startDate': startDate?.toIso8601String(),
        'linkedHabitIds': linkedHabitIds,
        'startTimeMinutes': startTimeMinutes,
      };

  factory Routine.fromJson(Map<String, dynamic> json) {
    final List<dynamic> todosJson = json['todos'] as List<dynamic>? ?? [];
    final List<RoutineTodoItem> todos = todosJson
        .map((todoJson) => RoutineTodoItem.fromJson(todoJson as Map<String, dynamic>))
        .toList();

    final List<dynamic>? weekdaysJson = json['weekdays'] as List<dynamic>?;
    final List<int>? weekdays = weekdaysJson?.map((e) => (e as num).toInt()).toList();

    final String? startDateStr = json['startDate'] as String?;
    final DateTime? startDate = startDateStr != null ? DateTime.tryParse(startDateStr) : null;

    final List<dynamic>? linkedHabitIdsJson = json['linkedHabitIds'] as List<dynamic>?;
    final List<String> linkedHabitIds = linkedHabitIdsJson?.map((e) => e as String).toList() ?? [];

    return Routine(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Routine',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.list.codePoint,
      tileColorValue: (json['tileColorValue'] as num?)?.toInt() ??
          const Color(0xFFE0F2FE).value,
      todos: todos,
      timeMode: (json['timeMode'] as String?) ?? 'overall',
      overallDurationMinutes: (json['overallDurationMinutes'] as num?)?.toInt(),
      overallPlaylistId: json['overallPlaylistId'] as String?,
      overallTimerType: json['overallTimerType'] as String?,
      occurrenceType: (json['occurrenceType'] as String?) ?? 'daily',
      weekdays: weekdays,
      intervalDays: (json['intervalDays'] as num?)?.toInt(),
      startDate: startDate,
      linkedHabitIds: linkedHabitIds,
      startTimeMinutes: (json['startTimeMinutes'] as num?)?.toInt(),
    );
  }

  /// Get total duration in minutes (either overall or sum of todos)
  int getTotalDurationMinutes() {
    if (timeMode == 'overall' && overallDurationMinutes != null) {
      return overallDurationMinutes!;
    }
    if (timeMode == 'per_todo') {
      return todos.fold(0, (sum, todo) => sum + (todo.durationMinutes ?? 0));
    }
    return 0;
  }

  /// Get completion percentage for today
  double getCompletionPercentageForDate(DateTime date) {
    if (todos.isEmpty) return 0.0;
    final completedCount = todos.where((todo) => todo.isCompletedOnDate(date)).length;
    return completedCount / todos.length;
  }

  /// Check if this routine should occur on a given date
  bool occursOnDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    
    switch (occurrenceType) {
      case 'daily':
        return true;
      case 'weekdays':
        if (weekdays == null || weekdays!.isEmpty) return true;
        // DateTime.weekday: 1=Mon, 2=Tue, ... 7=Sun
        // Our weekdays: 0=Mon, 1=Tue, ... 6=Sun
        final dayIndex = normalizedDate.weekday - 1; // Convert to 0-based
        return weekdays!.contains(dayIndex);
      case 'interval':
        if (intervalDays == null || intervalDays! <= 0) return true;
        final start = startDate ?? DateTime.fromMillisecondsSinceEpoch(createdAtMs);
        final normalizedStart = DateTime(start.year, start.month, start.day);
        final daysDiff = normalizedDate.difference(normalizedStart).inDays;
        return daysDiff >= 0 && daysDiff % intervalDays! == 0;
      default:
        return true;
    }
  }

  /// Get the start time of this routine in minutes since midnight
  int? getStartTimeMinutes() {
    if (startTimeMinutes != null) return startTimeMinutes;
    // Fallback: check the first todo with a scheduled time
    for (final todo in todos) {
      if (todo.reminderMinutes != null) {
        return todo.reminderMinutes;
      }
    }
    return null;
  }

  @override
  String toString() {
    return 'Routine(id: $id, title: $title, todos: ${todos.length}, occurrence: $occurrenceType)';
  }
}
