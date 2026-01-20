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

  const Routine({
    required this.id,
    required this.title,
    required this.createdAtMs,
    required this.iconCodePoint,
    required this.tileColorValue,
    this.todos = const [],
    this.timeMode = 'overall',
    this.overallDurationMinutes,
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
      };

  factory Routine.fromJson(Map<String, dynamic> json) {
    final List<dynamic> todosJson = json['todos'] as List<dynamic>? ?? [];
    final List<RoutineTodoItem> todos = todosJson
        .map((todoJson) => RoutineTodoItem.fromJson(todoJson as Map<String, dynamic>))
        .toList();

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

  @override
  String toString() {
    return 'Routine(id: $id, title: $title, todos: ${todos.length})';
  }
}
