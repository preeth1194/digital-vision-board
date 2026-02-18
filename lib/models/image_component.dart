import 'package:flutter/material.dart';

import 'habit_item.dart';
import 'goal_metadata.dart';
import 'task_and_checklist_models.dart';
import 'vision_component.dart';

final class ImageComponent extends VisionComponent {
  static const String typeName = 'image';
  final String imagePath;
  final GoalMetadata? goal;

  const ImageComponent({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.scale,
    super.zIndex,
    super.habits,
    super.habitIds,
    super.tasks,
    super.isDisabled,
    required this.imagePath,
    this.goal,
  });

  @override
  String get type => typeName;

  @override
  ImageComponent copyWithCommon({
    String? id,
    Offset? position,
    Size? size,
    double? rotation,
    double? scale,
    int? zIndex,
    List<HabitItem>? habits,
    List<String>? habitIds,
    List<TaskItem>? tasks,
    bool? isDisabled,
    GoalMetadata? goal,
  }) {
    return ImageComponent(
      id: id ?? this.id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      habits: habits ?? this.habits,
      habitIds: habitIds ?? this.habitIds,
      tasks: tasks ?? this.tasks,
      isDisabled: isDisabled ?? this.isDisabled,
      imagePath: imagePath,
      goal: goal ?? this.goal,
    );
  }

  ImageComponent copyWith({String? imagePath, bool? isDisabled, GoalMetadata? goal}) => ImageComponent(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
        habits: habits,
        habitIds: habitIds,
        tasks: tasks,
        isDisabled: isDisabled ?? this.isDisabled,
        imagePath: imagePath ?? this.imagePath,
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
        'habitIds': habitIds,
        'isDisabled': isDisabled,
        'imagePath': imagePath,
        'goal': goal?.toJson(),
      };

  factory ImageComponent.fromJson(Map<String, dynamic> json) {
    final habits = VisionComponent.habitsFromJson(json['habits']);
    return ImageComponent(
      id: json['id'] as String,
      position: VisionComponent.offsetFromJson(
        json['position'] as Map<String, dynamic>,
      ),
      size: VisionComponent.sizeFromJson(json['size'] as Map<String, dynamic>),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
      habits: habits,
      habitIds: VisionComponent.habitIdsFromJson(json['habitIds'], fallbackHabits: habits),
      tasks: VisionComponent.tasksFromJson(json['tasks']),
      isDisabled: json['isDisabled'] as bool? ?? false,
      imagePath: json['imagePath'] as String,
      goal: (json['goal'] is Map<String, dynamic>)
          ? GoalMetadata.fromJson(json['goal'] as Map<String, dynamic>)
          : null,
    );
  }
}

