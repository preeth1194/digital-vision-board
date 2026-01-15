import 'package:flutter/material.dart';

import 'habit_item.dart';
import 'vision_component.dart';

final class ImageComponent extends VisionComponent {
  static const String typeName = 'image';
  final String imagePath;

  const ImageComponent({
    required super.id,
    required super.position,
    required super.size,
    super.rotation,
    super.scale,
    super.zIndex,
    super.habits,
    required this.imagePath,
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
  }) {
    return ImageComponent(
      id: id ?? this.id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      habits: habits ?? this.habits,
      imagePath: imagePath,
    );
  }

  ImageComponent copyWith({String? imagePath}) => ImageComponent(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
        habits: habits,
        imagePath: imagePath ?? this.imagePath,
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
        'imagePath': imagePath,
      };

  factory ImageComponent.fromJson(Map<String, dynamic> json) => ImageComponent(
        id: json['id'] as String,
        position: VisionComponent.offsetFromJson(
          json['position'] as Map<String, dynamic>,
        ),
        size: VisionComponent.sizeFromJson(json['size'] as Map<String, dynamic>),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
        habits: VisionComponent.habitsFromJson(json['habits']),
        imagePath: json['imagePath'] as String,
      );
}

