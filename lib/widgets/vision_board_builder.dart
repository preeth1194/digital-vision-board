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
    final canvasSize = bgSize != null
        ? Size(
            bgSize.width < 2000 ? 2000 : bgSize.width,
            bgSize.height < 2000 ? 2000 : bgSize.height,
          )
        : const Size(2000, 2000);

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = constraints.biggest;
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
}

