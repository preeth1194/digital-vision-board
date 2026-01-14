import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/hotspot_model.dart';
import 'habit_tracker_sheet.dart';
import '../models/vision_component.dart';

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

  /// Callback when a hotspot should be deleted
  final ValueChanged<HotspotModel>? onHotspotDelete;

  /// Callback when a new hotspot is created (after drawing)
  /// Passes the coordinates and expects a HotspotModel to be returned (or null to cancel)
  final Future<HotspotModel?> Function(double x, double y, double width, double height)? onHotspotCreated;

  /// Callback when a hotspot should be edited (tapped in edit mode)
  final Future<HotspotModel?> Function(HotspotModel hotspot)? onHotspotEdit;

  /// Callback when a hotspot is selected (tapped in edit mode)
  final ValueChanged<HotspotModel>? onHotspotSelected;

  /// The currently selected hotspots (for highlighting in edit mode)
  final Set<HotspotModel> selectedHotspots;

  /// Whether to show labels on hotspots
  final bool showLabels;

  /// Whether the widget is in editing mode
  final bool isEditing;

  /// Border color for hotspots (default: Neon Green)
  final Color hotspotBorderColor;

  /// Fill color for hotspots (default: Neon Green with transparency)
  final Color hotspotFillColor;
  
  /// Selected border color
  final Color selectedHotspotBorderColor;
  
  /// Selected fill color
  final Color selectedHotspotFillColor;

  /// Border width for hotspots
  final double hotspotBorderWidth;

  const VisionBoardHotspotBuilder({
    super.key,
    required this.imageProvider,
    required this.hotspots,
    this.onHotspotsChanged,
    this.onHotspotDelete,
    this.onHotspotCreated,
    this.onHotspotEdit,
    this.onHotspotSelected,
    this.selectedHotspots = const {},
    this.showLabels = true,
    this.isEditing = true,
    this.hotspotBorderColor = const Color(0xFF39FF14), // Neon Green
    this.hotspotFillColor = const Color(0x1A39FF14), // Neon Green with ~10% opacity
    this.selectedHotspotBorderColor = Colors.blue,
    this.selectedHotspotFillColor = const Color(0x332196F3), // Blue with opacity
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
  Offset? _drawingStartPosition;
  DateTime? _drawingStartTime;
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
  void didUpdateWidget(VisionBoardHotspotBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset zoom/pan when switching to edit mode
    if (oldWidget.isEditing != widget.isEditing && widget.isEditing) {
      // Switching to edit mode - reset transformation to default (no zoom/pan)
      _transformationController.value = Matrix4.identity();
      print('Switched to edit mode - resetting zoom/pan');
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    super.dispose();
  }

  /// Load the actual image dimensions
  void _loadImageSize() {
    final ImageStream stream = widget.imageProvider.resolve(
      const ImageConfiguration(),
    );
    _imageStreamListener = ImageStreamListener(
      (ImageInfo info, bool _) {
        if (!mounted) return;
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
    // We need to invert the transformation to get the point in the original image coordinate space
    final Matrix4? transform = _transformationController.value;
    if (transform != null && !transform.isIdentity()) {
      // Invert the transformation to get the point in the InteractiveViewer's coordinate space
      final Matrix4 inverted = Matrix4.inverted(transform);
      screenPoint = _transformPoint(inverted, screenPoint);
    }

    // Check if point is within image bounds (after transformation inversion)
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

    // Always use the same image bounds calculation - this ensures consistency
    final Rect imageBounds = _getImageBounds(containerSize, _imageSize!);

    // Convert normalized coordinates (0.0-1.0) to screen coordinates within image bounds
    final double screenX = imageBounds.left + (hotspot.x * imageBounds.width);
    final double screenY = imageBounds.top + (hotspot.y * imageBounds.height);
    final double screenWidth = hotspot.width * imageBounds.width;
    final double screenHeight = hotspot.height * imageBounds.height;

    // Apply InteractiveViewer transformation if present
    final Matrix4? transform = _transformationController.value;
    if (transform != null && !transform.isIdentity()) {
      // Transform all four corners of the rectangle to account for zoom/pan
      final Offset topLeft = _transformPoint(transform, Offset(screenX, screenY));
      final Offset topRight = _transformPoint(transform, Offset(screenX + screenWidth, screenY));
      final Offset bottomLeft = _transformPoint(transform, Offset(screenX, screenY + screenHeight));
      final Offset bottomRight = _transformPoint(transform, Offset(screenX + screenWidth, screenY + screenHeight));

      // Find the bounding box of the transformed rectangle
      final double minX = math.min(math.min(topLeft.dx, topRight.dx), math.min(bottomLeft.dx, bottomRight.dx));
      final double maxX = math.max(math.max(topLeft.dx, topRight.dx), math.max(bottomLeft.dx, bottomRight.dx));
      final double minY = math.min(math.min(topLeft.dy, topRight.dy), math.min(bottomLeft.dy, bottomRight.dy));
      final double maxY = math.max(math.max(topLeft.dy, topRight.dy), math.max(bottomLeft.dy, bottomRight.dy));

      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    // No transformation - return coordinates directly
    return Rect.fromLTWH(screenX, screenY, screenWidth, screenHeight);
  }

  void _onPanStart(DragStartDetails details, Size containerSize) {
    _onPanStartWithOffset(details.localPosition, containerSize);
  }

  void _onPanStartWithOffset(Offset localPosition, Size containerSize) {
    if (!widget.isEditing) return;

    final Offset? imagePoint = _screenToImageCoordinates(
      localPosition,
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
    _onPanUpdateWithOffset(details.localPosition, containerSize);
  }

  void _onPanUpdateWithOffset(Offset localPosition, Size containerSize) {
    if (!widget.isEditing || _dragStart == null) return;

    final Offset? imagePoint = _screenToImageCoordinates(
      localPosition,
      containerSize,
    );

    if (imagePoint != null) {
      setState(() {
        _dragEnd = imagePoint;
      });
    }
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (!widget.isEditing || _dragStart == null || _dragEnd == null) return;

    // Calculate normalized rectangle
    final double x = math.min(_dragStart!.dx, _dragEnd!.dx);
    final double y = math.min(_dragStart!.dy, _dragEnd!.dy);
    final double width = (_dragStart!.dx - _dragEnd!.dx).abs();
    final double height = (_dragStart!.dy - _dragEnd!.dy).abs();

    // Clear the drawing state first
    setState(() {
      _dragStart = null;
      _dragEnd = null;
    });

    // Only create hotspot if it has meaningful size
    if (width > 0.01 && height > 0.01) {
      // If there's a callback for creating hotspots, use it
      if (widget.onHotspotCreated != null) {
        final HotspotModel? newHotspot = await widget.onHotspotCreated!(x, y, width, height);
        
        // If the dialog was cancelled (returns null), don't add the hotspot
        if (newHotspot != null) {
          final List<HotspotModel> updatedHotspots = [
            ...widget.hotspots,
            newHotspot,
          ];
          widget.onHotspotsChanged?.call(updatedHotspots);
        }
      } else {
        // Fallback: create hotspot without dialog (for backward compatibility)
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
    }
  }

  Future<void> _onHotspotTap(HotspotModel hotspot, BuildContext context) async {
    if (widget.isEditing) {
      // In edit mode, select the hotspot instead of immediately editing
      if (widget.onHotspotSelected != null) {
        widget.onHotspotSelected!(hotspot);
      }
      return;
    }

    // In view mode, open the habit tracker modal bottom sheet
    if (_imageSize == null) return;
    final VisionComponent component = convertHotspotToComponent(hotspot, _imageSize!);
    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext sheetContext) {
          return HabitTrackerSheet(
            component: component,
            onComponentUpdated: (updatedComponent) {
              final updatedHotspot = hotspot.copyWith(habits: updatedComponent.habits);
              // Update the hotspot in the list
              final List<HotspotModel> updatedHotspots = widget.hotspots.map((h) {
                // Match by coordinates (with small tolerance for floating point)
                final bool coordinatesMatch = 
                    (h.x - hotspot.x).abs() < 0.0001 &&
                    (h.y - hotspot.y).abs() < 0.0001 &&
                    (h.width - hotspot.width).abs() < 0.0001 &&
                    (h.height - hotspot.height).abs() < 0.0001;
                
                // Also match by id and link if they exist (for more reliable matching)
                final bool idMatch = h.id == hotspot.id || (h.id == null && hotspot.id == null);
                final bool linkMatch = h.link == hotspot.link || (h.link == null && hotspot.link == null);
                
                if (coordinatesMatch && idMatch && linkMatch) {
                  return updatedHotspot;
                }
                return h;
              }).toList();
              
              widget.onHotspotsChanged?.call(updatedHotspots);
            },
          );
        },
      );
    }
  }

  Future<void> _onHotspotLongPress(HotspotModel hotspot, BuildContext context) async {
    if (!widget.isEditing) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Hotspot'),
          content: const Text('Delete this hotspot?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true && widget.onHotspotDelete != null) {
      widget.onHotspotDelete!(hotspot);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Always use the current constraints to ensure consistency
        _containerSize = constraints.biggest;
        
        return Stack(
          children: [
            // Image with InteractiveViewer - no wrapper to allow full multi-touch support
            InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              // In edit mode, disable single-finger pan when drawing, but always allow multi-touch (pinch)
              panEnabled: !widget.isEditing || _dragStart == null,
              scaleEnabled: true, // Always allow pinch-to-zoom in both modes
              child: Image(
                image: widget.imageProvider,
                fit: BoxFit.contain,
              ),
            ),

            // Listener for drawing (placed BEHIND hotspots so hotspots can block events)
            // But ABOVE Image so it catches events on empty space
            if (widget.isEditing)
              Positioned.fill(
                child: Listener(
                  onPointerDown: (event) {
                    print('Drawing Listener: Pointer down - starting drawing');
                    _onPanStartWithOffset(event.localPosition, constraints.biggest);
                  },
                  onPointerMove: _dragStart != null
                      ? (event) {
                          _onPanUpdateWithOffset(event.localPosition, constraints.biggest);
                        }
                      : null,
                  onPointerUp: _dragStart != null
                      ? (event) {
                          _onPanEnd(DragEndDetails());
                        }
                      : null,
                  onPointerCancel: _dragStart != null
                      ? (event) {
                          setState(() {
                            _dragStart = null;
                            _dragEnd = null;
                          });
                        }
                      : null,
                  behavior: HitTestBehavior.translucent,
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),

            // Existing hotspots (placed on TOP so they receive gestures first)
            // Both edit and view modes use the same _imageToScreenRect function for consistency
            // Only render hotspots if image size is loaded to ensure accurate coordinates
            if (_imageSize != null)
              ...widget.hotspots.map((hotspot) {
                // Use the same coordinate calculation for both edit and view modes
                // This ensures hotspots appear in the same position regardless of mode
                final Rect screenRect = _imageToScreenRect(
                  hotspot,
                  constraints.biggest,
                );

                // Ensure we have valid dimensions
                if (screenRect.width <= 0 || screenRect.height <= 0) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  left: screenRect.left,
                  top: screenRect.top,
                  width: screenRect.width,
                  height: screenRect.height,
                  child: widget.isEditing
                      ? _buildHotspotView(hotspot, context)
                      : _buildClickableHotspot(hotspot, context),
                );
              }),

            // Currently drawing rectangle (placed on TOP of everything during drawing)
            if (widget.isEditing && _dragStart != null && _dragEnd != null)
              _buildDrawingRectangle(constraints.biggest),
          ],
        );
      },
    );
  }

  Widget _buildHotspotView(HotspotModel hotspot, BuildContext context) {
    // Check if this hotspot is selected by comparing coordinates with any in the set
    final bool isSelected = widget.selectedHotspots.any((selected) =>
        (selected.x - hotspot.x).abs() < 0.0001 &&
        (selected.y - hotspot.y).abs() < 0.0001 &&
        (selected.width - hotspot.width).abs() < 0.0001 &&
        (selected.height - hotspot.height).abs() < 0.0001);
    
    return GestureDetector(
      onTap: () {
        print('=== Hotspot TAP detected - selecting hotspot ===');
        _onHotspotTap(hotspot, context);
      },
      onLongPress: () {
        print('=== Hotspot LONG PRESS detected - opening delete dialog ===');
        _onHotspotLongPress(hotspot, context);
      },
      // Opaque behavior ensures this widget blocks ALL events from reaching widgets below (like the drawing Listener)
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? widget.selectedHotspotBorderColor : widget.hotspotBorderColor,
                width: isSelected ? 3.0 : widget.hotspotBorderWidth,
              ),
              color: isSelected ? widget.selectedHotspotFillColor : widget.hotspotFillColor,
            ),
          ),
          // Ledger Name Label
          if (widget.showLabels && hotspot.id != null && hotspot.id!.isNotEmpty)
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hotspot.id!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClickableHotspot(HotspotModel hotspot, BuildContext context) {
    final bool hasLink = hotspot.link != null && hotspot.link!.isNotEmpty;

    return InkWell(
      onTap: () => _onHotspotTap(hotspot, context),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.hotspotBorderColor,
                width: widget.hotspotBorderWidth,
              ),
              color: widget.hotspotFillColor,
            ),
          ),
          // Ledger Name Label (FIX: Added this to view mode)
          if (widget.showLabels && hotspot.id != null && hotspot.id!.isNotEmpty)
            Positioned(
              left: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  hotspot.id!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Show external link icon if hotspot has a valid link
          if (hasLink)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_new,
                  size: 12,
                  color: Color(0xFF39FF14), // Neon Green
                ),
              ),
            ),
        ],
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
