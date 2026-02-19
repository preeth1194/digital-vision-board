import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_components.dart';
import '../models/goal_metadata.dart';
import '../services/boards_storage_service.dart';
import '../services/vision_board_components_storage_service.dart';
import '../services/image_persistence.dart';
import '../services/image_service.dart';
import '../widgets/editor/add_name_dialog.dart';
import '../widgets/editor/background_options_sheet.dart';
import '../widgets/editor/layers_sheet.dart';
import '../widgets/editor/text_editor_dialog.dart';
import '../widgets/dialogs/goal_details_dialog.dart';
import '../widgets/grid/image_source_sheet.dart';
import '../widgets/vision_board_builder.dart';

/// Canva-style freeform canvas for **goal images only**.
///
/// - User adds a goal by picking an image -> cropper -> saved as a layer.
/// - User can drag/resize layers.
/// - Habits are tracked per goal (image) layer (edited in viewer / HabitTrackerSheet).
/// - This screen does not write habits; habit data is read from components for display only (backward compat via component.habits).
/// - Text is allowed for decoration (not for tracking).
class GoalCanvasEditorScreen extends StatefulWidget {
  final String boardId;
  final String title;

  const GoalCanvasEditorScreen({
    super.key,
    required this.boardId,
    required this.title,
  });

  @override
  State<GoalCanvasEditorScreen> createState() => _GoalCanvasEditorScreenState();
}

class _GoalCanvasEditorScreenState extends State<GoalCanvasEditorScreen> {
  static const double _pickedImageMaxSide = 2048;
  static const int _pickedImageQuality = 92;

  bool _loading = true;
  List<VisionComponent> _components = [];
  String? _selectedId;

  Color _backgroundColor = const Color(0xFFF8F9F4);
  ImageProvider? _backgroundImage;
  Size? _canvasSize;

  Timer? _saveDebounce;

