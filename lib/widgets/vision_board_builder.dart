import 'package:flutter/material.dart';

import '../models/vision_components.dart';
import 'manipulable_node.dart';
import 'vision_board/component_image.dart';

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
  final TransformationController _viewerController = TransformationController();
  Object? _lastBackgroundIdentity;
  Size? _lastBackgroundSize;
  bool _didInitView = false;

  @override
  void dispose() {
    _viewerController.dispose();
    super.dispose();
  }

  void _maybeInitView({
    required Size viewport,
    required Size canvas,
    required Object? backgroundIdentity,
    required Size? backgroundSize,
  }) {
    final bgChanged =
        backgroundIdentity != _lastBackgroundIdentity || backgroundSize != _lastBackgroundSize;

    _lastBackgroundIdentity = backgroundIdentity;
    _lastBackgroundSize = backgroundSize;

    if (viewport.width <= 0 || viewport.height <= 0) return;
    if (canvas.width <= 0 || canvas.height <= 0) return;

    // Recenter/refit when the background changes (e.g., scanned/imported board).
    if (!_didInitView || bgChanged) {
      // If canvas matches viewport size, no scaling needed - just center it
      if ((canvas.width - viewport.width).abs() < 1 && (canvas.height - viewport.height).abs() < 1) {
        // Canvas is same size as viewport - no transform needed
        _viewerController.value = Matrix4.identity();
      } else {
        // Fit entire canvas into the viewport (so big photos don't look "zoomed in"
        // to the top-left) and center it.
        final scaleX = (viewport.width / canvas.width).clamp(0.05, 1.0);
        final scaleY = (viewport.height / canvas.height).clamp(0.05, 1.0);
        final scale = (scaleX < scaleY ? scaleX : scaleY).toDouble();
        final scaledW = canvas.width * scale;
        final scaledH = canvas.height * scale;
        final dx = (viewport.width - scaledW) / 2;
        final dy = (viewport.height - scaledH) / 2;

        _viewerController.value = Matrix4.identity()
          ..translateByDouble(dx, dy, 0, 1)
          ..scaleByDouble(scale, scale, 1, 1);
      }
      _didInitView = true;
    }
  }

  void _updateComponent(VisionComponent updated) {
    // Don't constrain components to viewport - allow them to be any size on the canvas
    // The viewport is just the visible area, but components can exist anywhere on the canvas
    final next = widget.components.map((c) => c.id == updated.id ? updated : c).toList();
    widget.onComponentsChanged(next);
  }

  void _bringToFront(VisionComponent component) {
    final maxZ = widget.components.isEmpty
        ? 0
        : widget.components.map((c) => c.zIndex).reduce((a, b) => a > b ? a : b);
    if (component.zIndex >= maxZ) return;
    _updateComponent(component.copyWithCommon(zIndex: maxZ + 1));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.components]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        _viewportSize = viewport;
        
        // Always use viewport (phone screen) size for canvas
        // This ensures canvas matches phone screen and prevents sliding
        final canvasSize = Size(viewport.width, viewport.height);
        
        // Canvas always matches viewport - no InteractiveViewer needed, no sliding
        // Background image will fill the canvas using BoxFit.cover
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.isEditing ? () => widget.onSelectedComponentIdChanged(null) : null,
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Background color - fixed to canvas
                Positioned.fill(
                  child: Container(color: widget.backgroundColor),
                ),
                // Background image - fixed to canvas, fills using cover
                if (widget.backgroundImage != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Image(
                        image: widget.backgroundImage!,
                        // Cover ensures image fills canvas while maintaining aspect ratio
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  ...sorted.map((c) {
                    final canSelectInView = widget.isEditing || c is! TextComponent;
                    final isSelected = canSelectInView && widget.selectedComponentId == c.id;

                    Widget child = const SizedBox.shrink();
                    switch (c) {
                      case ImageComponent():
                        child = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Opacity(
                                opacity: c.isDisabled ? 0.35 : 1.0,
                                child: componentImageForPath(c.imagePath),
                              ),
                              if (c.isDisabled)
                                const Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: EdgeInsets.all(6),
                                    child: Icon(Icons.check_circle, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        );
                        break;
                      case TextComponent():
                        child = Container(
                          padding: const EdgeInsets.all(8),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: c.size.width,
                              child: Text(
                                c.text,
                                style: c.style,
                                textAlign: c.textAlign,
                              ),
                            ),
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
                      onSelected: () {
                        if (!canSelectInView) return;
                        widget.onSelectedComponentIdChanged(c.id);
                        if (widget.isEditing) _bringToFront(c);
                      },
                      onOpen: (!widget.isEditing && c is! TextComponent) 
                          ? () => widget.onOpenComponent(c) 
                          : null,
                      onChanged: _updateComponent,
                      child: child,
                    );
                  }),
                ],
            ),
          ),
        );
      },
    );
  }
}

