import 'package:flutter/material.dart';

import 'habit_item.dart';
import 'task_and_checklist_models.dart';
import 'vision_component.dart';

final class TextComponent extends VisionComponent {
  static const String typeName = 'text';
  final String text;
  final TextStyle style;
  final TextAlign textAlign;

  const TextComponent({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.scale,
    super.zIndex,
    super.habits,
    super.tasks,
    super.isDisabled,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.left,
  });

  @override
  String get type => typeName;

  @override
  TextComponent copyWithCommon({
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
    return TextComponent(
      id: id ?? this.id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      habits: habits ?? this.habits,
      tasks: tasks ?? this.tasks,
      isDisabled: isDisabled ?? this.isDisabled,
      text: text,
      style: style,
      textAlign: textAlign,
    );
  }

  TextComponent copyWith({
    String? text,
    TextStyle? style,
    TextAlign? textAlign,
    bool? isDisabled,
  }) =>
      TextComponent(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
        habits: habits,
        tasks: tasks,
        isDisabled: isDisabled ?? this.isDisabled,
        text: text ?? this.text,
        style: style ?? this.style,
        textAlign: textAlign ?? this.textAlign,
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
        'text': text,
        'style': VisionComponent.textStyleToJson(style),
        'textAlign': textAlign.index,
      };

  factory TextComponent.fromJson(Map<String, dynamic> json) => TextComponent(
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
        text: json['text'] as String? ?? '',
        style: VisionComponent.textStyleFromJson(
          (json['style'] as Map<String, dynamic>? ?? const {}),
        ),
        textAlign: (json['textAlign'] is num)
            ? TextAlign.values[(json['textAlign'] as num).toInt().clamp(0, TextAlign.values.length - 1)]
            : TextAlign.left,
      );
}

