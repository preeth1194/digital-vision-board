import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/goal_overlay_component.dart';
import 'goal_overlay_box.dart';
import 'goal_overlay_geometry.dart';

typedef GoalOverlayTap = void Function(GoalOverlayComponent overlay);
typedef GoalOverlaysChanged = void Function(List<GoalOverlayComponent> overlays);
typedef GoalOverlayCreate = Future<GoalOverlayComponent?> Function(Rect rectPx);

class GoalOverlayCanvasView extends StatefulWidget {
  final ImageProvider imageProvider;
  final Size imageSize;

  final bool isEditing;
  final List<GoalOverlayComponent> overlays;
  final String? selectedId;

  final ValueChanged<String?> onSelectedIdChanged;
  final GoalOverlaysChanged onOverlaysChanged;
  final GoalOverlayCreate onCreateOverlay;

  /// Called when user taps overlay in view mode.
  final GoalOverlayTap onOpenOverlay;

  const GoalOverlayCanvasView({
    super.key,
    required this.imageProvider,
    required this.imageSize,
    required this.isEditing,
    required this.overlays,
    required this.selectedId,
    required this.onSelectedIdChanged,
    required this.onOverlaysChanged,
    required this.onCreateOverlay,
    required this.onOpenOverlay,
  });

  @override
  State<GoalOverlayCanvasView> createState() => _GoalOverlayCanvasViewState();
}

enum _InteractionMode {
  none,
  drawing,
  moving,
  resizeTl,
  resizeTr,
  resizeBl,
  resizeBr,
}

class _GoalOverlayCanvasViewState extends State<GoalOverlayCanvasView> {
  final TransformationController _controller = TransformationController();
  final GlobalKey _stackKey = GlobalKey();

  _InteractionMode _mode = _InteractionMode.none;

  Offset? _drawStartPx;
  Offset? _drawEndPx;

  // drag state for move/resize
  Rect? _startRectPx;
  Offset? _startPointerPx;
  String? _activeId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Size _containerSize(BuildContext ctx) {
    final render = _stackKey.currentContext?.findRenderObject();
    if (render is RenderBox) return render.size;
    return MediaQuery.of(ctx).size;
  }

  Offset? _globalToLocal(Offset global) {
    final render = _stackKey.currentContext?.findRenderObject();
    if (render is! RenderBox) return null;
    return render.globalToLocal(global);
  }

  Rect _rectFor(GoalOverlayComponent o) =>
      Rect.fromLTWH(o.position.dx, o.position.dy, o.size.width, o.size.height);

  GoalOverlayComponent _applyRect(GoalOverlayComponent o, Rect next) {
    return o.copyWithCommon(
      position: Offset(next.left, next.top),
      size: Size(next.width, next.height),
    );
  }

  Rect _clampRectToImage(Rect r) {
    final w = widget.imageSize.width;
    final h = widget.imageSize.height;

    final minSize = 24.0;
    final width = r.width.clamp(minSize, w);
    final height = r.height.clamp(minSize, h);

    final maxLeft = (w - width).clamp(0.0, w);
    final maxTop = (h - height).clamp(0.0, h);
    final left = r.left.clamp(0.0, maxLeft);
    final top = r.top.clamp(0.0, maxTop);
    return Rect.fromLTWH(left, top, width, height);
  }

  GoalOverlayComponent? _findById(String id) {
    return widget.overlays.cast<GoalOverlayComponent?>().firstWhere(
          (o) => o?.id == id,
          orElse: () => null,
        );
  }

  void _updateOverlay(String id, Rect next) {
    final existing = _findById(id);
    if (existing == null) return;
    final clamped = _clampRectToImage(next);
    final updated = _applyRect(existing, clamped);
    widget.onOverlaysChanged(widget.overlays.map((o) => o.id == id ? updated : o).toList());
  }

  void _deleteOverlay(String id) {
    widget.onOverlaysChanged(widget.overlays.where((o) => o.id != id).toList());
    if (widget.selectedId == id) widget.onSelectedIdChanged(null);
  }

  bool _hitAnyOverlay(Offset containerLocal) {
    final containerSize = _containerSize(context);
    final pPx = screenToImagePixel(
      screenPoint: containerLocal,
      containerSize: containerSize,
      imageSize: widget.imageSize,
      transform: _controller.value,
    );
    if (pPx == null) return false;
    for (final o in widget.overlays) {
      if (_rectFor(o).contains(pPx)) return true;
    }
    return false;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.isEditing) return;
    final local = _globalToLocal(event.position);
    if (local == null) return;
    // Don't start drawing if user is interacting with an existing overlay box.
    if (_hitAnyOverlay(local)) return;

    final containerSize = _containerSize(context);
    final pPx = screenToImagePixel(
      screenPoint: local,
      containerSize: containerSize,
      imageSize: widget.imageSize,
      transform: _controller.value,
    );
    if (pPx == null) return;
    setState(() {
      _mode = _InteractionMode.drawing;
      _drawStartPx = pPx;
      _drawEndPx = pPx;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!widget.isEditing) return;
    if (_mode != _InteractionMode.drawing) return;
    final local = _globalToLocal(event.position);
    if (local == null) return;
    final containerSize = _containerSize(context);
    final pPx = screenToImagePixel(
      screenPoint: local,
      containerSize: containerSize,
      imageSize: widget.imageSize,
      transform: _controller.value,
    );
    if (pPx == null) return;
    setState(() => _drawEndPx = pPx);
  }

