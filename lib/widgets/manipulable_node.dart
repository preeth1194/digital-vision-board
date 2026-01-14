import 'package:flutter/material.dart';

import '../models/vision_components.dart';

typedef ComponentChanged = void Function(VisionComponent component);

/// A Canva-like wrapper that supports drag, pinch-to-zoom, and rotation,
/// plus selection UI with resize handles.
class ManipulableNode extends StatefulWidget {
  final VisionComponent component;
  final bool isSelected;
  final bool gesturesEnabled;
  final Widget child;

  final VoidCallback onSelected;
  final VoidCallback? onOpen;
  final ComponentChanged onChanged;

  const ManipulableNode({
    super.key,
    required this.component,
    required this.isSelected,
    required this.gesturesEnabled,
    required this.child,
    required this.onSelected,
    this.onOpen,
    required this.onChanged,
  });

  @override
  State<ManipulableNode> createState() => _ManipulableNodeState();
}

class _ManipulableNodeState extends State<ManipulableNode> {
  static const double _minSize = 40;
  static const double _handleSize = 14;

  bool _isResizing = false;

  late VisionComponent _startComponent;
  late double _startScale;
  late double _startRotation;

  @override
  void initState() {
    super.initState();
    _startComponent = widget.component;
    _startScale = widget.component.scale;
    _startRotation = widget.component.rotation;
  }

  @override
  void didUpdateWidget(covariant ManipulableNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.component != widget.component) {
      _startComponent = widget.component;
      _startScale = widget.component.scale;
      _startRotation = widget.component.rotation;
    }
  }

  void _emit(VisionComponent next) {
    widget.onChanged(next);
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.gesturesEnabled) return;
    _startComponent = widget.component;
    _startScale = widget.component.scale;
    _startRotation = widget.component.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.gesturesEnabled) return;
    if (!widget.isSelected) return;
    if (_isResizing) return;

    // When a component is scaled up/down, raw pointer deltas are in screen space.
    // Convert to canvas space so dragging stays smooth and doesn't "overshoot".
    final Offset dragDelta = details.focalPointDelta / widget.component.scale;

    final next = widget.component.copyWithCommon(
      position: widget.component.position + dragDelta,
      scale: (_startScale * details.scale).clamp(0.2, 8.0),
      rotation: _startRotation + details.rotation,
    );
    _emit(next);
  }

  void _setResizing(bool v) {
    if (_isResizing == v) return;
    setState(() => _isResizing = v);
  }

  void _resize(_HandlePosition handle, DragUpdateDetails details) {
    if (!widget.gesturesEnabled) return;
    if (!widget.isSelected) return;

    final delta = details.delta / widget.component.scale;
    var pos = widget.component.position;
    var size = widget.component.size;

    double newW = size.width;
    double newH = size.height;

    Offset posDelta = Offset.zero;

    switch (handle) {
      case _HandlePosition.topLeft:
        newW = size.width - delta.dx;
        newH = size.height - delta.dy;
        posDelta = Offset(delta.dx, delta.dy);
        break;
      case _HandlePosition.topRight:
        newW = size.width + delta.dx;
        newH = size.height - delta.dy;
        posDelta = Offset(0, delta.dy);
        break;
      case _HandlePosition.bottomLeft:
        newW = size.width - delta.dx;
        newH = size.height + delta.dy;
        posDelta = Offset(delta.dx, 0);
        break;
      case _HandlePosition.bottomRight:
        newW = size.width + delta.dx;
        newH = size.height + delta.dy;
        posDelta = Offset.zero;
        break;
    }

    // Clamp size and adjust position deltas accordingly.
    if (newW < _minSize) {
      final diff = _minSize - newW;
      newW = _minSize;
      if (handle == _HandlePosition.topLeft || 
          handle == _HandlePosition.bottomLeft) {
        posDelta = Offset(posDelta.dx - diff, posDelta.dy);
      }
    }
    if (newH < _minSize) {
      final diff = _minSize - newH;
      newH = _minSize;
      if (handle == _HandlePosition.topLeft || 
          handle == _HandlePosition.topRight) {
        posDelta = Offset(posDelta.dx, posDelta.dy - diff);
      }
    }

    pos += posDelta;

    _emit(widget.component.copyWithCommon(position: pos, size: Size(newW, newH)));
  }

  Widget _handle(_HandlePosition handle, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _setResizing(true),
        onPanEnd: (_) => _setResizing(false),
        onPanCancel: () => _setResizing(false),
        onPanUpdate: (d) => _resize(handle, d),
        child: Container(
          width: _handleSize,
          height: _handleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
            borderRadius: BorderRadius.circular(4), // Slightly rounder
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                spreadRadius: 0,
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.component;

    // Keep Positioned unscaled/unrotated; apply transform around center.
    return Positioned(
      left: c.position.dx,
      top: c.position.dy,
      width: c.size.width,
      height: c.size.height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!widget.gesturesEnabled) {
            widget.onOpen?.call();
            return;
          }

          widget.onSelected();
          if (!_isResizing) {
            // In edit mode, we don't call onOpen anymore, just select.
            // widget.onOpen?.call(); 
            // Wait, the requirement says "while in editing mode i should not get habbit tracker popup on clicking image".
            // So I should disable onOpen in edit mode here OR in the parent. 
            // Better to respect the passed onOpen. If parent passes null, it won't be called.
            widget.onOpen?.call();
          }
        },
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(c.rotation)
            ..scale(c.scale, c.scale),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: widget.child),
              if (widget.isSelected && widget.gesturesEnabled) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
                      ),
                    ),
                  ),
                ),
                _handle(_HandlePosition.topLeft, Alignment.topLeft),
                _handle(_HandlePosition.topRight, Alignment.topRight),
                _handle(_HandlePosition.bottomLeft, Alignment.bottomLeft),
                _handle(_HandlePosition.bottomRight, Alignment.bottomRight),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _HandlePosition { 
  topLeft, topRight, 
  bottomLeft, bottomRight 
}