  String get _backgroundColorKey => BoardsStorageService.boardBgColorKey(widget.boardId);
  String get _backgroundImagePathKey => BoardsStorageService.boardImagePathKey(widget.boardId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final loaded = await VisionBoardComponentsStorageService.loadComponents(widget.boardId, prefs: prefs);
    final bgColor = prefs.getInt(_backgroundColorKey);
    final bgPath = prefs.getString(_backgroundImagePathKey);
    final cw = prefs.getDouble(BoardsStorageService.boardCanvasWidthKey(widget.boardId)) ??
        (prefs.getInt(BoardsStorageService.boardCanvasWidthKey(widget.boardId))?.toDouble());
    final ch = prefs.getDouble(BoardsStorageService.boardCanvasHeightKey(widget.boardId)) ??
        (prefs.getInt(BoardsStorageService.boardCanvasHeightKey(widget.boardId))?.toDouble());
    if (!mounted) return;
    setState(() {
      _components = loaded; // goal canvas supports image goals + decorative text
      if (bgColor != null) _backgroundColor = Color(bgColor);
      if (bgPath != null && bgPath.isNotEmpty && !kIsWeb) {
        _backgroundImage = FileImage(io.File(bgPath));
      } else {
        _backgroundImage = null;
      }
      if (cw != null && ch != null && cw > 0 && ch > 0) {
        _canvasSize = Size(cw, ch);
      }
      _loading = false;
    });
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 120), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_backgroundColorKey, _backgroundColor.value);
      await VisionBoardComponentsStorageService.saveComponents(widget.boardId, _components, prefs: prefs);
    });
  }

  VisionComponent _clampToCanvas(VisionComponent c) {
    final canvas = _canvasSize;
    if (canvas == null || canvas.width <= 0 || canvas.height <= 0) return c;

    final maxW = canvas.width;
    final maxH = canvas.height;

    final w = c.size.width.clamp(40.0, maxW);
    final h = c.size.height.clamp(40.0, maxH);

    final maxDx = (maxW - w).isFinite && (maxW - w) > 0 ? (maxW - w) : 0.0;
    final maxDy = (maxH - h).isFinite && (maxH - h) > 0 ? (maxH - h) : 0.0;

    final dx = c.position.dx.isFinite ? c.position.dx.clamp(0.0, maxDx) : 0.0;
    final dy = c.position.dy.isFinite ? c.position.dy.clamp(0.0, maxDy) : 0.0;

    return c.copyWithCommon(position: Offset(dx, dy), size: Size(w, h));
  }

  void _setComponents(List<VisionComponent> next) {
    final clamped = next.map(_clampToCanvas).toList();
    setState(() => _components = clamped);
    _scheduleSave();
  }

  int _nextZ() {
    if (_components.isEmpty) return 0;
    return _components.map((c) => c.zIndex).reduce((a, b) => a > b ? a : b) + 1;
  }

  String _uniqueGoalName(String base) {
    final trimmed = base.trim().isEmpty ? 'Goal' : base.trim();
    if (_components.every((c) => c.id != trimmed)) return trimmed;
    int i = 2;
    while (_components.any((c) => c.id == '$trimmed ($i)')) {
      i++;
    }
    return '$trimmed ($i)';
  }

  Future<Size?> _resolveImageSize(ImageProvider provider) async {
    try {
      final stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<ImageInfo>();
      late final ImageStreamListener listener;
      listener = ImageStreamListener((info, _) {
        completer.complete(info);
        stream.removeListener(listener);
      }, onError: (error, stackTrace) {
        completer.completeError(error, stackTrace);
        stream.removeListener(listener);
      });
      stream.addListener(listener);
      final info = await completer.future;
      return Size(info.image.width.toDouble(), info.image.height.toDouble());
    } catch (_) {
      return null;
    }
  }

  Size _defaultSizeForImage(Size? imageSize) {
    // Reasonable bounds for an initial layer size (user can resize afterwards).
    const minSide = 180.0;
    const maxSide = 520.0;

    if (imageSize == null || imageSize.width <= 0 || imageSize.height <= 0) {
      return const Size(420, 320);
    }

    var w = imageSize.width;
    var h = imageSize.height;
    final maxCurrent = w > h ? w : h;
    final minCurrent = w < h ? w : h;

    // Scale up tiny images a bit.
    if (maxCurrent < minSide) {
      final s = minSide / maxCurrent;
      w *= s;
      h *= s;
    }

    // Scale down large images.
    if (maxCurrent > maxSide) {
      final s = maxSide / maxCurrent;
      w *= s;
      h *= s;
    }

    // Avoid super thin defaults.
    if (minCurrent < 80) {
      final s = 80 / minCurrent;
      w *= s;
      h *= s;
    }

    return Size(w, h);
  }

  Offset _defaultPosition(Size layerSize) {
    final s = _canvasSize ?? MediaQuery.of(context).size;
    final x = (s.width - layerSize.width) / 2;
    final y = (s.height - layerSize.height) / 3;
    final dx = x.isFinite ? x.clamp(12.0, (s.width - layerSize.width).clamp(12.0, s.width)) : 12.0;
    final dy = y.isFinite ? y.clamp(12.0, (s.height - layerSize.height).clamp(12.0, s.height)) : 12.0;
    return Offset(dx, dy);
  }

  Future<void> _addGoalImage() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Goal images are not supported on web yet.')),
      );
      return;
    }

    final ImageSource? source = await showImageSourceSheet(context);
    if (!mounted) return;
    if (source == null) return;

    final croppedPath = await ImageService.pickAndCropImage(
      context,
      source: source,
      maxWidth: _pickedImageMaxSide,
      maxHeight: _pickedImageMaxSide,
      imageQuality: _pickedImageQuality,
    );
    if (!mounted) return;
    if (croppedPath == null || croppedPath.isEmpty) return;

    final categorySuggestions = _components
        .whereType<ImageComponent>()
        .map((c) => c.goal?.category)
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final nameRes = await showAddNameAndCategoryDialog(
      context,
      title: 'Goal name',
      categoryHint: 'Category (optional)',
      categorySuggestions: categorySuggestions,
    );
    if (!mounted) return;
    if (nameRes == null || nameRes.name.trim().isEmpty) return;

    final goalName = _uniqueGoalName(nameRes.name);
    final initialMeta = GoalMetadata(title: goalName, category: nameRes.category);
    final goalDetails = await showGoalDetailsDialog(context, goalTitle: goalName, initial: initialMeta);
    if (!mounted) return;

    final goalMetaToSave = goalDetails ?? (nameRes.category == null ? null : initialMeta);

    Size? imageSize;
    try {
      final file = io.File(croppedPath);
      if (await file.exists()) {
        imageSize = await _resolveImageSize(FileImage(file));
      }
    } catch (_) {}

    final layerSize = _defaultSizeForImage(imageSize);
    final layerPos = _defaultPosition(layerSize);

    final layer = ImageComponent(
      id: goalName,
      position: layerPos,
      size: layerSize,
      rotation: 0,
      scale: 1,
      zIndex: _nextZ(),
      imagePath: croppedPath,
      goal: goalMetaToSave,
    );

    _setComponents([..._components, layer]);
    setState(() => _selectedId = layer.id);
  }

  String _uniqueTextId(String base) {
    final trimmed = base.trim().isEmpty ? 'Text' : base.trim();
    if (_components.every((c) => c.id != trimmed)) return trimmed;
    int i = 2;
    while (_components.any((c) => c.id == '$trimmed ($i)')) {
      i++;
    }
    return '$trimmed ($i)';
  }

  Future<void> _addTextLayer() async {
    final colorScheme = Theme.of(context).colorScheme;
    final result = await showTextEditorDialog(
      context,
      initialText: '',
      initialStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
    );
    if (!mounted) return;
    if (result == null || result.text.trim().isEmpty) return;

    final id = _uniqueTextId(result.text.length > 24 ? '${result.text.substring(0, 24)}…' : result.text);
    final size = const Size(300, 110);
    final pos = _defaultPosition(size);

    final c = TextComponent(
      id: id,
      position: pos,
      size: size,
      rotation: 0,
      scale: 1,
      zIndex: _nextZ(),
      text: result.text,
      style: result.style,
      textAlign: result.textAlign,
    );

    _setComponents([..._components, c]);
    setState(() => _selectedId = c.id);
  }

  Future<void> _editSelectedText() async {
    final id = _selectedId;
    if (id == null) return;
    final component = _components.whereType<TextComponent>().cast<TextComponent?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
    if (component == null) return;

    final result = await showTextEditorDialog(
      context,
      initialText: component.text,
      initialStyle: component.style,
      initialTextAlign: component.textAlign,
    );
    if (!mounted) return;
    if (result == null) return;

    final updated = component.copyWith(text: result.text, style: result.style, textAlign: result.textAlign);
    _setComponents(_components.map((c) => c.id == updated.id ? updated : c).toList());
    setState(() => _selectedId = updated.id);
  }

  Future<void> _deleteById(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete goal?'),
        content: Text(
          'Delete "$id"? This will delete all habits, tasks, and streak history associated with this goal.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final next = _components.where((c) => c.id != id).toList();
    _setComponents(next);
    if (_selectedId == id) setState(() => _selectedId = null);
  }

  Future<void> _showLayers() async {
    final sorted = List<VisionComponent>.from(_components)
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

    await showLayersSheet(
      context,
      componentsTopToBottom: sorted,
      selectedId: _selectedId,
      onDelete: (id) async {
        Navigator.of(context).pop();
        await _deleteById(id);
      },
      onSelect: (id) {
        setState(() => _selectedId = id);
      },
      onReorder: (newOrderTopToBottom) {
        final count = newOrderTopToBottom.length;
        final updated = <VisionComponent>[];
        for (int i = 0; i < count; i++) {
          final component = newOrderTopToBottom[i];
          final existing = _components.firstWhere((c) => c.id == component.id);
          updated.add(existing.copyWithCommon(zIndex: count - 1 - i));
        }
        _setComponents(updated);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedId == null ? null : _components.where((c) => c.id == _selectedId).cast<VisionComponent?>().firstWhere((c) => true, orElse: () => null);
    final selectedIsText = selected is TextComponent;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Edit: ${widget.title}'),
        actions: [
          if (selectedIsText)
            IconButton(
              tooltip: 'Edit text',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editSelectedText,
            ),
          if (_selectedId != null)
            IconButton(
              tooltip: 'Delete selected',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteById(_selectedId!),
            ),
          IconButton(
            tooltip: 'Layers',
            icon: const Icon(Icons.layers_outlined),
            onPressed: _showLayers,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final nextSize = constraints.biggest;
                // If no fixed canvas size is persisted (non-template boards), default to viewport size.
                if (_canvasSize == null && _canvasSize != nextSize) {
                  // Store the current canvas bounds and clamp any existing items once.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    setState(() => _canvasSize = nextSize);
                    _setComponents(_components);
                  });
                }

                return VisionBoardBuilder(
                  components: _components,
                  isEditing: true,
                  selectedComponentId: _selectedId,
                  onSelectedComponentIdChanged: (id) => setState(() => _selectedId = id),
                  onComponentsChanged: _setComponents,
                  onOpenComponent: (_) {},
                  backgroundColor: _backgroundColor,
                  backgroundImage: _backgroundImage,
                  backgroundImageSize: null,
                  canvasSize: _canvasSize,
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: BottomAppBar(
          height: 72,
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                tooltip: 'Add goal',
                icon: const Icon(Icons.add_photo_alternate_outlined),
                onPressed: _addGoalImage,
              ),
              IconButton(
                tooltip: 'Add text',
                icon: const Icon(Icons.text_fields),
                onPressed: _addTextLayer,
              ),
              IconButton(
                tooltip: 'Background',
                icon: const Icon(Icons.format_paint_outlined),
                onPressed: () async {
                  await showBackgroundOptionsSheet(
                    context,
                    onPickBackgroundImage: () async {
                      if (kIsWeb) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Background images are not supported on web yet.')),
                        );
                        return;
                      }
                      final ImageSource? source = await showImageSourceSheet(context);
                      if (!mounted) return;
                      if (source == null) return;
                      final picked = await ImagePicker().pickImage(
                        source: source,
                        maxWidth: _pickedImageMaxSide,
                        maxHeight: _pickedImageMaxSide,
                        imageQuality: _pickedImageQuality,
                      );
                      if (!mounted) return;
                      if (picked == null) return;
                      final persisted = await persistImageToAppStorage(picked.path);
                      final path = persisted ?? picked.path;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(_backgroundImagePathKey, path);
                      if (!mounted) return;
                      setState(() => _backgroundImage = FileImage(io.File(path)));
                      _scheduleSave();
                    },
                    onPickColor: (c) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt(_backgroundColorKey, c.value);
                      if (!mounted) return;
                      setState(() => _backgroundColor = c);
                      _scheduleSave();
                    },
                    onClearBackgroundImage: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove(_backgroundImagePathKey);
                      if (!mounted) return;
                      setState(() => _backgroundImage = null);
                      _scheduleSave();
                    },
                  );
                },
              ),
              IconButton(
                tooltip: 'Layers',
                icon: const Icon(Icons.layers_outlined),
                onPressed: _showLayers,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