  void _onPointerCancel(PointerCancelEvent _) {
    if (!mounted) return;
    setState(() {
      _mode = _InteractionMode.none;
      _drawStartPx = null;
      _drawEndPx = null;
    });
  }

  Future<void> _onPointerUp(PointerUpEvent _) async {
    if (!widget.isEditing) return;
    if (_mode != _InteractionMode.drawing) return;
    final s = _drawStartPx;
    final e = _drawEndPx;
    setState(() {
      _mode = _InteractionMode.none;
      _drawStartPx = null;
      _drawEndPx = null;
    });
    if (s == null || e == null) return;

    final left = math.min(s.dx, e.dx);
    final top = math.min(s.dy, e.dy);
    final width = (s.dx - e.dx).abs();
    final height = (s.dy - e.dy).abs();
    if (width < 10 || height < 10) return;

    final created = await widget.onCreateOverlay(
      Rect.fromLTWH(left, top, width, height),
    );
    if (!mounted) return;
    if (created == null) return;
    widget.onOverlaysChanged([...widget.overlays, created]);
    widget.onSelectedIdChanged(created.id);
  }

  void startMove(String id, DragStartDetails details) {
    if (!widget.isEditing) return;
    final local = _globalToLocal(details.globalPosition);
    if (local == null) return;
    final containerSize = _containerSize(context);
    final pPx = screenToImagePixel(
      screenPoint: local,
      containerSize: containerSize,
      imageSize: widget.imageSize,
      transform: _controller.value,
    );
    final o = _findById(id);
    if (pPx == null || o == null) return;
    setState(() {
      _activeId = id;
      _mode = _InteractionMode.moving;
      _startPointerPx = pPx;
      _startRectPx = _rectFor(o);
    });
  }

  void updateMove(DragUpdateDetails details) {
    if (_mode != _InteractionMode.moving) return;
    final id = _activeId;
    final startPtr = _startPointerPx;
    final startRect = _startRectPx;
    if (id == null || startPtr == null || startRect == null) return;
    final local = _globalToLocal(details.globalPosition);
    if (local == null) return;
    final containerSize = _containerSize(context);
    final pPx = screenToImagePixel(
      screenPoint: local,
      containerSize: containerSize,
      imageSize: widget.imageSize,
      transform: _controller.value,
    );
    if (pPx == null) return;
    final delta = pPx - startPtr;
    _updateOverlay(id, startRect.shift(delta));
  }

  void endInteraction(DragEndDetails _) {
    if (!mounted) return;
    setState(() {
      _mode = _InteractionMode.none;
      _activeId = null;
      _startPointerPx = null;
      _startRectPx = null;
    });
  }

  void startResize(String id, _InteractionMode mode, DragStartDetails details) {
    if (!widget.isEditing) return;
    final local = _globalToLocal(details.globalPosition);
    if (local == null) return;
    final containerSize = _containerSize(context);
    final pPx = screenToImagePixel(
      screenPoint: local,
      containerSize: containerSize,
      imageSize: widget.imageSize,
      transform: _controller.value,
    );
    final o = _findById(id);
    if (pPx == null || o == null) return;
    setState(() {
      _activeId = id;
      _mode = mode;
      _startPointerPx = pPx;
      _startRectPx = _rectFor(o);
    });
  }

