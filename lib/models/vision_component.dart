import 'package:flutter/material.dart';

import 'habit_item.dart';
import 'task_and_checklist_models.dart';

/// Freeform canvas node model.
///
/// `position` is the top-left coordinate in canvas space.
/// `size` is the unscaled size of the component in canvas space.
/// `scale` and `rotation` are applied around the component center.
abstract class VisionComponent {
  final String id;
  final Offset position;
  final Size size;
  final double rotation; // radians
  final double scale;
  final int zIndex;
  final List<HabitItem> habits;
  final List<TaskItem> tasks;
  /// When true, this layer is completed/disabled (kept, but visually muted).
  final bool isDisabled;

  const VisionComponent({
    required this.id,
    required this.position,
    required this.size,
    this.rotation = 0.0,
    this.scale = 1.0,
    this.zIndex = 0,
    this.habits = const [],
    this.tasks = const [],
    this.isDisabled = false,
  });

  VisionComponent copyWithCommon({
    String? id,
    Offset? position,
    Size? size,
    double? rotation,
    double? scale,
    int? zIndex,
    List<HabitItem>? habits,
    List<TaskItem>? tasks,
    bool? isDisabled,
  });

  String get type;

  Map<String, dynamic> toJson();

  static Map<String, dynamic> offsetToJson(Offset o) => {'dx': o.dx, 'dy': o.dy};
  static Offset offsetFromJson(Map<String, dynamic> json) =>
      Offset((json['dx'] as num).toDouble(), (json['dy'] as num).toDouble());

  static Map<String, dynamic> sizeToJson(Size s) => {'w': s.width, 'h': s.height};
  static Size sizeFromJson(Map<String, dynamic> json) =>
      Size((json['w'] as num).toDouble(), (json['h'] as num).toDouble());

  static Map<String, dynamic> textStyleToJson(TextStyle style) => {
        'color': style.color?.value,
        'fontSize': style.fontSize,
        'fontWeight': style.fontWeight?.index,
        'fontStyle': style.fontStyle?.index,
        'fontFamily': style.fontFamily,
      };

  static TextStyle textStyleFromJson(Map<String, dynamic> json) => TextStyle(
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

  static List<HabitItem> habitsFromJson(dynamic json) {
    final list = (json as List<dynamic>? ?? const []);
    return list.map((e) => HabitItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static List<Map<String, dynamic>> habitsToJson(List<HabitItem> habits) =>
      habits.map((h) => h.toJson()).toList();

  static List<TaskItem> tasksFromJson(dynamic json) {
    final list = (json as List<dynamic>? ?? const []);
    return list.map((e) => TaskItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static List<Map<String, dynamic>> tasksToJson(List<TaskItem> tasks) =>
      tasks.map((t) => t.toJson()).toList();
}

