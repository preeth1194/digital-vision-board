import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hotspot_model.dart';
import 'zone_component.dart';

/// Legacy compatibility: convert a normalized `HotspotModel` into a pixel-space
/// `ZoneComponent` on a canvas whose background image is laid out at
/// `originalImageSize`.
ZoneComponent convertHotspotToComponent(
  HotspotModel hotspot,
  Size originalImageSize,
) {
  final id = (hotspot.id != null && hotspot.id!.trim().isNotEmpty)
      ? hotspot.id!.trim()
      : 'zone_${math.Random().nextInt(1 << 32)}';

  return ZoneComponent(
    id: id,
    position: Offset(
      hotspot.x * originalImageSize.width,
      hotspot.y * originalImageSize.height,
    ),
    size: Size(
      hotspot.width * originalImageSize.width,
      hotspot.height * originalImageSize.height,
    ),
    rotation: 0,
    scale: 1,
    zIndex: 0,
    habits: hotspot.habits,
    link: hotspot.link,
  );
}

