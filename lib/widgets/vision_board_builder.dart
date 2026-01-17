import 'package:flutter/material.dart';

import '../models/vision_components.dart';
import 'manipulable_node.dart';
import 'vision_board/component_image.dart';

/// Freeform canvas renderer.
///
/// When [canvasSize] is provided (e.g. Canva template import), components are
/// positioned in that fixed canvas space and the whole canvas is uniformly
/// scaled to fit the viewport (BoxFit.contain).
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

  /// Logical canvas size (template space). If null, canvas == viewport.
  final Size? canvasSize;

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
    this.canvasSize,
  });

  void _updateComponent(VisionComponent updated) {
    final next = components.map((c) => c.id == updated.id ? updated : c).toList();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final logicalCanvas = canvasSize ?? Size(viewport.width, viewport.height);

        final vw = viewport.width <= 0 ? 1.0 : viewport.width;
        final vh = viewport.height <= 0 ? 1.0 : viewport.height;
        final cw = logicalCanvas.width <= 0 ? 1.0 : logicalCanvas.width;
        final ch = logicalCanvas.height <= 0 ? 1.0 : logicalCanvas.height;

        final scaleX = vw / cw;
        final scaleY = vh / ch;
        final canvasScale = (scaleX < scaleY ? scaleX : scaleY).clamp(0.05, 20.0).toDouble();

        final displayW = cw * canvasScale;
        final displayH = ch * canvasScale;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEditing ? () => onSelectedComponentIdChanged(null) : null,
          child: Center(
            child: SizedBox(
              width: displayW,
              height: displayH,
              child: ClipRect(
                child: Transform.scale(
                  alignment: Alignment.topLeft,
                  scale: canvasScale,
                  child: SizedBox(
                    width: cw,
                    height: ch,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(child: Container(color: backgroundColor)),
                        if (backgroundImage != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Image(
                                image: backgroundImage!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ...sorted.map((c) {
                          final canSelectInView = isEditing || c is! TextComponent;
                          final isSelected = canSelectInView && selectedComponentId == c.id;

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
                              child = Container(color: Colors.transparent);
                              break;
                          }

                          return ManipulableNode(
                            component: c,
                            canvasScale: canvasScale,
                            isSelected: isSelected,
                            gesturesEnabled: isEditing,
                            onSelected: () {
                              if (!canSelectInView) return;
                              onSelectedComponentIdChanged(c.id);
                              if (isEditing) _bringToFront(c);
                            },
                            onOpen: (!isEditing && c is! TextComponent) ? () => onOpenComponent(c) : null,
                            onChanged: _updateComponent,
                            child: child,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

