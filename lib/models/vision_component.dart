import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'habit_item.dart';
import 'hotspot_model.dart';

/// Freeform canvas node model.
///
/// `position` is the top-left coordinate in canvas space.
/// `size` is the unscaled size of the component in canvas space.
/// `scale` and `rotation` are applied around the component center.
sealed class VisionComponent {
  final String id;
  final Offset position;
  final Size size;
  final double rotation; // radians
  final double scale;
  final int zIndex;
  final List<HabitItem> habits;

  const VisionComponent({
    required this.id,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.zIndex = 0,
    this.habits = const [],
  });

  VisionComponent copyWithCommon({
    String? id,
    Offset? position,
    Size? size,
    double? rotation,
    double? scale,
    int? zIndex,
    List<HabitItem>? habits,
  });

  String get type;

  Map<String, dynamic> toJson();

  static VisionComponent fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case ImageComponent.typeName:
        return ImageComponent.fromJson(json);
      case TextComponent.typeName:
        return TextComponent.fromJson(json);
      case ZoneComponent.typeName:
        return ZoneComponent.fromJson(json);
      default:
        throw ArgumentError('Unknown VisionComponent type: $type');
    }
  }

  static Map<String, dynamic> _offsetToJson(Offset o) => {'dx': o.dx, 'dy': o.dy};
  static Offset _offsetFromJson(Map<String, dynamic> json) =>
      Offset((json['dx'] as num).toDouble(), (json['dy'] as num).toDouble());

  static Map<String, dynamic> _sizeToJson(Size s) => {'w': s.width, 'h': s.height};
  static Size _sizeFromJson(Map<String, dynamic> json) =>
      Size((json['w'] as num).toDouble(), (json['h'] as num).toDouble());

  static Map<String, dynamic> _textStyleToJson(TextStyle style) => {
        'color': style.color?.value,
        'fontSize': style.fontSize,
        'fontWeight': style.fontWeight?.index,
        'fontStyle': style.fontStyle?.index,
        'fontFamily': style.fontFamily,
      };

  static TextStyle _textStyleFromJson(Map<String, dynamic> json) => TextStyle(
        color: (json['color'] as int?) != null ? Color(json['color'] as int) : null,
        fontSize: (json['fontSize'] as num?)?.toDouble(),
        fontWeight: (json['fontWeight'] as int?) != null
            ? FontWeight.values[json['fontWeight'] as int]
            : null,
        fontStyle: (json['fontStyle'] as int?) != null
            ? FontStyle.values[json['fontStyle'] as int]
            : null,
        fontFamily: json['fontFamily'] as String?,
      );

  static List<HabitItem> _habitsFromJson(dynamic json) {
    final list = (json as List<dynamic>? ?? const []);
    return list.map((e) => HabitItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static List<Map<String, dynamic>> _habitsToJson(List<HabitItem> habits) =>
      habits.map((h) => h.toJson()).toList();
}

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

  ImageComponent copyWith({String? imagePath}) =>
      ImageComponent(
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
        'position': VisionComponent._offsetToJson(position),
        'size': VisionComponent._sizeToJson(size),
        'rotation': rotation,
        'scale': scale,
        'zIndex': zIndex,
        'habits': VisionComponent._habitsToJson(habits),
        'imagePath': imagePath,
      };

  factory ImageComponent.fromJson(Map<String, dynamic> json) => ImageComponent(
        id: json['id'] as String,
        position:
            VisionComponent._offsetFromJson(json['position'] as Map<String, dynamic>),
        size: VisionComponent._sizeFromJson(json['size'] as Map<String, dynamic>),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
        habits: VisionComponent._habitsFromJson(json['habits']),
        imagePath: json['imagePath'] as String,
      );
}

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
        'position': VisionComponent._offsetToJson(position),
        'size': VisionComponent._sizeToJson(size),
        'rotation': rotation,
        'scale': scale,
        'zIndex': zIndex,
        'habits': VisionComponent._habitsToJson(habits),
        'text': text,
        'style': VisionComponent._textStyleToJson(style),
      };

  factory TextComponent.fromJson(Map<String, dynamic> json) => TextComponent(
        id: json['id'] as String,
        position:
            VisionComponent._offsetFromJson(json['position'] as Map<String, dynamic>),
        size: VisionComponent._sizeFromJson(json['size'] as Map<String, dynamic>),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
        habits: VisionComponent._habitsFromJson(json['habits']),
        text: json['text'] as String? ?? '',
        style: VisionComponent._textStyleFromJson(
            (json['style'] as Map<String, dynamic>? ?? const {})),
      );
}

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
  }) {
    return ZoneComponent(
      id: id ?? this.id,
      position: position ?? this.position,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
      zIndex: zIndex ?? this.zIndex,
      habits: habits ?? this.habits,
      link: link,
    );
  }

  ZoneComponent copyWith({String? link}) => ZoneComponent(
        id: id,
        position: position,
        size: size,
        rotation: rotation,
        scale: scale,
        zIndex: zIndex,
        habits: habits,
        link: link ?? this.link,
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'position': VisionComponent._offsetToJson(position),
        'size': VisionComponent._sizeToJson(size),
        'rotation': rotation,
        'scale': scale,
        'zIndex': zIndex,
        'habits': VisionComponent._habitsToJson(habits),
        'link': link,
      };

  factory ZoneComponent.fromJson(Map<String, dynamic> json) => ZoneComponent(
        id: json['id'] as String,
        position:
            VisionComponent._offsetFromJson(json['position'] as Map<String, dynamic>),
        size: VisionComponent._sizeFromJson(json['size'] as Map<String, dynamic>),
        rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
        scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
        zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
        habits: VisionComponent._habitsFromJson(json['habits']),
        link: json['link'] as String?,
      );
}

/// Legacy compatibility: convert a normalized `HotspotModel` into a pixel-space
/// `ZoneComponent` on a canvas whose background image is laid out at
/// `originalImageSize`.
ZoneComponent convertHotspotToComponent(HotspotModel hotspot, Size originalImageSize) {
  final id = (hotspot.id != null && hotspot.id!.trim().isNotEmpty)
      ? hotspot.id!.trim()
      : 'zone_${math.Random().nextInt(1 << 32)}';

  return ZoneComponent(
    id: id,
    position: Offset(
      hotspot.x * originalImageSize.width,
      hotspot.y * originalImageSize.height,
    ),
    size: Size(
      hotspot.width * originalImageSize.width,
      hotspot.height * originalImageSize.height,
    ),
    rotation: 0,
    scale: 1,
    zIndex: 0,
    habits: hotspot.habits,
    link: hotspot.link,
  );
}

