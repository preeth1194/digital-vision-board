import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../models/vision_components.dart';
import 'manipulable/resize_handle.dart';
import 'manipulable/resize_logic.dart';

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
  static const double _rotateButtonDiameter = 44;
  static const Color _selectionPurple = Color(0xFF7C3AED);

  final GlobalKey _boxKey = GlobalKey();

  bool _isResizing = false;
  bool _isRotating = false;

  late double _startScale;
  late double _startRotation;
  late double _rotateStartAngle;

  @override
  void initState() {
    super.initState();
    _startScale = widget.component.scale;
    _startRotation = widget.component.rotation;
    _rotateStartAngle = 0;
  }

  @override
  void didUpdateWidget(covariant ManipulableNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.component != widget.component) {
      _startScale = widget.component.scale;
      _startRotation = widget.component.rotation;
    }
  }

  void _emit(VisionComponent next) {
    widget.onChanged(next);
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.gesturesEnabled) return;
    _startScale = widget.component.scale;
    _startRotation = widget.component.rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.gesturesEnabled) return;
    if (!widget.isSelected) return;
    if (_isResizing) return;
    if (_isRotating) return;

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

  void _setRotating(bool v) {
    if (_isRotating == v) return;
    setState(() => _isRotating = v);
  }

  void _resize(HandlePosition handle, DragUpdateDetails details) {
    if (!widget.gesturesEnabled) return;
    if (!widget.isSelected) return;

    final delta = details.delta / widget.component.scale;
    final resized = applyResizeDelta(
      position: widget.component.position,
      size: widget.component.size,
      handle: handle,
      delta: delta,
      minSize: _minSize,
    );

    _emit(
      widget.component.copyWithCommon(
        position: resized.position,
        size: resized.size,
      ),
    );
  }

  void _onRotateStart(DragStartDetails details) {
    if (!widget.gesturesEnabled) return;
    if (!widget.isSelected) return;
    final ctx = _boxKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    _startRotation = widget.component.rotation;
    final centerGlobal = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
    final v = details.globalPosition - centerGlobal;
    _rotateStartAngle = math.atan2(v.dy, v.dx);
    _setRotating(true);
  }

  void _onRotateUpdate(DragUpdateDetails details) {
    if (!widget.gesturesEnabled) return;
    if (!widget.isSelected) return;
    final ctx = _boxKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;

    final centerGlobal = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
    final v = details.globalPosition - centerGlobal;
    final angle = math.atan2(v.dy, v.dx);
    final delta = angle - _rotateStartAngle;
    _emit(widget.component.copyWithCommon(rotation: _startRotation + delta));
  }

  void _onRotateEnd([DragEndDetails? _]) => _setRotating(false);

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
        key: _boxKey,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!widget.gesturesEnabled) return widget.onOpen?.call();
          widget.onSelected();
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
                        border: Border.all(color: _selectionPurple, width: 3),
                      ),
                    ),
                  ),
                ),
                ResizeHandle(
                  position: HandlePosition.topLeft,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.topLeft, d),
                ),
                ResizeHandle(
                  position: HandlePosition.topCenter,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.topCenter, d),
                ),
                ResizeHandle(
                  position: HandlePosition.topRight,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.topRight, d),
                ),
                ResizeHandle(
                  position: HandlePosition.centerLeft,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.centerLeft, d),
                ),
                ResizeHandle(
                  position: HandlePosition.centerRight,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.centerRight, d),
                ),
                ResizeHandle(
                  position: HandlePosition.bottomLeft,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.bottomLeft, d),
                ),
                ResizeHandle(
                  position: HandlePosition.bottomCenter,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.bottomCenter, d),
                ),
                ResizeHandle(
                  position: HandlePosition.bottomRight,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.bottomRight, d),
                ),
                Positioned(
                  // Fully outside, with a small gap like the screenshot.
                  right: -(_rotateButtonDiameter / 2) - 8,
                  top: (c.size.height - _rotateButtonDiameter) / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _onRotateStart,
                    onPanUpdate: _onRotateUpdate,
                    onPanEnd: _onRotateEnd,
                    onPanCancel: () => _setRotating(false),
                    child: Container(
                      width: _rotateButtonDiameter,
                      height: _rotateButtonDiameter,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.black12, width: 1),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.rotate_right, size: 22, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

