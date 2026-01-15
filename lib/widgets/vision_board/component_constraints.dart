import 'package:flutter/material.dart';

import '../../models/vision_components.dart';

const double kVisionComponentMinSize = 40.0;

VisionComponent constrainComponentToViewport(
  VisionComponent component,
  Size viewportSize,
) {
  final constrainedWidth =
      component.size.width.clamp(kVisionComponentMinSize, viewportSize.width);
  final constrainedHeight =
      component.size.height.clamp(kVisionComponentMinSize, viewportSize.height);

  final effectiveWidth = constrainedWidth * component.scale;
  final effectiveHeight = constrainedHeight * component.scale;

  final maxX = (viewportSize.width - effectiveWidth).clamp(0.0, viewportSize.width);
  final maxY = (viewportSize.height - effectiveHeight).clamp(0.0, viewportSize.height);

  final constrainedPosition = Offset(
    component.position.dx.clamp(0.0, maxX),
    component.position.dy.clamp(0.0, maxY),
  );

  return component.copyWithCommon(
    position: constrainedPosition,
    size: Size(constrainedWidth, constrainedHeight),
  );
}

