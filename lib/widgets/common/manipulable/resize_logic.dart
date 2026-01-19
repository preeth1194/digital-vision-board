import 'package:flutter/material.dart';

import 'resize_handle.dart';

({Offset position, Size size}) applyResizeDelta({
  required Offset position,
  required Size size,
  required HandlePosition handle,
  required Offset delta,
  required double minSize,
}) {
  var pos = position;
  var newW = size.width;
  var newH = size.height;
  var posDelta = Offset.zero;

  switch (handle) {
    case HandlePosition.topLeft:
      newW = size.width - delta.dx;
      newH = size.height - delta.dy;
      posDelta = Offset(delta.dx, delta.dy);
      break;
    case HandlePosition.topCenter:
      newH = size.height - delta.dy;
      posDelta = Offset(0, delta.dy);
      break;
    case HandlePosition.topRight:
      newW = size.width + delta.dx;
      newH = size.height - delta.dy;
      posDelta = Offset(0, delta.dy);
      break;
    case HandlePosition.centerLeft:
      newW = size.width - delta.dx;
      posDelta = Offset(delta.dx, 0);
      break;
    case HandlePosition.centerRight:
      newW = size.width + delta.dx;
      posDelta = Offset.zero;
      break;
    case HandlePosition.bottomLeft:
      newW = size.width - delta.dx;
      newH = size.height + delta.dy;
      posDelta = Offset(delta.dx, 0);
      break;
    case HandlePosition.bottomCenter:
      newH = size.height + delta.dy;
      posDelta = Offset.zero;
      break;
    case HandlePosition.bottomRight:
      newW = size.width + delta.dx;
      newH = size.height + delta.dy;
      posDelta = Offset.zero;
      break;
  }

  if (newW < minSize) {
    final diff = minSize - newW;
    newW = minSize;
    if (handle == HandlePosition.topLeft ||
        handle == HandlePosition.bottomLeft ||
        handle == HandlePosition.centerLeft) {
      posDelta = Offset(posDelta.dx - diff, posDelta.dy);
    }
  }
  if (newH < minSize) {
    final diff = minSize - newH;
    newH = minSize;
    if (handle == HandlePosition.topLeft ||
        handle == HandlePosition.topRight ||
        handle == HandlePosition.topCenter) {
      posDelta = Offset(posDelta.dx, posDelta.dy - diff);
    }
  }

  pos += posDelta;
  return (position: pos, size: Size(newW, newH));
}

