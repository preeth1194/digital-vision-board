import 'package:flutter/material.dart';

import '../../models/hotspot_model.dart';

class HotspotOverlay extends StatelessWidget {
  final HotspotModel hotspot;
  final bool isEditing;
  final bool isSelected;
  final bool showLabels;

  final Color hotspotBorderColor;
  final Color hotspotFillColor;
  final Color selectedHotspotBorderColor;
  final Color selectedHotspotFillColor;
  final double hotspotBorderWidth;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const HotspotOverlay({
    super.key,
    required this.hotspot,
    required this.isEditing,
    required this.isSelected,
    required this.showLabels,
    required this.hotspotBorderColor,
    required this.hotspotFillColor,
    required this.selectedHotspotBorderColor,
    required this.selectedHotspotFillColor,
    required this.hotspotBorderWidth,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final hasLink = hotspot.link != null && hotspot.link!.isNotEmpty;

    final borderColor = isSelected ? selectedHotspotBorderColor : hotspotBorderColor;
    final fillColor = isSelected ? selectedHotspotFillColor : hotspotFillColor;
    final borderWidth = isSelected ? 3.0 : hotspotBorderWidth;

    final overlay = Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: borderWidth),
            color: fillColor,
          ),
        ),
        if (showLabels && hotspot.id != null && hotspot.id!.isNotEmpty)
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                hotspot.id!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (!isEditing && hasLink)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.open_in_new,
                size: 12,
                color: Color(0xFF39FF14),
              ),
            ),
          ),
      ],
    );

    if (isEditing) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: overlay,
      );
    }

    return InkWell(onTap: onTap, child: overlay);
  }
}

