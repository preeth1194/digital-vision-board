import 'package:flutter/material.dart';

import 'habit_item.dart';
import 'task_and_checklist_models.dart';
import 'vision_component.dart';

/// Legacy transparent hotspot, kept as a component.
final class ZoneComponent extends VisionComponent {
  static const String typeName = 'zone';

  /// Optional link migrated from legacy hotspots.
  final String? link;

  const ZoneComponent({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.scale,
    super.zIndex,
    super.habits,
    super.tasks,
    super.isDisabled,
    this.link,
  });

  @override
  String get type => typeName;

  @override
  ZoneComponent copyWithCommon({
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
    return ZoneComponent(
      id: id ?? this.id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      habits: habits ?? this.habits,
      tasks: tasks ?? this.tasks,
      isDisabled: isDisabled ?? this.isDisabled,
      link: link,
    );
  }

  ZoneComponent copyWith({String? link, bool? isDisabled}) => ZoneComponent(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
        habits: habits,
        tasks: tasks,
        isDisabled: isDisabled ?? this.isDisabled,
        link: link ?? this.link,
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
        'link': link,
      };

  factory ZoneComponent.fromJson(Map<String, dynamic> json) => ZoneComponent(
        id: json['id'] as String,
        position: VisionComponent.offsetFromJson(
          json['position'] as Map<String, dynamic>,
        ),
        size: VisionComponent.sizeFromJson(json['size'] as Map<String, dynamic>),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
        habits: VisionComponent.habitsFromJson(json['habits']),
        tasks: VisionComponent.tasksFromJson(json['tasks']),
        isDisabled: json['isDisabled'] as bool? ?? false,
        link: json['link'] as String?,
      );
}

