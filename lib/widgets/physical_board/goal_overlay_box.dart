import 'package:flutter/material.dart';

class GoalOverlayBox extends StatelessWidget {
  final String title;
  final bool isEditing;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  final void Function(DragStartDetails details)? onMoveStart;
  final void Function(DragUpdateDetails details)? onMoveUpdate;
  final void Function(DragEndDetails details)? onMoveEnd;

  final void Function(DragStartDetails details)? onResizeTlStart;
  final void Function(DragUpdateDetails details)? onResizeTlUpdate;
  final void Function(DragEndDetails details)? onResizeTlEnd;

  final void Function(DragStartDetails details)? onResizeTrStart;
  final void Function(DragUpdateDetails details)? onResizeTrUpdate;
  final void Function(DragEndDetails details)? onResizeTrEnd;

  final void Function(DragStartDetails details)? onResizeBlStart;
  final void Function(DragUpdateDetails details)? onResizeBlUpdate;
  final void Function(DragEndDetails details)? onResizeBlEnd;

  final void Function(DragStartDetails details)? onResizeBrStart;
  final void Function(DragUpdateDetails details)? onResizeBrUpdate;
  final void Function(DragEndDetails details)? onResizeBrEnd;

  const GoalOverlayBox({
    super.key,
    required this.title,
    required this.isEditing,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
    this.onMoveStart,
    this.onMoveUpdate,
    this.onMoveEnd,
    this.onResizeTlStart,
    this.onResizeTlUpdate,
    this.onResizeTlEnd,
    this.onResizeTrStart,
    this.onResizeTrUpdate,
    this.onResizeTrEnd,
    this.onResizeBlStart,
    this.onResizeBlUpdate,
    this.onResizeBlEnd,
    this.onResizeBrStart,
    this.onResizeBrUpdate,
    this.onResizeBrEnd,
  });

  static const _borderColor = Color(0xFF39FF14);
  static const _fillColor = Color(0x1A39FF14);

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? Theme.of(context).colorScheme.primary : _borderColor;
    final fillColor =
        isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.15) : _fillColor;
    final borderWidth = isSelected ? 3.0 : 2.0;

    Widget content = Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: borderWidth),
              color: fillColor,
            ),
          ),
        ),
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.70),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        if (isEditing && isSelected && onDelete != null)
          Positioned(
            right: 2,
            top: 2,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              iconSize: 18,
              tooltip: 'Delete goal',
              onPressed: onDelete,
              icon: const Icon(Icons.close, color: Colors.redAccent),
            ),
          ),
      ],
    );

    if (isEditing) {
      content = GestureDetector(
        onTap: onTap,
        onPanStart: onMoveStart,
        onPanUpdate: onMoveUpdate,
        onPanEnd: onMoveEnd,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    } else {
      content = InkWell(onTap: onTap, child: content);
    }

    if (!isEditing || !isSelected) return content;

    // Resize handles
    const handleSize = 16.0;
    Widget handle({
      required Alignment alignment,
      required void Function(DragStartDetails details)? onStart,
      required void Function(DragUpdateDetails details)? onUpdate,
      required void Function(DragEndDetails details)? onEnd,
    }) {
      return Align(
        alignment: alignment,
        child: GestureDetector(
          onPanStart: onStart,
          onPanUpdate: onUpdate,
          onPanEnd: onEnd,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        content,
        handle(alignment: Alignment.topLeft, onStart: onResizeTlStart, onUpdate: onResizeTlUpdate, onEnd: onResizeTlEnd),
        handle(alignment: Alignment.topRight, onStart: onResizeTrStart, onUpdate: onResizeTrUpdate, onEnd: onResizeTrEnd),
        handle(alignment: Alignment.bottomLeft, onStart: onResizeBlStart, onUpdate: onResizeBlUpdate, onEnd: onResizeBlEnd),
        handle(alignment: Alignment.bottomRight, onStart: onResizeBrStart, onUpdate: onResizeBrUpdate, onEnd: onResizeBrEnd),
      ],
    );
  }
}

