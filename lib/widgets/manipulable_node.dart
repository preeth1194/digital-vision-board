import 'package:flutter/material.dart';

import '../models/vision_components.dart';
import '../utils/app_colors.dart';
import 'manipulable/resize_handle.dart';
import 'manipulable/resize_logic.dart';

typedef ComponentChanged = void Function(VisionComponent component);

/// A Canva-like wrapper that supports drag plus selection UI with resize handles.
class ManipulableNode extends StatefulWidget {
  final VisionComponent component;
  /// Global canvas scale applied by the parent (template fit-to-viewport).
  /// Pointer deltas need to be divided by this to stay in canvas coordinates.
  final double canvasScale;
  final bool isSelected;
  final bool gesturesEnabled;
  final Widget child;

  final VoidCallback onSelected;
  final VoidCallback? onOpen;
  final ComponentChanged onChanged;

  const ManipulableNode({
    super.key,
    required this.component,
    this.canvasScale = 1.0,
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
  static const Color _selectionBorderColor = Colors.white;
  static const List<BoxShadow> _viewSelectionShadow = [
    BoxShadow(
      color: AppColors.shadowMedium,
      blurRadius: 14,
      spreadRadius: 2,
      offset: Offset(0, 6),
    ),
  ];
  static const List<BoxShadow> _editSelectionShadow = [
    BoxShadow(
      color: AppColors.shadowLight,
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  final GlobalKey _boxKey = GlobalKey();

  bool _isResizing = false;
  HandlePosition? _selectedResizeHandle;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ManipulableNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected && !widget.isSelected) {
      _selectedResizeHandle = null;
      _isResizing = false;
    }
  }

  void _emit(VisionComponent next) {
    widget.onChanged(next);
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.gesturesEnabled) return;
    if (!widget.isSelected) return;
    if (_isResizing) return;

    // When a component is dragged, convert pointer deltas to canvas space
    // Account for the component's current scale to ensure smooth dragging
    final denom = (widget.component.scale > 0 ? widget.component.scale : 1.0) * (widget.canvasScale > 0 ? widget.canvasScale : 1.0);
    final Offset dragDelta = details.focalPointDelta / denom;

    final next = widget.component.copyWithCommon(
      position: widget.component.position + dragDelta,
      // Disable pinch zoom/rotate; use resize handles + rotate handle instead.
      scale: widget.component.scale,
      rotation: widget.component.rotation,
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
    if (_selectedResizeHandle != handle) return;

    final denom = (widget.component.scale > 0 ? widget.component.scale : 1.0) * (widget.canvasScale > 0 ? widget.canvasScale : 1.0);
    final delta = details.delta / denom;
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
        key: _boxKey,
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // In view mode we still want selection highlight, then open.
          widget.onSelected();
          if (!widget.gesturesEnabled) {
            widget.onOpen?.call();
            return;
          }
        },
        onScaleStart: widget.gesturesEnabled && widget.isSelected
            ? (details) {
                // Mark that we're starting a drag
              }
            : null,
        onScaleUpdate: widget.gesturesEnabled && widget.isSelected
            ? _onScaleUpdate
            : null,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(c.rotation)
            ..scaleByDouble(c.scale, c.scale, 1, 1),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: widget.child),
              if (widget.isSelected) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _selectionBorderColor, width: 3),
                        boxShadow: widget.gesturesEnabled ? _editSelectionShadow : _viewSelectionShadow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (!widget.gesturesEnabled) const SizedBox.shrink(),
                if (widget.gesturesEnabled) ...[
                ResizeHandle(
                  position: HandlePosition.topLeft,
                  isSelected: _selectedResizeHandle == HandlePosition.topLeft,
                  onSelected: () =>
                      setState(() => _selectedResizeHandle = HandlePosition.topLeft),
                  onStart: () {
                    setState(() => _selectedResizeHandle = HandlePosition.topLeft);
                    _setResizing(true);
                  },
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.topLeft, d),
                ),
                ResizeHandle(
                  position: HandlePosition.topCenter,
                  isSelected: _selectedResizeHandle == HandlePosition.topCenter,
                  onSelected: () =>
                      setState(() => _selectedResizeHandle = HandlePosition.topCenter),
                  onStart: () {
                    setState(() => _selectedResizeHandle = HandlePosition.topCenter);
                    _setResizing(true);
                  },
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.topCenter, d),
                ),
                ResizeHandle(
                  position: HandlePosition.topRight,
                  isSelected: _selectedResizeHandle == HandlePosition.topRight,
                  onSelected: () =>
                      setState(() => _selectedResizeHandle = HandlePosition.topRight),
                  onStart: () {
                    setState(() => _selectedResizeHandle = HandlePosition.topRight);
                    _setResizing(true);
                  },
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.topRight, d),
                ),
                ResizeHandle(
                  position: HandlePosition.centerLeft,
                  isSelected: _selectedResizeHandle == HandlePosition.centerLeft,
                  onSelected: () =>
                      setState(() => _selectedResizeHandle = HandlePosition.centerLeft),
                  onStart: () {
                    setState(() => _selectedResizeHandle = HandlePosition.centerLeft);
                    _setResizing(true);
                  },
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.centerLeft, d),
                ),
                ResizeHandle(
                  position: HandlePosition.centerRight,
                  isSelected: _selectedResizeHandle == HandlePosition.centerRight,
                  onSelected: () =>
                      setState(() => _selectedResizeHandle = HandlePosition.centerRight),
                  onStart: () {
                    setState(() => _selectedResizeHandle = HandlePosition.centerRight);
                    _setResizing(true);
                  },
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.centerRight, d),
                ),
                ResizeHandle(
                  position: HandlePosition.bottomLeft,
                  isSelected: _selectedResizeHandle == HandlePosition.bottomLeft,
                  onSelected: () =>
                      setState(() => _selectedResizeHandle = HandlePosition.bottomLeft),
                  onStart: () {
                    setState(() => _selectedResizeHandle = HandlePosition.bottomLeft);
                    _setResizing(true);
                  },
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.bottomLeft, d),
                ),
                ResizeHandle(
                  position: HandlePosition.bottomCenter,
                  isSelected: _selectedResizeHandle == HandlePosition.bottomCenter,
                  onSelected: () =>
                      setState(() => _selectedResizeHandle = HandlePosition.bottomCenter),
                  onStart: () {
                    setState(() => _selectedResizeHandle = HandlePosition.bottomCenter);
                    _setResizing(true);
                  },
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.bottomCenter, d),
                ),
                ResizeHandle(
                  position: HandlePosition.bottomRight,
                  isSelected: _selectedResizeHandle == HandlePosition.bottomRight,
                  onSelected: () =>
                      setState(() => _selectedResizeHandle = HandlePosition.bottomRight),
                  onStart: () {
                    setState(() => _selectedResizeHandle = HandlePosition.bottomRight);
                    _setResizing(true);
                  },
                  onEnd: () => _setResizing(false),
                  onUpdate: (d) => _resize(HandlePosition.bottomRight, d),
                ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

