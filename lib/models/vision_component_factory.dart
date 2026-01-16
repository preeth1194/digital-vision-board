import 'image_component.dart';
import 'goal_overlay_component.dart';
import 'text_component.dart';
import 'vision_component.dart';
import 'zone_component.dart';

/// Deserialize a [VisionComponent] from JSON.
VisionComponent visionComponentFromJson(Map<String, dynamic> json) {
  final type = json['type'] as String?;
  switch (type) {
    case ImageComponent.typeName:
      return ImageComponent.fromJson(json);
    case GoalOverlayComponent.typeName:
      return GoalOverlayComponent.fromJson(json);
    case TextComponent.typeName:
      return TextComponent.fromJson(json);
    case ZoneComponent.typeName:
      return ZoneComponent.fromJson(json);
    default:
      throw ArgumentError('Unknown VisionComponent type: $type');
  }
}

