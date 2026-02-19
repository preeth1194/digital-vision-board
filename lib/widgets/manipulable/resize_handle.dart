import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';

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

class ResizeHandle extends StatefulWidget {
  final HandlePosition position;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final ValueChanged<DragUpdateDetails> onUpdate;
  final bool isSelected;
  final VoidCallback? onSelected;
  final double? cornerDiameter;
  final double? edgeLength;
  final double? edgeThickness;
  final double? touchSize;
  /// Push the *visible* handle outward from the border by this many pixels.
  /// Touch target remains centered/aligned for reliable hit-testing.
  ///
  /// If null, defaults to [defaultCornerVisualOutset] for corner handles and
  /// [defaultEdgeVisualOutset] for edge handles.
  final double? visualOutset;

  const ResizeHandle({
    super.key,
    required this.position,
    required this.onStart,
    required this.onEnd,
    required this.onUpdate,
    this.isSelected = false,
    this.onSelected,
    this.cornerDiameter,
    this.edgeLength,
    this.edgeThickness,
    this.touchSize,
    this.visualOutset,
  });

  // Visual sizes (what you see)
  // Corner dots: ~14px diameter.
  static const double defaultCornerDiameter = 18;
  // Edge pills: ~24x6 (orientation-dependent).
  static const double defaultEdgeLength = 30;
  static const double defaultEdgeThickness = 6;

  // Touch target size (invisible). Keep large for usability.
  static const double defaultTouchSize = 48;

  // Visual offset of handles relative to the selection border.
  // Match Free Canva editor: corners are slightly farther out than edges.
  static const double defaultCornerVisualOutset = 4;
  static const double defaultEdgeVisualOutset = 3;

  static const Color _handleBorderColor = AppColors.handleBorderGrey;
  static const Color _handleActiveFillColor = AppColors.handleActivePurple;
  static const double _handleBorderWidth = 1.5;
  static final BorderRadius _edgeBorderRadius = BorderRadius.circular(4);
  static const List<BoxShadow> _handleShadow = [
    BoxShadow(
      color: AppColors.shadowSubtle,
      blurRadius: 3,
      offset: Offset(0, 1),
    ),
  ];

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

  static Offset _visualOffsetFor(
    HandlePosition p, {
    required Size visualSize,
    required double touchSize,
    double visualOutset = 0,
  }) {
    // Keep the visible pill/dot fully inside the touch target, but flush it to the
    // selection border. This ensures dragging starts reliably on the visible handle.
    final halfTouch = touchSize / 2;
    final halfW = visualSize.width / 2;
    final halfH = visualSize.height / 2;

    final base = switch (p) {
      HandlePosition.topLeft => Offset(-(halfTouch - halfW), -(halfTouch - halfH)),
      HandlePosition.topCenter => Offset(0, -(halfTouch - halfH)),
      HandlePosition.topRight => Offset((halfTouch - halfW), -(halfTouch - halfH)),
      HandlePosition.centerLeft => Offset(-(halfTouch - halfW), 0),
      HandlePosition.centerRight => Offset((halfTouch - halfW), 0),
      HandlePosition.bottomLeft => Offset(-(halfTouch - halfW), (halfTouch - halfH)),
      HandlePosition.bottomCenter => Offset(0, (halfTouch - halfH)),
      HandlePosition.bottomRight => Offset((halfTouch - halfW), (halfTouch - halfH)),
    };

    final double sx = switch (p) {
      HandlePosition.topLeft ||
      HandlePosition.centerLeft ||
      HandlePosition.bottomLeft =>
        -1,
      HandlePosition.topRight ||
      HandlePosition.centerRight ||
      HandlePosition.bottomRight =>
        1,
      _ => 0,
    };
    final double sy = switch (p) {
      HandlePosition.topLeft ||
      HandlePosition.topCenter ||
      HandlePosition.topRight =>
        -1,
      HandlePosition.bottomLeft ||
      HandlePosition.bottomCenter ||
      HandlePosition.bottomRight =>
        1,
      _ => 0,
    };

    return base + Offset(sx * visualOutset, sy * visualOutset);
  }

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _active = false;

  void _setActive(bool next) {
    if (_active == next) return;
    setState(() => _active = next);
  }

  @override
  Widget build(BuildContext context) {
    final double touchSize = widget.touchSize ?? ResizeHandle.defaultTouchSize;
    final double cornerDiameter =
        widget.cornerDiameter ?? ResizeHandle.defaultCornerDiameter;
    final double edgeLength = widget.edgeLength ?? ResizeHandle.defaultEdgeLength;
    final double edgeThickness =
        widget.edgeThickness ?? ResizeHandle.defaultEdgeThickness;

    final bool isCorner = switch (widget.position) {
      HandlePosition.topLeft ||
      HandlePosition.topRight ||
      HandlePosition.bottomLeft ||
      HandlePosition.bottomRight =>
        true,
      _ => false,
    };
    final double visualOutset = widget.visualOutset ??
        (isCorner
            ? ResizeHandle.defaultCornerVisualOutset
            : ResizeHandle.defaultEdgeVisualOutset);

    final Size size = isCorner
        ? Size(cornerDiameter, cornerDiameter)
        : (widget.position == HandlePosition.topCenter ||
                widget.position == HandlePosition.bottomCenter)
            ? Size(edgeLength, edgeThickness)
            : Size(edgeThickness, edgeLength);

    final colorScheme = Theme.of(context).colorScheme;
    final bool isActive = _active || widget.isSelected;
    final borderColor = isActive
        ? colorScheme.surface
        : ResizeHandle._handleBorderColor;
    final fillColor = isActive ? ResizeHandle._handleActiveFillColor : colorScheme.surface;

    // Slightly emphasize the selected edge handle (visual feedback only).
    final bool isEdge = !isCorner;
    final bool emphasize = widget.isSelected && isEdge;
    final double visualEdgeLength = emphasize ? edgeLength + 8 : edgeLength;
    final double visualEdgeThickness = emphasize ? edgeThickness + 2 : edgeThickness;

    final double visualW = isCorner
        ? size.width
        : (size.width > size.height ? visualEdgeLength : visualEdgeThickness);
    final double visualH = isCorner
        ? size.height
        : (size.width > size.height ? visualEdgeThickness : visualEdgeLength);
    final visualSize = Size(visualW, visualH);

    return Align(
      alignment: ResizeHandle._alignmentFor(widget.position),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => widget.onSelected?.call(),
        onPanDown: (_) => _setActive(true),
        onPanStart: (_) {
          _setActive(true);
          widget.onSelected?.call();
          widget.onStart();
        },
        onPanEnd: (_) {
          _setActive(false);
          widget.onEnd();
        },
        onPanCancel: () {
          _setActive(false);
          widget.onEnd();
        },
        onPanUpdate: widget.onUpdate,
        child: SizedBox(
          width: touchSize,
          height: touchSize,
          child: Center(
            child: Transform.translate(
              offset: ResizeHandle._visualOffsetFor(
                widget.position,
                visualSize: visualSize,
                touchSize: touchSize,
                visualOutset: visualOutset,
              ),
              child: Container(
                width: visualW,
                height: visualH,
                decoration: BoxDecoration(
                  color: fillColor,
                  border: Border.all(
                    color: borderColor,
                    width: ResizeHandle._handleBorderWidth,
                  ),
                  shape: isCorner ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isCorner ? null : ResizeHandle._edgeBorderRadius,
                  boxShadow: ResizeHandle._handleShadow,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

