import 'package:flutter/material.dart';

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
                        border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
                      ),
                    ),
                  ),
                ),
                ResizeHandle(
                  alignment: Alignment.topLeft,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.topLeft, d),
                ),
                ResizeHandle(
                  alignment: Alignment.topRight,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.topRight, d),
                ),
                ResizeHandle(
                  alignment: Alignment.bottomLeft,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.bottomLeft, d),
                ),
                ResizeHandle(
                  alignment: Alignment.bottomRight,
                  onStart: () => _setResizing(true),
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.bottomRight, d),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

