import 'package:flutter/material.dart';

import 'goal_metadata.dart';
import 'habit_item.dart';
import 'task_item.dart';
import 'vision_component.dart';

/// Goal overlay anchored to a background image using **image-pixel coordinates**.
///
/// - `position` is top-left in the background image pixel space.
/// - `size` is width/height in the background image pixel space.
///
/// This is used for the Physical Board editor where the scanned/photo background
/// is the primary canvas and goals are represented as overlay regions.
final class GoalOverlayComponent extends VisionComponent {
  static const String typeName = 'goal_overlay';

  final GoalMetadata goal;

  const GoalOverlayComponent({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.scale,
    super.zIndex,
    super.habits,
    super.tasks,
    super.isDisabled,
    required this.goal,
  });

  @override
  String get type => typeName;

  @override
  GoalOverlayComponent copyWithCommon({
    String? id,
    Offset? position,
    Size? size,
    double? rotation,
    double? scale,
    int? zIndex,
    List<HabitItem>? habits,
    List<TaskItem>? tasks,
    bool? isDisabled,
  }) {
    return GoalOverlayComponent(
      id: id ?? this.id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      habits: habits ?? this.habits,
      tasks: tasks ?? this.tasks,
      isDisabled: isDisabled ?? this.isDisabled,
      goal: goal,
    );
  }

  GoalOverlayComponent copyWith({GoalMetadata? goal, bool? isDisabled}) => GoalOverlayComponent(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
        habits: habits,
        tasks: tasks,
        isDisabled: isDisabled ?? this.isDisabled,
        goal: goal ?? this.goal,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'position': VisionComponent.offsetToJson(position),
        'size': VisionComponent.sizeToJson(size),
        'rotation': rotation,
        'scale': scale,
        'zIndex': zIndex,
        'habits': VisionComponent.habitsToJson(habits),
        'isDisabled': isDisabled,
        'goal': goal.toJson(),
      };

  factory GoalOverlayComponent.fromJson(Map<String, dynamic> json) => GoalOverlayComponent(
        id: json['id'] as String,
        position: VisionComponent.offsetFromJson(json['position'] as Map<String, dynamic>),
        size: VisionComponent.sizeFromJson(json['size'] as Map<String, dynamic>),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
        habits: VisionComponent.habitsFromJson(json['habits']),
        tasks: VisionComponent.tasksFromJson(json['tasks']),
        isDisabled: json['isDisabled'] as bool? ?? false,
        goal: GoalMetadata.fromJson(json['goal'] as Map<String, dynamic>),
      );
}

