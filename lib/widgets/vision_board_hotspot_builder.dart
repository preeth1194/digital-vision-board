import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/hotspot_model.dart';

/// A robust, reusable widget for building vision board hotspots.
/// 
/// Displays an image with InteractiveViewer for zoom/pan, allows drawing
/// rectangular zones in edit mode, and makes them clickable in view mode.
/// All coordinates are normalized (0.0-1.0) relative to image dimensions.
class VisionBoardHotspotBuilder extends StatefulWidget {
  /// The image to display
  final ImageProvider imageProvider;

  /// List of existing hotspots
  final List<HotspotModel> hotspots;

  /// Callback when hotspots change
  final ValueChanged<List<HotspotModel>>? onHotspotsChanged;

  /// Whether the widget is in editing mode
  final bool isEditing;

  /// Border color for hotspots (default: Neon Green)
  final Color hotspotBorderColor;

  /// Fill color for hotspots (default: Neon Green with transparency)
  final Color hotspotFillColor;

  /// Border width for hotspots
  final double hotspotBorderWidth;

  const VisionBoardHotspotBuilder({
    super.key,
    required this.imageProvider,
    required this.hotspots,
    this.onHotspotsChanged,
    this.isEditing = true,
    this.hotspotBorderColor = const Color(0xFF39FF14), // Neon Green
    this.hotspotFillColor = const Color(0x1A39FF14), // Neon Green with ~10% opacity
    this.hotspotBorderWidth = 2.0,
  });

  @override
  State<VisionBoardHotspotBuilder> createState() =>
      _VisionBoardHotspotBuilderState();
}

