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
    case HandlePosition.topRight:
      newW = size.width + delta.dx;
      newH = size.height - delta.dy;
      posDelta = Offset(0, delta.dy);
      break;
    case HandlePosition.bottomLeft:
      newW = size.width - delta.dx;
      newH = size.height + delta.dy;
      posDelta = Offset(delta.dx, 0);
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
    if (handle == HandlePosition.topLeft || handle == HandlePosition.bottomLeft) {
      posDelta = Offset(posDelta.dx - diff, posDelta.dy);
    }
  }
  if (newH < minSize) {
    final diff = minSize - newH;
    newH = minSize;
    if (handle == HandlePosition.topLeft || handle == HandlePosition.topRight) {
      posDelta = Offset(posDelta.dx, posDelta.dy - diff);
    }
  }

  pos += posDelta;
  return (position: pos, size: Size(newW, newH));
}

