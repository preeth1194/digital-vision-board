/// Model representing a hotspot zone on the vision board image.
/// Coordinates are normalized (0.0 to 1.0) relative to the image dimensions.
class HotspotModel {
  /// X position as a percentage of image width (0.0 to 1.0)
  final double x;

  /// Y position as a percentage of image height (0.0 to 1.0)
  final double y;

  /// Width as a percentage of image width (0.0 to 1.0)
  final double width;

  /// Height as a percentage of image height (0.0 to 1.0)
  final double height;

  /// Optional identifier for the hotspot
  final String? id;

  const HotspotModel({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.id,
  });

  /// Creates a copy of this hotspot with optional field overrides
  HotspotModel copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? id,
  }) {
    return HotspotModel(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      id: id ?? this.id,
    );
  }

  /// Converts to a map for serialization
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'id': id,
    };
  }

  /// Creates from a map (for deserialization)
  factory HotspotModel.fromJson(Map<String, dynamic> json) {
    return HotspotModel(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      id: json['id'] as String?,
    );
  }

  @override
  String toString() {
    return 'HotspotModel(x: $x, y: $y, width: $width, height: $height, id: $id)';
  }
}
