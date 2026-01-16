import 'package:flutter/material.dart';

import 'habit_item.dart';
import 'vision_component.dart';

final class TextComponent extends VisionComponent {
  static const String typeName = 'text';
  final String text;
  final TextStyle style;

  const TextComponent({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.scale,
    super.zIndex,
    super.habits,
    required this.text,
    required this.style,
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
  }) {
    return TextComponent(
      id: id ?? this.id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      habits: habits ?? this.habits,
      text: text,
      style: style,
    );
  }

  TextComponent copyWith({String? text, TextStyle? style}) => TextComponent(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
        habits: habits,
        text: text ?? this.text,
        style: style ?? this.style,
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
        'text': text,
        'style': VisionComponent.textStyleToJson(style),
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
        text: json['text'] as String? ?? '',
        style: VisionComponent.textStyleFromJson(
          (json['style'] as Map<String, dynamic>? ?? const {}),
        ),
      );
}

