import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/hotspot_model.dart';

Offset transformPoint(Matrix4 matrix, Offset point) {
  final x = point.dx;
  final y = point.dy;
  final resultX = matrix[0] * x + matrix[4] * y + matrix[12];
  final resultY = matrix[1] * x + matrix[5] * y + matrix[13];
  return Offset(resultX, resultY);
}

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

Offset? screenToImageCoordinates({
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

  final normalizedX = (p.dx - imageBounds.left) / imageBounds.width;
  final normalizedY = (p.dy - imageBounds.top) / imageBounds.height;

  return Offset(
    normalizedX.clamp(0.0, 1.0),
    normalizedY.clamp(0.0, 1.0),
  );
}

Rect imageToScreenRect({
  required HotspotModel hotspot,
  required Size containerSize,
  required Size imageSize,
  required Matrix4 transform,
}) {
  final imageBounds = getImageBounds(containerSize, imageSize);

  final screenX = imageBounds.left + (hotspot.x * imageBounds.width);
  final screenY = imageBounds.top + (hotspot.y * imageBounds.height);
  final screenWidth = hotspot.width * imageBounds.width;
  final screenHeight = hotspot.height * imageBounds.height;

  if (!transform.isIdentity()) {
    final topLeft = transformPoint(transform, Offset(screenX, screenY));
    final topRight = transformPoint(transform, Offset(screenX + screenWidth, screenY));
    final bottomLeft = transformPoint(transform, Offset(screenX, screenY + screenHeight));
    final bottomRight =
        transformPoint(transform, Offset(screenX + screenWidth, screenY + screenHeight));

    final minX = math.min(math.min(topLeft.dx, topRight.dx), math.min(bottomLeft.dx, bottomRight.dx));
    final maxX = math.max(math.max(topLeft.dx, topRight.dx), math.max(bottomLeft.dx, bottomRight.dx));
    final minY = math.min(math.min(topLeft.dy, topRight.dy), math.min(bottomLeft.dy, bottomRight.dy));
    final maxY = math.max(math.max(topLeft.dy, topRight.dy), math.max(bottomLeft.dy, bottomRight.dy));

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  return Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight);
}

Widget buildDrawingRectangle({
  required Size containerSize,
  required Size imageSize,
  required Matrix4 transform,
  required Offset dragStart,
  required Offset dragEnd,
  required Color borderColor,
  required Color fillColor,
  required double borderWidth,
}) {
  final imageBounds = getImageBounds(containerSize, imageSize);

  final startX = imageBounds.left + (dragStart.dx * imageBounds.width);
  final startY = imageBounds.top + (dragStart.dy * imageBounds.height);
  final endX = imageBounds.left + (dragEnd.dx * imageBounds.width);
  final endY = imageBounds.top + (dragEnd.dy * imageBounds.height);

  final left = math.min(startX, endX);
  final top = math.min(startY, endY);
  final width = (startX - endX).abs();
  final height = (startY - endY).abs();

  Rect rect = Rect.fromLTWH(left, top, width, height);
  if (!transform.isIdentity()) {
    final topLeft = transformPoint(transform, rect.topLeft);
    final topRight = transformPoint(transform, rect.topRight);
    final bottomLeft = transformPoint(transform, rect.bottomLeft);
    final bottomRight = transformPoint(transform, rect.bottomRight);

    final minX = math.min(math.min(topLeft.dx, topRight.dx), math.min(bottomLeft.dx, bottomRight.dx));
    final maxX = math.max(math.max(topLeft.dx, topRight.dx), math.max(bottomLeft.dx, bottomRight.dx));
    final minY = math.min(math.min(topLeft.dy, topRight.dy), math.min(bottomLeft.dy, bottomRight.dy));
    final maxY = math.max(math.max(topLeft.dy, topRight.dy), math.max(bottomLeft.dy, bottomRight.dy));

    rect = Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  return Positioned(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    child: Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: borderWidth),
        color: fillColor,
      ),
    ),
  );
}

