import 'package:flutter/material.dart';

import '../models/vision_component.dart';
import '../utils/file_image_provider.dart';
import 'manipulable_node.dart';

/// Freeform, Canva-style vision board builder.
///
/// Renders a pan/zoom canvas with a stack of [VisionComponent]s.
class VisionBoardBuilder extends StatelessWidget {
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

  void _updateComponent(VisionComponent updated) {
    // Constrain position and size to stay within canvas bounds
    final bgSize = backgroundImageSize;
    final canvasSize = bgSize != null
        ? Size(
            bgSize.width < 2000 ? 2000 : bgSize.width,
            bgSize.height < 2000 ? 2000 : bgSize.height,
          )
        : const Size(2000, 2000);
    
    // Account for scale when calculating effective size
    final effectiveWidth = updated.size.width * updated.scale;
    final effectiveHeight = updated.size.height * updated.scale;
    
    // Constrain size to not exceed canvas (minimum size is 40)
    const minSize = 40.0;
    final constrainedWidth = updated.size.width.clamp(minSize, canvasSize.width);
    final constrainedHeight = updated.size.height.clamp(minSize, canvasSize.height);
    
    // Calculate max position based on constrained size and scale
    final effectiveWidth = constrainedWidth * updated.scale;
    final effectiveHeight = constrainedHeight * updated.scale;
    
    final maxX = (canvasSize.width - effectiveWidth).clamp(0.0, canvasSize.width);
    final maxY = (canvasSize.height - effectiveHeight).clamp(0.0, canvasSize.height);
    
    // Clamp position to ensure component stays within canvas
    final constrainedPosition = Offset(
      updated.position.dx.clamp(0.0, maxX),
      updated.position.dy.clamp(0.0, maxY),
    );
    
    final constrained = updated.copyWithCommon(
      position: constrainedPosition,
      size: Size(constrainedWidth, constrainedHeight),
    );
    final next = components.map((c) => c.id == updated.id ? constrained : c).toList();
    onComponentsChanged(next);
  }

  void _bringToFront(VisionComponent component) {
    final maxZ = components.isEmpty ? 0 : components.map((c) => c.zIndex).reduce((a, b) => a > b ? a : b);
    if (component.zIndex >= maxZ) return;
    _updateComponent(component.copyWithCommon(zIndex: maxZ + 1));
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...components]..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    final bgSize = backgroundImageSize;
    final canvasSize = bgSize != null
        ? Size(
            bgSize.width < 2000 ? 2000 : bgSize.width,
            bgSize.height < 2000 ? 2000 : bgSize.height,
          )
        : const Size(2000, 2000);

    return LayoutBuilder(
      builder: (context, constraints) {
        return InteractiveViewer(
          minScale: 0.2,
          maxScale: 6.0,
          panEnabled: !isEditing || selectedComponentId == null,
          scaleEnabled: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isEditing ? () => onSelectedComponentIdChanged(null) : null,
            child: SizedBox(
              width: canvasSize.width,
              height: canvasSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(color: backgroundColor),
                  ),
                  if (backgroundImage != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      width: bgSize?.width ?? canvasSize.width,
                      height: bgSize?.height ?? canvasSize.height,
                      child: IgnorePointer(
                        child: Image(
                          image: backgroundImage!,
                          fit: bgSize != null ? BoxFit.fill : BoxFit.cover,
                        ),
                      ),
                    ),
                  ...sorted.map((c) {
                    final isSelected = selectedComponentId == c.id;

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
                      gesturesEnabled: isEditing,
                      child: child,
                      onSelected: () {
                        onSelectedComponentIdChanged(c.id);
                        _bringToFront(c);
                      },
                      onOpen: (!isEditing && c is! TextComponent) 
                          ? () => onOpenComponent(c) 
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

