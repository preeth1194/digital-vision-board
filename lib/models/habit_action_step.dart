import 'package:flutter/material.dart';

/// A simplified action step within a habit (no completion tracking or timers).
class HabitActionStep {
  final String id;
  final String title;
  final int iconCodePoint;
  final int order;
  final String? stepLabel;
  final String? productType;
  final String? productName;
  final String? notes;
  final String? plannerDay;

  const HabitActionStep({
    required this.id,
    required this.title,
    required this.iconCodePoint,
    required this.order,
    this.stepLabel,
    this.productType,
    this.productName,
    this.notes,
    this.plannerDay,
  });

  String get displayTitle {
    final preferred = [
      productName,
      productType,
      stepLabel,
      title,
    ].map((e) => (e ?? '').trim()).firstWhere(
      (value) => value.isNotEmpty,
      orElse: () => '',
    );
    return preferred;
  }

  HabitActionStep copyWith({
    String? id,
    String? title,
    int? iconCodePoint,
    int? order,
    String? stepLabel,
    String? productType,
    String? productName,
    String? notes,
    String? plannerDay,
  }) {
    return HabitActionStep(
      id: id ?? this.id,
      title: title ?? this.title,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      order: order ?? this.order,
      stepLabel: stepLabel ?? this.stepLabel,
      productType: productType ?? this.productType,
      productName: productName ?? this.productName,
      notes: notes ?? this.notes,
      plannerDay: plannerDay ?? this.plannerDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'iconCodePoint': iconCodePoint,
        'order': order,
        'stepLabel': stepLabel,
        'productType': productType,
        'productName': productName,
        'notes': notes,
        'plannerDay': plannerDay,
      };

  factory HabitActionStep.fromJson(Map<String, dynamic> json) {
    return HabitActionStep(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
          Icons.check_circle_outline.codePoint,
      order: (json['order'] as num?)?.toInt() ?? 0,
      stepLabel: json['stepLabel'] as String? ?? json['step_label'] as String?,
      productType:
          json['productType'] as String? ?? json['product_type'] as String?,
      productName:
          json['productName'] as String? ?? json['product_name'] as String?,
      notes: json['notes'] as String?,
      plannerDay:
          json['plannerDay'] as String? ?? json['planner_day'] as String?,
    );
  }

  @override
  String toString() => 'HabitActionStep(id: $id, title: $title, order: $order)';
}
