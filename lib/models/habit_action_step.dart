import 'package:flutter/material.dart';

/// A simplified action step within a habit (no completion tracking or timers).
class HabitActionStep {
  final String id;
  final String title;
  final int iconCodePoint;
  final int order;

  const HabitActionStep({
    required this.id,
    required this.title,
    required this.iconCodePoint,
    required this.order,
  });

  HabitActionStep copyWith({
    String? id,
    String? title,
    int? iconCodePoint,
    int? order,
  }) {
    return HabitActionStep(
      id: id ?? this.id,
      title: title ?? this.title,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'iconCodePoint': iconCodePoint,
        'order': order,
      };

  factory HabitActionStep.fromJson(Map<String, dynamic> json) {
    return HabitActionStep(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.check_circle_outline.codePoint,
      order: (json['order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() => 'HabitActionStep(id: $id, title: $title, order: $order)';
}