class _VisionBoardHotspotBuilderState
    extends State<VisionBoardHotspotBuilder> {
  final TransformationController _transformationController =
      TransformationController();
  Offset? _dragStart;
  Offset? _dragEnd;
  Size? _imageSize;
  Size? _containerSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _imageStream?.removeListener(_imageStreamListener!);
    super.dispose();
  }

  /// Load the actual image dimensions
  void _loadImageSize() {
    final ImageStream stream = widget.imageProvider.resolve(
      const ImageConfiguration(),
    );
    _imageStreamListener = ImageStreamListener(
      (ImageInfo info, bool _) {
        setState(() {
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
    );
    _imageStream = stream;
    stream.addListener(_imageStreamListener!);
  }

  /// Helper function to transform an Offset using a Matrix4
  Offset _transformPoint(Matrix4 matrix, Offset point) {
    // Transform a 2D point (x, y) using a 4x4 matrix
    // Treat as homogeneous coordinates (x, y, 0, 1)
    final double x = point.dx;
    final double y = point.dy;
    
    // Matrix multiplication: result = matrix * [x, y, 0, 1]^T
    final double resultX = matrix[0] * x + matrix[4] * y + matrix[12];
    final double resultY = matrix[1] * x + matrix[5] * y + matrix[13];
    
    return Offset(resultX, resultY);
  }

  /// Calculate the actual displayed image bounds considering BoxFit.contain
  Rect _getImageBounds(Size containerSize, Size imageSize) {
    final double imageAspectRatio = imageSize.width / imageSize.height;
    final double containerAspectRatio = containerSize.width / containerSize.height;

    double displayWidth;
    double displayHeight;
    double offsetX = 0;
    double offsetY = 0;

    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider - fit to width
      displayWidth = containerSize.width;
      displayHeight = containerSize.width / imageAspectRatio;
      offsetY = (containerSize.height - displayHeight) / 2;
    } else {
      // Image is taller - fit to height
      displayHeight = containerSize.height;
      displayWidth = containerSize.height * imageAspectRatio;
      offsetX = (containerSize.width - displayWidth) / 2;
    }

    return Rect.fromLTWH(offsetX, offsetY, displayWidth, displayHeight);
  }

  /// Convert screen coordinates to normalized image coordinates (0.0-1.0)
  Offset? _screenToImageCoordinates(Offset screenPoint, Size containerSize) {
    if (_imageSize == null) return null;

    final Rect imageBounds = _getImageBounds(containerSize, _imageSize!);

    // Account for InteractiveViewer transformation first
    final Matrix4? transform = _transformationController.value;
    if (transform != null && !transform.isIdentity()) {
      // Invert the transformation to get the point in the InteractiveViewer's coordinate space
      final Matrix4 inverted = Matrix4.inverted(transform);
      screenPoint = _transformPoint(inverted, screenPoint);
    }

    // Check if point is within image bounds (after transformation)
    if (!imageBounds.contains(screenPoint)) return null;

    // Convert to image-relative coordinates (normalized 0.0-1.0)
    final double normalizedX = (screenPoint.dx - imageBounds.left) / imageBounds.width;
    final double normalizedY = (screenPoint.dy - imageBounds.top) / imageBounds.height;

    // Clamp to valid range
    return Offset(
      normalizedX.clamp(0.0, 1.0),
      normalizedY.clamp(0.0, 1.0),
    );
  }

  /// Convert normalized image coordinates to screen coordinates
  Rect _imageToScreenRect(
    HotspotModel hotspot,
    Size containerSize,
  ) {
    if (_imageSize == null) {
      return Rect.zero;
    }

    final Rect imageBounds = _getImageBounds(containerSize, _imageSize!);

    // Convert normalized coordinates to screen coordinates
    final double screenX = imageBounds.left + (hotspot.x * imageBounds.width);
    final double screenY = imageBounds.top + (hotspot.y * imageBounds.height);
    final double screenWidth = hotspot.width * imageBounds.width;
    final double screenHeight = hotspot.height * imageBounds.height;

    // Apply InteractiveViewer transformation
    final Matrix4? transform = _transformationController.value;
    if (transform != null && !transform.isIdentity()) {
      final Offset topLeft = _transformPoint(transform, Offset(screenX, screenY));
      final Offset topRight = _transformPoint(transform, Offset(screenX + screenWidth, screenY));
      final Offset bottomLeft = _transformPoint(transform, Offset(screenX, screenY + screenHeight));
      final Offset bottomRight = _transformPoint(transform, Offset(screenX + screenWidth, screenY + screenHeight));

      final double minX = math.min(math.min(topLeft.dx, topRight.dx), math.min(bottomLeft.dx, bottomRight.dx));
      final double maxX = math.max(math.max(topLeft.dx, topRight.dx), math.max(bottomLeft.dx, bottomRight.dx));
      final double minY = math.min(math.min(topLeft.dy, topRight.dy), math.min(bottomLeft.dy, bottomRight.dy));
      final double maxY = math.max(math.max(topLeft.dy, topRight.dy), math.max(bottomLeft.dy, bottomRight.dy));

      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    return Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight);
  }

  void _onPanStart(DragStartDetails details, Size containerSize) {
    if (!widget.isEditing) return;

    final Offset? imagePoint = _screenToImageCoordinates(
      details.localPosition,
      containerSize,
    );

    if (imagePoint != null) {
      setState(() {
        _dragStart = imagePoint;
        _dragEnd = imagePoint;
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size containerSize) {
    if (!widget.isEditing || _dragStart == null) return;

    final Offset? imagePoint = _screenToImageCoordinates(
      details.localPosition,
      containerSize,
    );

    if (imagePoint != null) {
      setState(() {
        _dragEnd = imagePoint;
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isEditing || _dragStart == null || _dragEnd == null) return;

    // Calculate normalized rectangle
    final double x = math.min(_dragStart!.dx, _dragEnd!.dx);
    final double y = math.min(_dragStart!.dy, _dragEnd!.dy);
    final double width = (_dragStart!.dx - _dragEnd!.dx).abs();
    final double height = (_dragStart!.dy - _dragEnd!.dy).abs();

    // Only create hotspot if it has meaningful size
    if (width > 0.01 && height > 0.01) {
      final HotspotModel newHotspot = HotspotModel(
        x: x,
        y: y,
        width: width,
        height: height,
      );

      final List<HotspotModel> updatedHotspots = [
        ...widget.hotspots,
        newHotspot,
      ];

      widget.onHotspotsChanged?.call(updatedHotspots);
    }

    setState(() {
      _dragStart = null;
      _dragEnd = null;
    });
  }

  void _onHotspotTap(HotspotModel hotspot) {
    if (widget.isEditing) return;
    print('Zone Tapped: ${hotspot.id ?? 'No ID'}');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _containerSize = constraints.biggest;

        return Stack(
          children: [
            // Image with InteractiveViewer
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image(
                image: widget.imageProvider,
                fit: BoxFit.contain,
              ),
            ),

            // Gesture detector for drawing
            // Note: Single-finger drag draws rectangles. Use pinch-to-zoom and two-finger pan
            // for navigating the image. InteractiveViewer handles multi-touch gestures.
            if (widget.isEditing)
              GestureDetector(
                onPanStart: (details) => _onPanStart(details, constraints.biggest),
                onPanUpdate: (details) => _onPanUpdate(details, constraints.biggest),
                onPanEnd: _onPanEnd,
                onPanCancel: () {
                  setState(() {
                    _dragStart = null;
                    _dragEnd = null;
                  });
                },
                behavior: HitTestBehavior.translucent,
                child: Container(
                  color: Colors.transparent,
                ),
              ),

            // Existing hotspots
            ...widget.hotspots.map((hotspot) {
              final Rect screenRect = _imageToScreenRect(
                hotspot,
                constraints.biggest,
              );

              return Positioned(
                left: screenRect.left,
                top: screenRect.top,
                width: screenRect.width,
                height: screenRect.height,
                child: widget.isEditing
                    ? _buildHotspotView(hotspot)
                    : _buildClickableHotspot(hotspot),
              );
            }),

            // Currently drawing rectangle
            if (widget.isEditing && _dragStart != null && _dragEnd != null)
              _buildDrawingRectangle(constraints.biggest),
          ],
        );
      },
    );
  }

  Widget _buildHotspotView(HotspotModel hotspot) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: widget.hotspotBorderColor,
          width: widget.hotspotBorderWidth,
        ),
        color: widget.hotspotFillColor,
      ),
    );
  }

  Widget _buildClickableHotspot(HotspotModel hotspot) {
    return InkWell(
      onTap: () => _onHotspotTap(hotspot),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.hotspotBorderColor,
            width: widget.hotspotBorderWidth,
          ),
          color: widget.hotspotFillColor,
        ),
      ),
    );
  }

  Widget _buildDrawingRectangle(Size containerSize) {
    if (_imageSize == null || _dragStart == null || _dragEnd == null) {
      return const SizedBox.shrink();
    }

    final Rect imageBounds = _getImageBounds(containerSize, _imageSize!);

    // Convert normalized coordinates to screen coordinates
    final double startX = imageBounds.left + (_dragStart!.dx * imageBounds.width);
    final double startY = imageBounds.top + (_dragStart!.dy * imageBounds.height);
    final double endX = imageBounds.left + (_dragEnd!.dx * imageBounds.width);
    final double endY = imageBounds.top + (_dragEnd!.dy * imageBounds.height);

    final double left = math.min(startX, endX);
    final double top = math.min(startY, endY);
    final double width = (startX - endX).abs();
    final double height = (startY - endY).abs();

    // Apply transformation
    final Matrix4? transform = _transformationController.value;
    if (transform != null && !transform.isIdentity()) {
      final Offset topLeft = _transformPoint(transform, Offset(left, top));
      final Offset topRight = _transformPoint(transform, Offset(left + width, top));
      final Offset bottomLeft = _transformPoint(transform, Offset(left, top + height));
      final Offset bottomRight = _transformPoint(transform, Offset(left + width, top + height));

      final double minX = math.min(math.min(topLeft.dx, topRight.dx), math.min(bottomLeft.dx, bottomRight.dx));
      final double maxX = math.max(math.max(topLeft.dx, topRight.dx), math.max(bottomLeft.dx, bottomRight.dx));
      final double minY = math.min(math.min(topLeft.dy, topRight.dy), math.min(bottomLeft.dy, bottomRight.dy));
      final double maxY = math.max(math.max(topLeft.dy, topRight.dy), math.max(bottomLeft.dy, bottomRight.dy));

      return Positioned(
        left: minX,
        top: minY,
        width: maxX - minX,
        height: maxY - minY,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: widget.hotspotBorderColor,
              width: widget.hotspotBorderWidth,
            ),
            color: widget.hotspotFillColor,
          ),
        ),
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: widget.hotspotBorderColor,
            width: widget.hotspotBorderWidth,
          ),
          color: widget.hotspotFillColor,
        ),
      ),
    );
  }
}
