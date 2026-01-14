import 'habit_item.dart';

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

  /// Optional URL link associated with the hotspot
  final String? link;

  /// List of habits associated with this hotspot
  final List<HabitItem> habits;

  const HotspotModel({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.id,
    this.link,
    this.habits = const [],
  });

  /// Creates a copy of this hotspot with optional field overrides
  HotspotModel copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
    String? id,
    String? link,
    List<HabitItem>? habits,
  }) {
    return HotspotModel(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      id: id ?? this.id,
      link: link ?? this.link,
      habits: habits ?? this.habits,
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
      'link': link,
      'habits': habits.map((habit) => habit.toJson()).toList(),
    };
  }

  /// Creates from a map (for deserialization)
  factory HotspotModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> habitsJson = json['habits'] as List<dynamic>? ?? [];
    final List<HabitItem> habits = habitsJson
        .map((habitJson) => HabitItem.fromJson(habitJson as Map<String, dynamic>))
        .toList();

    return HotspotModel(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      id: json['id'] as String?,
      link: json['link'] as String?,
      habits: habits,
    );
  }

  /// Get the total number of habit completions for the last 7 days
  /// Aggregates all habits in this hotspot
  int get completionCountForLast7Days {
    final DateTime now = DateTime.now();
    final DateTime todayNormalized = DateTime(now.year, now.month, now.day);
    final DateTime sevenDaysAgoNormalized = todayNormalized.subtract(const Duration(days: 6)); // Include today, so 6 days back

    int totalCompletions = 0;

    for (final habit in habits) {
      for (final completedDate in habit.completedDates) {
        final DateTime normalizedDate = DateTime(
          completedDate.year,
          completedDate.month,
          completedDate.day,
        );

        // Check if this date is within the last 7 days (inclusive of both bounds)
        if (normalizedDate.compareTo(sevenDaysAgoNormalized) >= 0 &&
            normalizedDate.compareTo(todayNormalized) <= 0) {
          totalCompletions++;
        }
      }
    }

    return totalCompletions;
  }

  @override
  String toString() {
    return 'HotspotModel(x: $x, y: $y, width: $width, height: $height, id: $id, link: $link, habits: ${habits.length})';
  }
}
