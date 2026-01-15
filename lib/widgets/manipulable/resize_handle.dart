import 'package:flutter/material.dart';

enum HandlePosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class ResizeHandle extends StatelessWidget {
  final HandlePosition position;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final ValueChanged<DragUpdateDetails> onUpdate;

  const ResizeHandle({
    super.key,
    required this.position,
    required this.onStart,
    required this.onEnd,
    required this.onUpdate,
  });

  // Visual sizes (what you see)
  static const double cornerDiameter = 16;
  static const double edgeLength = 26;
  static const double edgeThickness = 8;

  // Touch target size (invisible). Keep large for usability.
  static const double touchSize = 30;

  static Alignment _alignmentFor(HandlePosition p) {
    return switch (p) {
      HandlePosition.topLeft => Alignment.topLeft,
      HandlePosition.topCenter => Alignment.topCenter,
      HandlePosition.topRight => Alignment.topRight,
      HandlePosition.centerLeft => Alignment.centerLeft,
      HandlePosition.centerRight => Alignment.centerRight,
      HandlePosition.bottomLeft => Alignment.bottomLeft,
      HandlePosition.bottomCenter => Alignment.bottomCenter,
      HandlePosition.bottomRight => Alignment.bottomRight,
    };
  }

  static Offset _borderOffsetFor(HandlePosition p) {
    // Center each handle on the selection border (half in / half out),
    // like the screenshot.
    return switch (p) {
      HandlePosition.topLeft => const Offset(-touchSize / 2, -touchSize / 2),
      HandlePosition.topCenter => const Offset(0, -touchSize / 2),
      HandlePosition.topRight => const Offset(touchSize / 2, -touchSize / 2),
      HandlePosition.centerLeft => const Offset(-touchSize / 2, 0),
      HandlePosition.centerRight => const Offset(touchSize / 2, 0),
      HandlePosition.bottomLeft => const Offset(-touchSize / 2, touchSize / 2),
      HandlePosition.bottomCenter => const Offset(0, touchSize / 2),
      HandlePosition.bottomRight => const Offset(touchSize / 2, touchSize / 2),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Match the screenshot's purple selection color.
    const stroke = Color(0xFF7C3AED);

    final bool isCorner = switch (position) {
      HandlePosition.topLeft ||
      HandlePosition.topRight ||
      HandlePosition.bottomLeft ||
      HandlePosition.bottomRight =>
        true,
      _ => false,
    };

    final Size size = isCorner
        ? const Size(cornerDiameter, cornerDiameter)
        : (position == HandlePosition.topCenter || position == HandlePosition.bottomCenter)
            ? const Size(edgeLength, edgeThickness)
            : const Size(edgeThickness, edgeLength);

    return Align(
      alignment: _alignmentFor(position),
      child: Transform.translate(
        offset: _borderOffsetFor(position),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onStart(),
          onPanEnd: (_) => onEnd(),
          onPanCancel: () => onEnd(),
          onPanUpdate: onUpdate,
          child: SizedBox(
            width: touchSize,
            height: touchSize,
            child: Center(
              child: Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: stroke, width: 2),
                  shape: isCorner ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCorner ? null : BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

