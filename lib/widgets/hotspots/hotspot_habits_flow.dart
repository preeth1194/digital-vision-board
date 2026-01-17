import 'package:flutter/material.dart';

import '../../models/hotspot_model.dart';
import '../../models/vision_components.dart';
import '../habit_tracker_sheet.dart';

bool _matchesHotspot(HotspotModel a, HotspotModel b) {
  final coordinatesMatch = (a.x - b.x).abs() < 0.0001 &&
      (a.y - b.y).abs() < 0.0001 &&
      (a.width - b.width).abs() < 0.0001 &&
      (a.height - b.height).abs() < 0.0001;
  final idMatch = a.id == b.id || (a.id == null && b.id == null);
  final linkMatch = a.link == b.link || (a.link == null && b.link == null);
  return coordinatesMatch && idMatch && linkMatch;
}

Future<void> openHabitTrackerForHotspot({
  required BuildContext context,
  required HotspotModel hotspot,
  required Size imageSize,
  required List<HotspotModel> hotspots,
  required ValueChanged<List<HotspotModel>>? onHotspotsChanged,
}) async {
  final VisionComponent component = convertHotspotToComponent(hotspot, imageSize);
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return HabitTrackerSheet(
        boardId: null,
        component: component,
        onComponentUpdated: (updatedComponent) {
          final updatedHotspot = hotspot.copyWith(habits: updatedComponent.habits);
          final updatedHotspots =
              hotspots.map((h) => _matchesHotspot(h, hotspot) ? updatedHotspot : h).toList();
          onHotspotsChanged?.call(updatedHotspots);
        },
      );
    },
  );
}

