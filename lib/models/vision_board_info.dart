import 'package:flutter/material.dart';

class VisionBoardInfo {
  static const String layoutFreeform = 'freeform';
  static const String layoutGrid = 'grid';

  final String id;
  final String title;
  final int createdAtMs;
  final int iconCodePoint; // Material icon code point
  final int tileColorValue; // ARGB color value
  final String layoutType; // 'freeform' | 'grid'

  const VisionBoardInfo({
    required this.id,
    required this.title,
    required this.createdAtMs,
    required this.iconCodePoint,
    required this.tileColorValue,
    required this.layoutType,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAtMs': createdAtMs,
        'iconCodePoint': iconCodePoint,
        'tileColorValue': tileColorValue,
        'layoutType': layoutType,
      };

  factory VisionBoardInfo.fromJson(Map<String, dynamic> json) => VisionBoardInfo(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'Untitled',
        createdAtMs: (json['createdAtMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        iconCodePoint: (json['iconCodePoint'] as num?)?.toInt() ??
            Icons.dashboard_outlined.codePoint,
        tileColorValue: (json['tileColorValue'] as num?)?.toInt() ??
            const Color(0xFFEEF2FF).value,
        layoutType: json['layoutType'] as String? ?? VisionBoardInfo.layoutFreeform,
      );
}

/// Fixed set of board icons.
const List<IconData> kBoardIconOptions = [
  Icons.dashboard_outlined,
  Icons.flag_outlined,
  Icons.favorite_border,
  Icons.fitness_center_outlined,
  Icons.school_outlined,
  Icons.work_outline,
  Icons.attach_money,
  Icons.travel_explore,
  Icons.self_improvement_outlined,
  Icons.restaurant_outlined,
];

IconData boardIconFromCodePoint(int codePoint) {
  for (final icon in kBoardIconOptions) {
    if (icon.codePoint == codePoint) return icon;
  }
  return Icons.dashboard_outlined;
}

