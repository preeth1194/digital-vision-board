import 'package:flutter/material.dart';
import '../../models/hotspot_model.dart';
import 'hotspot_canvas_view.dart';
import 'hotspot_delete_flow.dart';
import 'hotspot_geometry.dart';
import 'hotspot_habits_flow.dart';

class VisionBoardHotspotBuilder extends StatefulWidget {
  final ImageProvider imageProvider;
  final List<HotspotModel> hotspots;
  final ValueChanged<List<HotspotModel>>? onHotspotsChanged;
  final ValueChanged<HotspotModel>? onHotspotDelete;
  final Future<HotspotModel?> Function(double x, double y, double width, double height)? onHotspotCreated;
  final Future<HotspotModel?> Function(HotspotModel hotspot)? onHotspotEdit;
  final ValueChanged<HotspotModel>? onHotspotSelected;
  final Set<HotspotModel> selectedHotspots;
  final bool showLabels;
  final bool isEditing;
  final Color hotspotBorderColor;
  final Color hotspotFillColor;
  final Color selectedHotspotBorderColor;
  final Color selectedHotspotFillColor;
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
    this.hotspotBorderColor = const Color(0xFF4A7C59),
    this.hotspotFillColor = const Color(0x1A4A7C59),
    this.selectedHotspotBorderColor = const Color(0xFF2D5A3D),
    this.selectedHotspotFillColor = const Color(0x332D5A3D),
    this.hotspotBorderWidth = 2.0,
  });

  @override
  State<VisionBoardHotspotBuilder> createState() => _VisionBoardHotspotBuilderState();
}

class _VisionBoardHotspotBuilderState extends State<VisionBoardHotspotBuilder> {
  final TransformationController _transformationController = TransformationController();
  Offset? _dragStart;
  Offset? _dragEnd;
  Size? _imageSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    _loadImageSize();
  }

  @override
  void didUpdateWidget(covariant VisionBoardHotspotBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isEditing != widget.isEditing && widget.isEditing) {
      _transformationController.value = Matrix4.identity();
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

  void _loadImageSize() {
    final stream = widget.imageProvider.resolve(const ImageConfiguration());
    _imageStreamListener = ImageStreamListener((ImageInfo info, bool _) {
      if (!mounted) return;
      setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    });
    _imageStream = stream;
    stream.addListener(_imageStreamListener!);
  }

  void _onPointerDown(Offset localPosition, Size containerSize) {
    if (!widget.isEditing) return;
    if (_imageSize == null) return;
    final point = screenToImageCoordinates(
      screenPoint: localPosition,
      containerSize: containerSize,
      imageSize: _imageSize!,
      transform: _transformationController.value,
    );
    if (point == null) return;
    setState(() { _dragStart = point; _dragEnd = point; });
  }

  void _onPointerMove(Offset localPosition, Size containerSize) {
    if (!widget.isEditing || _dragStart == null) return;
    if (_imageSize == null) return;
    final point = screenToImageCoordinates(
      screenPoint: localPosition,
      containerSize: containerSize,
      imageSize: _imageSize!,
      transform: _transformationController.value,
    );
    if (point == null) return;
    setState(() => _dragEnd = point);
  }

  Future<void> _onPointerUp() async {
    if (!widget.isEditing || _dragStart == null || _dragEnd == null) return;

    final x = (_dragStart!.dx < _dragEnd!.dx) ? _dragStart!.dx : _dragEnd!.dx;
    final y = (_dragStart!.dy < _dragEnd!.dy) ? _dragStart!.dy : _dragEnd!.dy;
    final width = (_dragStart!.dx - _dragEnd!.dx).abs();
    final height = (_dragStart!.dy - _dragEnd!.dy).abs();

    setState(() { _dragStart = null; _dragEnd = null; });

    if (width <= 0.01 || height <= 0.01) return;

    if (widget.onHotspotCreated != null) {
      final created = await widget.onHotspotCreated!(x, y, width, height);
      if (created == null) return;
      widget.onHotspotsChanged?.call([...widget.hotspots, created]);
      return;
    }

    widget.onHotspotsChanged?.call([
      ...widget.hotspots,
      HotspotModel(x: x, y: y, width: width, height: height),
    ]);
  }

  void _onPointerCancel() {
    if (!mounted) return;
    setState(() { _dragStart = null; _dragEnd = null; });
  }

  Future<void> _onHotspotTap(HotspotModel hotspot) async {
    if (widget.isEditing) {
      widget.onHotspotSelected?.call(hotspot);
      return;
    }
    if (_imageSize == null) return;
    await openHabitTrackerForHotspot(
      context: context,
      hotspot: hotspot,
      imageSize: _imageSize!,
      hotspots: widget.hotspots,
      onHotspotsChanged: widget.onHotspotsChanged,
    );
  }

  Future<void> _onHotspotLongPress(HotspotModel hotspot) async {
    if (!widget.isEditing) return;
    final ok = await confirmDeleteHotspot(context, hotspot);
    if (!ok) return;
    widget.onHotspotDelete?.call(hotspot);
  }

  @override
  Widget build(BuildContext context) {
    return HotspotCanvasView(
      transformationController: _transformationController,
      imageProvider: widget.imageProvider,
      imageSize: _imageSize,
      isEditing: widget.isEditing,
      showLabels: widget.showLabels,
      hotspots: widget.hotspots,
      selectedHotspots: widget.selectedHotspots,
      dragStart: _dragStart,
      dragEnd: _dragEnd,
      hotspotBorderColor: widget.hotspotBorderColor,
      hotspotFillColor: widget.hotspotFillColor,
      selectedHotspotBorderColor: widget.selectedHotspotBorderColor,
      selectedHotspotFillColor: widget.selectedHotspotFillColor,
      hotspotBorderWidth: widget.hotspotBorderWidth,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      onHotspotTap: _onHotspotTap,
      onHotspotLongPress: _onHotspotLongPress,
    );
  }
}

