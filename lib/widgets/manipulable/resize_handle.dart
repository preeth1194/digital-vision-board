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

  static const double cornerDiameter = 16;
  static const double edgeLength = 22;
  static const double edgeThickness = 10;

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
    // Nudge handles slightly outside the selection border, like the screenshot.
    const double o = 6;
    return switch (p) {
      HandlePosition.topLeft => const Offset(-o, -o),
      HandlePosition.topCenter => const Offset(0, -o),
      HandlePosition.topRight => const Offset(o, -o),
      HandlePosition.centerLeft => const Offset(-o, 0),
      HandlePosition.centerRight => const Offset(o, 0),
      HandlePosition.bottomLeft => const Offset(-o, o),
      HandlePosition.bottomCenter => const Offset(0, o),
      HandlePosition.bottomRight => const Offset(o, o),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stroke = cs.primary;

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
    );
  }
}

