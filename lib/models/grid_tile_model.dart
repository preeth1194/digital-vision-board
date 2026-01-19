import 'package:flutter/foundation.dart';

import 'goal_metadata.dart';
import 'habit_item.dart';
import 'task_item.dart';

/// Data model for a tile in a structured (staggered) grid vision board.
///
/// - `type`: `'image'` or `'text'`
/// - `content`: file path (image) or text content
@immutable
class GridTileModel {
  final String id;
  final String type; // 'empty' | 'image' | 'text'
  final String? content;
  final int crossAxisCellCount;
  final int mainAxisCellCount;
  final int index;
  /// Optional goal metadata (category/deadline/CBT/action plan) for this tile-goal.
  final GoalMetadata? goal;
  /// Habits associated with this tile-goal.
  final List<HabitItem> habits;
  /// Tasks associated with this tile-goal.
  final List<TaskItem> tasks;

  const GridTileModel({
    required this.id,
    required this.type,
    required this.content,
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
    required this.index,
    this.goal,
    this.habits = const [],
    this.tasks = const [],
  });

  bool get hasTrackerData {
    if (habits.isNotEmpty || tasks.isNotEmpty) return true;
    // If user has streak history stored in habits or checklist completions.
    final anyHabitHistory = habits.any((h) => h.completedDates.isNotEmpty);
    if (anyHabitHistory) return true;
    final anyChecklistHistory = tasks.any((t) => t.checklist.any((c) => (c.completedOn ?? '').trim().isNotEmpty));
    return anyChecklistHistory;
  }

  GridTileModel copyWith({
    String? id,
    String? type,
    String? content,
    int? crossAxisCellCount,
    int? mainAxisCellCount,
    int? index,
    GoalMetadata? goal,
    List<HabitItem>? habits,
    List<TaskItem>? tasks,
  }) {
    return GridTileModel(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      crossAxisCellCount: crossAxisCellCount ?? this.crossAxisCellCount,
      mainAxisCellCount: mainAxisCellCount ?? this.mainAxisCellCount,
      index: index ?? this.index,
      goal: goal ?? this.goal,
      habits: habits ?? this.habits,
      tasks: tasks ?? this.tasks,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'content': content,
        'crossAxisCellCount': crossAxisCellCount,
        'mainAxisCellCount': mainAxisCellCount,
        'index': index,
        'goal': goal?.toJson(),
        'habits': habits.map((h) => h.toJson()).toList(),
      };

  factory GridTileModel.fromJson(Map<String, dynamic> json) {
    return GridTileModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'empty',
      content: json['content'] as String?,
      crossAxisCellCount: (json['crossAxisCellCount'] as num?)?.toInt() ?? 1,
      mainAxisCellCount: (json['mainAxisCellCount'] as num?)?.toInt() ?? 1,
      index: (json['index'] as num?)?.toInt() ?? 0,
      goal: (json['goal'] is Map<String, dynamic>)
          ? GoalMetadata.fromJson(json['goal'] as Map<String, dynamic>)
          : null,
      habits: (json['habits'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HabitItem.fromJson)
          .toList(),
      tasks: (json['tasks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .toList(),
    );
  }
}

