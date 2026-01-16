import 'package:flutter/material.dart';

import '../models/vision_components.dart';
import 'manipulable_node.dart';
import 'vision_board/component_constraints.dart';
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
      _didInitView = true;
    }
  }

  void _updateComponent(VisionComponent updated) {
    final viewport = _viewportSize;
    final constrained = viewport == null ? updated : constrainComponentToViewport(updated, viewport);
    final next = widget.components.map((c) => c.id == updated.id ? constrained : c).toList();
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

    final bgSize = widget.backgroundImageSize;
    // Use background image size if available, otherwise default to 2000x2000
    // But ensure minimum reasonable size
    final canvasSize = bgSize != null
        ? Size(
            bgSize.width < 1000 ? 1000 : bgSize.width,
            bgSize.height < 1000 ? 1000 : bgSize.height,
          )
        : const Size(2000, 2000);

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
        _maybeInitView(
          viewport: constraints.biggest,
          canvas: canvasSize,
          backgroundIdentity: widget.backgroundImage,
          backgroundSize: widget.backgroundImageSize,
        );
        return InteractiveViewer(
          transformationController: _viewerController,
          minScale: 0.2,
          maxScale: 6.0,
          // Allow panning when no component is selected, or when viewing (not editing)
          panEnabled: !widget.isEditing || widget.selectedComponentId == null,
          // Disable pinch-zoom while editing (Canva-like editor behavior).
          scaleEnabled: !widget.isEditing,
          // Allow some margin so centering isn't clamped.
          boundaryMargin: const EdgeInsets.all(1000),
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
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Image(
                          image: widget.backgroundImage!,
                          // Fill the entire canvas area, letting InteractiveViewer handle viewport scaling
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ...sorted.map((c) {
                    final isSelected = widget.selectedComponentId == c.id;

                    Widget child = const SizedBox.shrink();
                    switch (c) {
                      case ImageComponent():
                        child = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: componentImageForPath(c.imagePath),
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
                      onSelected: () {
                        widget.onSelectedComponentIdChanged(c.id);
                        _bringToFront(c);
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
          ),
        );
      },
    );
  }
}

