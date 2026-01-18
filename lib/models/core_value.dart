import 'package:flutter/material.dart';

/// Core values a board can be centered around.
///
/// Stored as stable string ids to keep JSON simple.
final class CoreValue {
  final String id;
  final String label;
  final IconData icon;
  final Color tileColor;

  const CoreValue({
    required this.id,
    required this.label,
    required this.icon,
    required this.tileColor,
  });
}

final class CoreValues {
  CoreValues._();

  static const String growthMindset = 'growth_mindset';
  static const String careerAmbition = 'career_ambition';
  static const String creativityExpression = 'creativity_expression';
  static const String lifestyleAdventure = 'lifestyle_adventure';
  static const String connectionCommunity = 'connection_community';

  static const CoreValue growthMindsetValue = CoreValue(
    id: growthMindset,
    label: 'Growth & Mindset',
    icon: Icons.self_improvement_outlined,
    tileColor: Color(0xFFECFDF5),
  );

  static const List<CoreValue> all = [
    growthMindsetValue,
    CoreValue(
      id: careerAmbition,
      label: 'Career & Ambition',
      icon: Icons.work_outline,
      tileColor: Color(0xFFE0F2FE),
    ),
    CoreValue(
      id: creativityExpression,
      label: 'Creativity & Expression',
      icon: Icons.brush_outlined,
      tileColor: Color(0xFFF3E8FF),
    ),
    CoreValue(
      id: lifestyleAdventure,
      label: 'Lifestyle & Adventure',
      icon: Icons.travel_explore,
      tileColor: Color(0xFFFFF7ED),
    ),
    CoreValue(
      id: connectionCommunity,
      label: 'Connection & Community',
      icon: Icons.people_outline,
      tileColor: Color(0xFFFFF1F2),
    ),
  ];

  static CoreValue byId(String? id) {
    final v = (id ?? '').trim();
    if (v.isEmpty) return growthMindsetValue;
    for (final cv in all) {
      if (cv.id == v) return cv;
    }
    return growthMindsetValue;
  }
}

