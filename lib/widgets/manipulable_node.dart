import 'package:flutter/material.dart';

import '../models/vision_component.dart';

typedef ComponentChanged = void Function(VisionComponent component);

/// A Canva-like wrapper that supports drag, pinch-to-zoom, and rotation,
/// plus selection UI with resize handles.
class ManipulableNode extends StatefulWidget {
  final VisionComponent component;
  final bool isSelected;
  final bool gesturesEnabled;
  final Widget child;

  final VoidCallback onSelected;
  final VoidCallback onOpen;
  final ComponentChanged onChanged;

  const ManipulableNode({
    super.key,
    required this.component,
    required this.isSelected,
    required this.gesturesEnabled,
    required this.child,
    required this.onSelected,
    required this.onOpen,
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

    final next = widget.component.copyWithCommon(
      position: widget.component.position + details.focalPointDelta,
      scale: (_startScale * details.scale).clamp(0.2, 8.0),
      rotation: _startRotation + details.rotation,
    );
    _emit(next);
  }

  void _setResizing(bool v) {
    if (_isResizing == v) return;
    setState(() => _isResizing = v);
  }

  void _resizeFromCorner(_Corner corner, DragUpdateDetails details) {
    if (!widget.gesturesEnabled) return;
    if (!widget.isSelected) return;

    final delta = details.delta / widget.component.scale;
    var pos = widget.component.position;
    var size = widget.component.size;

    double newW = size.width;
    double newH = size.height;

    Offset posDelta = Offset.zero;

    switch (corner) {
      case _Corner.topLeft:
        newW = size.width - delta.dx;
        newH = size.height - delta.dy;
        posDelta = Offset(delta.dx, delta.dy);
        break;
      case _Corner.topRight:
        newW = size.width + delta.dx;
        newH = size.height - delta.dy;
        posDelta = Offset(0, delta.dy);
        break;
      case _Corner.bottomLeft:
        newW = size.width - delta.dx;
        newH = size.height + delta.dy;
        posDelta = Offset(delta.dx, 0);
        break;
      case _Corner.bottomRight:
        newW = size.width + delta.dx;
        newH = size.height + delta.dy;
        posDelta = Offset.zero;
        break;
    }

    // Clamp size and adjust position deltas accordingly.
    if (newW < _minSize) {
      final diff = _minSize - newW;
      newW = _minSize;
      if (corner == _Corner.topLeft || corner == _Corner.bottomLeft) {
        posDelta = Offset(posDelta.dx - diff, posDelta.dy);
      }
    }
    if (newH < _minSize) {
      final diff = _minSize - newH;
      newH = _minSize;
      if (corner == _Corner.topLeft || corner == _Corner.topRight) {
        posDelta = Offset(posDelta.dx, posDelta.dy - diff);
      }
    }

    pos += posDelta;

    _emit(widget.component.copyWithCommon(position: pos, size: Size(newW, newH)));
  }

  Widget _handle(_Corner corner, Alignment alignment) {
    return Align(
      alignment: alignment,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _setResizing(true),
        onPanEnd: (_) => _setResizing(false),
        onPanCancel: () => _setResizing(false),
        onPanUpdate: (d) => _resizeFromCorner(corner, d),
        child: Container(
          width: _handleSize,
          height: _handleSize,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue, width: 2),
            borderRadius: BorderRadius.circular(3),
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
            widget.onOpen();
            return;
          }

          widget.onSelected();
          if (!_isResizing) {
            widget.onOpen();
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
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                    ),
                  ),
                ),
                _handle(_Corner.topLeft, Alignment.topLeft),
                _handle(_Corner.topRight, Alignment.topRight),
                _handle(_Corner.bottomLeft, Alignment.bottomLeft),
                _handle(_Corner.bottomRight, Alignment.bottomRight),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _Corner { topLeft, topRight, bottomLeft, bottomRight }

