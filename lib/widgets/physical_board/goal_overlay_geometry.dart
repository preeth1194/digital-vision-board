import 'dart:math' as math;

import 'package:flutter/material.dart';

Offset transformPoint(Matrix4 matrix, Offset point) {
  final x = point.dx;
  final y = point.dy;
  final resultX = matrix[0] * x + matrix[4] * y + matrix[12];
  final resultY = matrix[1] * x + matrix[5] * y + matrix[13];
  return Offset(resultX, resultY);
}

/// Compute the displayed image bounds (in container coordinates) for an image
/// rendered as `BoxFit.contain` inside `containerSize`.
Rect getImageBounds(Size containerSize, Size imageSize) {
  final imageAspectRatio = imageSize.width / imageSize.height;
  final containerAspectRatio = containerSize.width / containerSize.height;

  double displayWidth;
  double displayHeight;
  double offsetX = 0;
  double offsetY = 0;

  if (imageAspectRatio > containerAspectRatio) {
    displayWidth = containerSize.width;
    displayHeight = containerSize.width / imageAspectRatio;
    offsetY = (containerSize.height - displayHeight) / 2;
  } else {
    displayHeight = containerSize.height;
    displayWidth = containerSize.height * imageAspectRatio;
    offsetX = (containerSize.width - displayWidth) / 2;
  }

  return Rect.fromLTWH(offsetX, offsetY, displayWidth, displayHeight);
}

/// Convert a point in container coordinates to a point in **image pixels**
/// (0..imageSize.width, 0..imageSize.height), accounting for the current
/// `InteractiveViewer` transform.
Offset? screenToImagePixel({
  required Offset screenPoint,
  required Size containerSize,
  required Size imageSize,
  required Matrix4 transform,
}) {
  final imageBounds = getImageBounds(containerSize, imageSize);

  var p = screenPoint;
  if (!transform.isIdentity()) {
    final inverted = Matrix4.inverted(transform);
    p = transformPoint(inverted, p);
  }

  if (!imageBounds.contains(p)) return null;

  final nx = (p.dx - imageBounds.left) / imageBounds.width;
  final ny = (p.dy - imageBounds.top) / imageBounds.height;

  final px = (nx * imageSize.width).clamp(0.0, imageSize.width);
  final py = (ny * imageSize.height).clamp(0.0, imageSize.height);
  return Offset(px, py);
}

/// Convert an image-pixel rect to a rect in container coordinates, accounting
/// for the current `InteractiveViewer` transform.
Rect imagePixelRectToScreenRect({
  required Rect rectPx,
  required Size containerSize,
  required Size imageSize,
  required Matrix4 transform,
}) {
  final imageBounds = getImageBounds(containerSize, imageSize);

  final nx = rectPx.left / imageSize.width;
  final ny = rectPx.top / imageSize.height;
  final nw = rectPx.width / imageSize.width;
  final nh = rectPx.height / imageSize.height;

  final screenX = imageBounds.left + (nx * imageBounds.width);
  final screenY = imageBounds.top + (ny * imageBounds.height);
  final screenW = nw * imageBounds.width;
  final screenH = nh * imageBounds.height;

  if (!transform.isIdentity()) {
    final topLeft = transformPoint(transform, Offset(screenX, screenY));
    final topRight = transformPoint(transform, Offset(screenX + screenW, screenY));
    final bottomLeft = transformPoint(transform, Offset(screenX, screenY + screenH));
    final bottomRight = transformPoint(transform, Offset(screenX + screenW, screenY + screenH));

    final minX = math.min(math.min(topLeft.dx, topRight.dx), math.min(bottomLeft.dx, bottomRight.dx));
    final maxX = math.max(math.max(topLeft.dx, topRight.dx), math.max(bottomLeft.dx, bottomRight.dx));
    final minY = math.min(math.min(topLeft.dy, topRight.dy), math.min(bottomLeft.dy, bottomRight.dy));
    final maxY = math.max(math.max(topLeft.dy, topRight.dy), math.max(bottomLeft.dy, bottomRight.dy));

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  return Rect.fromLTWH(screenX, screenY, screenW, screenH);
}