  void updateResize(DragUpdateDetails details) {
    final id = _activeId;
    final startPtr = _startPointerPx;
    final startRect = _startRectPx;
    if (id == null || startPtr == null || startRect == null) return;
    if (!(_mode == _InteractionMode.resizeTl ||
        _mode == _InteractionMode.resizeTr ||
        _mode == _InteractionMode.resizeBl ||
        _mode == _InteractionMode.resizeBr)) {
      return;
    }
    final local = _globalToLocal(details.globalPosition);
    if (local == null) return;
    final containerSize = _containerSize(context);
    final pPx = screenToImagePixel(
      screenPoint: local,
      containerSize: containerSize,
      imageSize: widget.imageSize,
      transform: _controller.value,
    );
    if (pPx == null) return;
    final dx = pPx.dx - startPtr.dx;
    final dy = pPx.dy - startPtr.dy;

    Rect next = startRect;
    switch (_mode) {
      case _InteractionMode.resizeTl:
        next = Rect.fromLTRB(next.left + dx, next.top + dy, next.right, next.bottom);
        break;
      case _InteractionMode.resizeTr:
        next = Rect.fromLTRB(next.left, next.top + dy, next.right + dx, next.bottom);
        break;
      case _InteractionMode.resizeBl:
        next = Rect.fromLTRB(next.left + dx, next.top, next.right, next.bottom + dy);
        break;
      case _InteractionMode.resizeBr:
        next = Rect.fromLTRB(next.left, next.top, next.right + dx, next.bottom + dy);
        break;
      default:
        break;
    }
    // Normalize inverted rects if user crosses over
    final l = math.min(next.left, next.right);
    final r = math.max(next.left, next.right);
    final t = math.min(next.top, next.bottom);
    final b = math.max(next.top, next.bottom);
    _updateOverlay(id, Rect.fromLTRB(l, t, r, b));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = constraints.biggest;
        final isInteracting = widget.isEditing && _mode != _InteractionMode.none;

        return Stack(
          key: _stackKey,
          children: [
            InteractiveViewer(
              transformationController: _controller,
              minScale: 0.5,
              maxScale: 6.0,
              panEnabled: !isInteracting,
              scaleEnabled: true,
              child: Image(image: widget.imageProvider, fit: BoxFit.contain),
            ),
            if (widget.isEditing)
              Positioned.fill(
                child: Listener(
                  onPointerDown: _onPointerDown,
                  onPointerMove: _onPointerMove,
                  onPointerUp: _onPointerUp,
                  onPointerCancel: _onPointerCancel,
                  behavior: HitTestBehavior.translucent,
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            // Rebuild overlay positions when zoom/pan changes.
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Stack(
                  children: [
                    ...widget.overlays.map((o) {
                      final rectPx = _rectFor(o);
                      final screenRect = imagePixelRectToScreenRect(
                        rectPx: rectPx,
                        containerSize: containerSize,
                        imageSize: widget.imageSize,
                        transform: _controller.value,
                      );
                      if (screenRect.width <= 0 || screenRect.height <= 0) {
                        return const SizedBox.shrink();
                      }

                      final selected = widget.selectedId == o.id;
                      final title =
                          (o.goal.title ?? '').trim().isNotEmpty ? o.goal.title!.trim() : o.id;

                      return Positioned(
                        left: screenRect.left,
                        top: screenRect.top,
                        width: screenRect.width,
                        height: screenRect.height,
                        child: GoalOverlayBox(
                          title: title,
                          isEditing: widget.isEditing,
                          isSelected: selected,
                          onTap: () {
                            if (widget.isEditing) {
                              widget.onSelectedIdChanged(o.id);
                              return;
                            }
                            widget.onOpenOverlay(o);
                          },
                          onDelete: widget.isEditing && selected ? () => _deleteOverlay(o.id) : null,
                          onMoveStart: widget.isEditing
                              ? (d) {
                                  widget.onSelectedIdChanged(o.id);
                                  startMove(o.id, d);
                                }
                              : null,
                          onMoveUpdate: widget.isEditing ? updateMove : null,
                          onMoveEnd: widget.isEditing ? endInteraction : null,
                          onResizeTlStart: widget.isEditing
                              ? (d) {
                                  widget.onSelectedIdChanged(o.id);
                                  startResize(o.id, _InteractionMode.resizeTl, d);
                                }
                              : null,
                          onResizeTlUpdate: widget.isEditing ? updateResize : null,
                          onResizeTlEnd: widget.isEditing ? endInteraction : null,
                          onResizeTrStart: widget.isEditing
                              ? (d) {
                                  widget.onSelectedIdChanged(o.id);
                                  startResize(o.id, _InteractionMode.resizeTr, d);
                                }
                              : null,
                          onResizeTrUpdate: widget.isEditing ? updateResize : null,
                          onResizeTrEnd: widget.isEditing ? endInteraction : null,
                          onResizeBlStart: widget.isEditing
                              ? (d) {
                                  widget.onSelectedIdChanged(o.id);
                                  startResize(o.id, _InteractionMode.resizeBl, d);
                                }
                              : null,
                          onResizeBlUpdate: widget.isEditing ? updateResize : null,
                          onResizeBlEnd: widget.isEditing ? endInteraction : null,
                          onResizeBrStart: widget.isEditing
                              ? (d) {
                                  widget.onSelectedIdChanged(o.id);
                                  startResize(o.id, _InteractionMode.resizeBr, d);
                                }
                              : null,
                          onResizeBrUpdate: widget.isEditing ? updateResize : null,
                          onResizeBrEnd: widget.isEditing ? endInteraction : null,
                        ),
                      );
                    }),
                    if (widget.isEditing &&
                        _mode == _InteractionMode.drawing &&
                        _drawStartPx != null &&
                        _drawEndPx != null)
                      Builder(
                        builder: (context) {
                          final s = _drawStartPx!;
                          final e = _drawEndPx!;
                          final left = math.min(s.dx, e.dx);
                          final top = math.min(s.dy, e.dy);
                          final w = (s.dx - e.dx).abs();
                          final h = (s.dy - e.dy).abs();
                          final rectPx = Rect.fromLTWH(left, top, w, h);
                          final screenRect = imagePixelRectToScreenRect(
                            rectPx: rectPx,
                            containerSize: containerSize,
                            imageSize: widget.imageSize,
                            transform: _controller.value,
                          );
                          return Positioned(
                            left: screenRect.left,
                            top: screenRect.top,
                            width: screenRect.width,
                            height: screenRect.height,
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFF39FF14), width: 2),
                                  color: const Color(0x1A39FF14),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

