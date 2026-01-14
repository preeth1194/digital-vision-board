import 'package:flutter/material.dart';

enum HandlePosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

class ResizeHandle extends StatelessWidget {
  final Alignment alignment;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final ValueChanged<DragUpdateDetails> onUpdate;

  const ResizeHandle({
    super.key,
    required this.alignment,
    required this.onStart,
    required this.onEnd,
    required this.onUpdate,
  });

  static const double handleSize = 14;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onStart(),
        onPanEnd: (_) => onEnd(),
        onPanCancel: () => onEnd(),
        onPanUpdate: onUpdate,
        child: Container(
          width: handleSize,
          height: handleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

