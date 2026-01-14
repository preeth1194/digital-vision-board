import 'package:flutter/material.dart';

import '../models/vision_component.dart';
import '../utils/file_image_provider.dart';
import 'manipulable_node.dart';

/// Freeform, Canva-style vision board builder.
///
/// Renders a pan/zoom canvas with a stack of [VisionComponent]s.
class VisionBoardBuilder extends StatefulWidget {
  final List<VisionComponent> components;
  final bool isEditing;

  final String? selectedComponentId;
  final ValueChanged<String?> onSelectedComponentIdChanged;

  final ValueChanged<List<VisionComponent>> onComponentsChanged;
  final ValueChanged<VisionComponent> onOpenComponent;

  final Color backgroundColor;
  final ImageProvider? backgroundImage;
  final Size? backgroundImageSize;

  const VisionBoardBuilder({
    super.key,
    required this.components,
    required this.isEditing,
    required this.selectedComponentId,
    required this.onSelectedComponentIdChanged,
    required this.onComponentsChanged,
    required this.onOpenComponent,
    required this.backgroundColor,
    required this.backgroundImage,
    required this.backgroundImageSize,
  });

  @override
  State<VisionBoardBuilder> createState() => _VisionBoardBuilderState();
}

class _VisionBoardBuilderState extends State<VisionBoardBuilder> {
  Size? _viewportSize;

  void _updateComponent(VisionComponent updated) {
    // Use viewport size if available, otherwise fall back to canvas size
    final bgSize = widget.backgroundImageSize;
    final canvasSize = bgSize != null
        ? Size(
            bgSize.width < 2000 ? 2000 : bgSize.width,
            bgSize.height < 2000 ? 2000 : bgSize.height,
          )
        : const Size(2000, 2000);
    
    // Use viewport size for constraints (visible area), not canvas size
    // If viewport size not set yet, use a reasonable default based on screen
    final constraintSize = _viewportSize;
    if (constraintSize == null) {
      // Viewport not initialized yet, skip constraint for now
      final next = widget.components.map((c) => c.id == updated.id ? updated : c).toList();
      widget.onComponentsChanged(next);
      return;
    }
    
    // Constrain size to not exceed viewport (minimum size is 40)
    const minSize = 40.0;
    final constrainedWidth = updated.size.width.clamp(minSize, constraintSize.width);
    final constrainedHeight = updated.size.height.clamp(minSize, constraintSize.height);
    
    // Calculate max position based on constrained size and scale
    // The effective size accounts for scale transformation
    final effectiveWidth = constrainedWidth * updated.scale;
    final effectiveHeight = constrainedHeight * updated.scale;
    
    // Calculate maximum allowed position so component stays within viewport
    // Right edge: position.x + effectiveWidth <= constraintSize.width
    // Bottom edge: position.y + effectiveHeight <= constraintSize.height
    final maxX = (constraintSize.width - effectiveWidth).clamp(0.0, constraintSize.width);
    final maxY = (constraintSize.height - effectiveHeight).clamp(0.0, constraintSize.height);
    
    // Clamp position to ensure component stays within viewport
    final constrainedPosition = Offset(
      updated.position.dx.clamp(0.0, maxX),
      updated.position.dy.clamp(0.0, maxY),
    );
    
    final constrained = updated.copyWithCommon(
      position: constrainedPosition,
      size: Size(constrainedWidth, constrainedHeight),
    );
    final next = widget.components.map((c) => c.id == updated.id ? constrained : c).toList();
    widget.onComponentsChanged(next);
  }

  void _bringToFront(VisionComponent component) {
    final maxZ = widget.components.isEmpty ? 0 : widget.components.map((c) => c.zIndex).reduce((a, b) => a > b ? a : b);
    if (component.zIndex >= maxZ) return;
    _updateComponent(component.copyWithCommon(zIndex: maxZ + 1));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.components]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final bgSize = widget.backgroundImageSize;
    final canvasSize = bgSize != null
        ? Size(
            bgSize.width < 2000 ? 2000 : bgSize.width,
            bgSize.height < 2000 ? 2000 : bgSize.height,
          )
        : const Size(2000, 2000);

    // Get actual screen size for viewport constraints
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    // Account for app bar and bottom bar (approximately)
    // App bar is typically 56, bottom bar is 80
    final viewportHeight = screenSize.height - 56 - 80; // Approximate, will be refined in LayoutBuilder
    final viewportSize = Size(screenSize.width, viewportHeight);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Store actual viewport size - use the smaller of constraints or screen size
        // This ensures we constrain to the visible area
        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;
        // Use constraints.biggest which is the actual available space in the body
        // This already accounts for app bar and bottom bar
        _viewportSize = Size(
          constraints.biggest.width > 0 ? constraints.biggest.width : screenSize.width,
          constraints.biggest.height > 0 ? constraints.biggest.height : screenSize.height,
        );
        
        return InteractiveViewer(
          minScale: 0.2,
          maxScale: 6.0,
          panEnabled: !widget.isEditing || widget.selectedComponentId == null,
          scaleEnabled: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.isEditing ? () => widget.onSelectedComponentIdChanged(null) : null,
            child: SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(color: widget.backgroundColor),
                  ),
                  if (widget.backgroundImage != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: bgSize?.width ?? canvasSize.width,
                      height: bgSize?.height ?? canvasSize.height,
                      child: IgnorePointer(
                        child: Image(
                          image: widget.backgroundImage!,
                          fit: bgSize != null ? BoxFit.fill : BoxFit.cover,
                        ),
                      ),
                    ),
                  ...sorted.map((c) {
                    final isSelected = widget.selectedComponentId == c.id;

                    Widget child;
                    switch (c) {
                      case ImageComponent():
                        child = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _imageForPath(c.imagePath),
                        );
                        break;
                      case TextComponent():
                        child = Container(
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(c.text, style: c.style),
                          ),
                        );
                        break;
                      case ZoneComponent():
                        child = Container(
                          color: Colors.transparent,
                        );
                        break;
                    }

                    return ManipulableNode(
                      component: c,
                      isSelected: isSelected,
                      gesturesEnabled: widget.isEditing,
                      child: child,
                      onSelected: () {
                        widget.onSelectedComponentIdChanged(c.id);
                        _bringToFront(c);
                      },
                      onOpen: (!widget.isEditing && c is! TextComponent) 
                          ? () => widget.onOpenComponent(c) 
                          : null,
                      onChanged: _updateComponent,
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _imageForPath(String path) {
    // If path looks like a URL, treat it as NetworkImage; otherwise, file path.
    final lower = path.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return Image.network(path, fit: BoxFit.cover);
    }

    final provider = fileImageProviderFromPath(path);
    if (provider != null) {
      return Image(image: provider, fit: BoxFit.cover);
    }

    return Container(
      color: Colors.black12,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

