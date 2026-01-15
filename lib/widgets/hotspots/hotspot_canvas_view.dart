import 'package:flutter/material.dart';

import '../../models/hotspot_model.dart';
import 'hotspot_geometry.dart';
import 'hotspot_overlay.dart';

class HotspotCanvasView extends StatelessWidget {
  final TransformationController transformationController;
  final ImageProvider imageProvider;
  final Size? imageSize;

  final bool isEditing;
  final bool showLabels;

  final List<HotspotModel> hotspots;
  final Set<HotspotModel> selectedHotspots;

  final Offset? dragStart;
  final Offset? dragEnd;

  final Color hotspotBorderColor;
  final Color hotspotFillColor;
  final Color selectedHotspotBorderColor;
  final Color selectedHotspotFillColor;
  final double hotspotBorderWidth;

  final void Function(Offset localPosition, Size containerSize)? onPointerDown;
  final void Function(Offset localPosition, Size containerSize)? onPointerMove;
  final VoidCallback? onPointerUp;
  final VoidCallback? onPointerCancel;

  final void Function(HotspotModel hotspot)? onHotspotTap;
  final void Function(HotspotModel hotspot)? onHotspotLongPress;

  const HotspotCanvasView({
    super.key,
    required this.transformationController,
    required this.imageProvider,
    required this.imageSize,
    required this.isEditing,
    required this.showLabels,
    required this.hotspots,
    required this.selectedHotspots,
    required this.dragStart,
    required this.dragEnd,
    required this.hotspotBorderColor,
    required this.hotspotFillColor,
    required this.selectedHotspotBorderColor,
    required this.selectedHotspotFillColor,
    required this.hotspotBorderWidth,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onHotspotTap,
    required this.onHotspotLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = constraints.biggest;
        final hasImageSize = imageSize != null;

        return Stack(
          children: [
            InteractiveViewer(
              transformationController: transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              panEnabled: !isEditing || dragStart == null,
              scaleEnabled: true,
              child: Image(image: imageProvider, fit: BoxFit.contain),
            ),
            if (isEditing)
              Positioned.fill(
                child: Listener(
                  onPointerDown: onPointerDown == null
                      ? null
                      : (event) => onPointerDown!(event.localPosition, containerSize),
                  onPointerMove: (dragStart != null && onPointerMove != null)
                      ? (event) => onPointerMove!(event.localPosition, containerSize)
                      : null,
                  onPointerUp:
                      (dragStart != null && onPointerUp != null) ? (_) => onPointerUp!() : null,
                  onPointerCancel: (dragStart != null && onPointerCancel != null)
                      ? (_) => onPointerCancel!()
                      : null,
                  behavior: HitTestBehavior.translucent,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            if (hasImageSize)
              ...hotspots.map((hotspot) {
                final screenRect = imageToScreenRect(
                  hotspot: hotspot,
                  containerSize: containerSize,
                  imageSize: imageSize!,
                  transform: transformationController.value,
                );
                if (screenRect.width <= 0 || screenRect.height <= 0) {
                  return const SizedBox.shrink();
                }

                final isSelected = selectedHotspots.any((selected) =>
                    (selected.x - hotspot.x).abs() < 0.0001 &&
                    (selected.y - hotspot.y).abs() < 0.0001 &&
                    (selected.width - hotspot.width).abs() < 0.0001 &&
                    (selected.height - hotspot.height).abs() < 0.0001);

                return Positioned(
                  left: screenRect.left,
                  top: screenRect.top,
                  width: screenRect.width,
                  height: screenRect.height,
                  child: HotspotOverlay(
                    hotspot: hotspot,
                    isEditing: isEditing,
                    isSelected: isSelected,
                    showLabels: showLabels,
                    hotspotBorderColor: hotspotBorderColor,
                    hotspotFillColor: hotspotFillColor,
                    selectedHotspotBorderColor: selectedHotspotBorderColor,
                    selectedHotspotFillColor: selectedHotspotFillColor,
                    hotspotBorderWidth: hotspotBorderWidth,
                    onTap: () => onHotspotTap?.call(hotspot),
                    onLongPress: isEditing ? () => onHotspotLongPress?.call(hotspot) : null,
                  ),
                );
              }),
            if (isEditing && hasImageSize && dragStart != null && dragEnd != null)
              buildDrawingRectangle(
                containerSize: containerSize,
                imageSize: imageSize!,
                transform: transformationController.value,
                dragStart: dragStart!,
                dragEnd: dragEnd!,
                borderColor: hotspotBorderColor,
                fillColor: hotspotFillColor,
                borderWidth: hotspotBorderWidth,
              ),
          ],
        );
      },
    );
  }
}

