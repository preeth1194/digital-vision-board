import 'package:flutter/foundation.dart';

import 'goal_metadata.dart';
import 'habit_item.dart';
import 'task_and_checklist_models.dart';

/// Data model for a tile in a structured (staggered) grid vision board.
///
/// - `type`: `'image'` or `'text'`
/// - `content`: file path (image) or text content
@immutable
class GridTileModel {
  final String id;
  final String type; // 'empty' | 'image' | 'text'
  final String? content;
  /// True when this tile was auto-filled by the wizard (quotes/stock images).
  /// Helps UX: we can style/shuffle placeholders without affecting user-created tiles.
  final bool isPlaceholder;
  final int crossAxisCellCount;
  final int mainAxisCellCount;
  final int index;
  /// Optional goal metadata (category/deadline/CBT/action plan) for this tile-goal.
  final GoalMetadata? goal;
  /// Habits associated with this tile-goal (legacy, kept for backward compat).
  final List<HabitItem> habits;
  /// Habit IDs referencing habits in HabitStorageService.
  final List<String> habitIds;
  /// Tasks associated with this tile-goal.
  final List<TaskItem> tasks;
  final double? textFontSize;
  final String? textAlign; // 'left' | 'center' | 'right'
  final bool? textBold;

  const GridTileModel({
    required this.id,
    required this.type,
    required this.content,
    this.isPlaceholder = false,
    required this.crossAxisCellCount,
    required this.mainAxisCellCount,
    required this.index,
    this.goal,
    this.habits = const [],
    this.habitIds = const [],
    this.tasks = const [],
    this.textFontSize,
    this.textAlign,
    this.textBold,
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
    bool? isPlaceholder,
    int? crossAxisCellCount,
    int? mainAxisCellCount,
    int? index,
    GoalMetadata? goal,
    List<HabitItem>? habits,
    List<String>? habitIds,
    List<TaskItem>? tasks,
    double? textFontSize,
    String? textAlign,
    bool? textBold,
  }) {
    return GridTileModel(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      crossAxisCellCount: crossAxisCellCount ?? this.crossAxisCellCount,
      mainAxisCellCount: mainAxisCellCount ?? this.mainAxisCellCount,
      index: index ?? this.index,
      goal: goal ?? this.goal,
      habits: habits ?? this.habits,
      habitIds: habitIds ?? this.habitIds,
      tasks: tasks ?? this.tasks,
      textFontSize: textFontSize ?? this.textFontSize,
      textAlign: textAlign ?? this.textAlign,
      textBold: textBold ?? this.textBold,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'content': content,
        'is_placeholder': isPlaceholder,
        'crossAxisCellCount': crossAxisCellCount,
        'mainAxisCellCount': mainAxisCellCount,
        'index': index,
        'goal': goal?.toJson(),
        'habits': habits.map((h) => h.toJson()).toList(),
        'habitIds': habitIds,
        if (textFontSize != null) 'textFontSize': textFontSize,
        if (textAlign != null) 'textAlign': textAlign,
        if (textBold != null) 'textBold': textBold,
      };

  factory GridTileModel.fromJson(Map<String, dynamic> json) {
    final habits = (json['habits'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(HabitItem.fromJson)
        .toList();
    final habitIdsRaw = json['habitIds'] as List<dynamic>?;
    final habitIds = habitIdsRaw != null
        ? habitIdsRaw.whereType<String>().toList()
        : habits.map((h) => h.id).toList();
    return GridTileModel(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'empty',
      content: json['content'] as String?,
      isPlaceholder: (json['is_placeholder'] as bool?) ?? (json['isPlaceholder'] as bool?) ?? false,
      crossAxisCellCount: (json['crossAxisCellCount'] as num?)?.toInt() ?? 1,
      mainAxisCellCount: (json['mainAxisCellCount'] as num?)?.toInt() ?? 1,
      index: (json['index'] as num?)?.toInt() ?? 0,
      goal: (json['goal'] is Map<String, dynamic>)
          ? GoalMetadata.fromJson(json['goal'] as Map<String, dynamic>)
          : null,
      habits: habits,
      habitIds: habitIds,
      tasks: (json['tasks'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(TaskItem.fromJson)
          .toList(),
      textFontSize: (json['textFontSize'] as num?)?.toDouble(),
      textAlign: json['textAlign'] as String?,
      textBold: json['textBold'] as bool?,
    );
  }
}

