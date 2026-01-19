import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal_metadata.dart';
import '../models/vision_components.dart';
import '../../services/board/board_scan_service.dart';
import '../../services/board/boards_storage_service.dart';
import '../../services/board/vision_board_components_storage_service.dart';
import '../../widgets/common/editor/add_name_dialog.dart';
import '../../widgets/common/editor/layers_sheet.dart';
import '../../widgets/habits/habit_tracker_sheet.dart';
import '../../widgets/board/physical_board/goal_overlay_canvas_view.dart';

/// Physical-board editor:
/// - scanned/photo image as background
/// - goal overlays stored in **image pixel coordinates**
/// - view/edit modes (tap goal overlay to open tracker/CBT)
class PhysicalBoardEditorScreen extends StatefulWidget {
  final String boardId;
  final String title;
  final bool autoStartImport;

  const PhysicalBoardEditorScreen({
    super.key,
    required this.boardId,
    required this.title,
    this.autoStartImport = true,
  });

  @override
  State<PhysicalBoardEditorScreen> createState() => _PhysicalBoardEditorScreenState();
}

class _PhysicalBoardEditorScreenState extends State<PhysicalBoardEditorScreen> {
  bool _loading = true;

  SharedPreferences? _prefs;
  Timer? _saveDebounce;

  ImageProvider? _bgProvider;
  Size? _bgImageSize; // source image pixel dimensions

  List<VisionComponent> _components = [];
  String? _selectedId;

  String get _imagePathKey => BoardsStorageService.boardImagePathKey(widget.boardId);

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

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 120), () async {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs ??= prefs;
      await VisionBoardComponentsStorageService.saveComponents(widget.boardId, _components, prefs: prefs);
    });
  }

  void _setComponents(List<VisionComponent> next) {
    setState(() => _components = next);
    if (!_loading) _scheduleSave();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    _prefs ??= prefs;

    final bgPath = prefs.getString(_imagePathKey);
    ImageProvider? bg;
    Size? bgSize;
    if (!kIsWeb && bgPath != null && bgPath.isNotEmpty) {
      final file = io.File(bgPath);
      if (await file.exists()) {
        bg = FileImage(file);
        bgSize = await _resolveImageSize(bg);
      }
    }

    final loaded = await VisionBoardComponentsStorageService.loadComponents(widget.boardId, prefs: prefs);
    if (!mounted) return;
    setState(() {
      _bgProvider = bg;
      _bgImageSize = bgSize;
      _components = loaded;
      _loading = false;
    });

    if (widget.autoStartImport && bg == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _importPhysicalBoard());
    }
  }

  Future<void> _importPhysicalBoard() async {
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import is not supported on web yet.')),
      );
      return;
    }

    final path = await scanAndCropPhysicalBoard(allowGallery: true);
    if (!mounted) return;
    if (path == null || path.isEmpty) return;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await prefs.setString(_imagePathKey, path);

    final file = io.File(path);
    final provider = FileImage(file);
    final size = await _resolveImageSize(provider);
    if (!mounted) return;
    setState(() {
      _bgProvider = provider;
      _bgImageSize = size;
    });
  }

  Future<void> _openHabitTracker(VisionComponent component) async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HabitTrackerSheet(
        boardId: widget.boardId,
        component: component,
        onComponentUpdated: (updated) {
          final next = _components.map((c) => c.id == updated.id ? updated : c).toList();
          _setComponents(next);
        },
        fullScreen: true,
      ),
    );
  }

  Future<bool> _confirmDeleteIfHasTrackerData(String id) async {
    final component = _components.cast<VisionComponent?>().firstWhere((c) => c?.id == id, orElse: () => null);
    final hasTrackerData = component != null &&
        ((component.habits.isNotEmpty || component.tasks.isNotEmpty) ||
            component.habits.any((h) => h.completedDates.isNotEmpty) ||
            component.tasks.any((t) => t.checklist.any((c) => (c.completedOn ?? '').trim().isNotEmpty)));

    if (!hasTrackerData) return true;
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
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    return ok;
  }

  Future<void> _showLayers() async {
    final topToBottom = [..._components]..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    await showLayersSheet(
      context,
      componentsTopToBottom: topToBottom,
      selectedId: _selectedId,
      allowReorder: false,
      allowDelete: true,
      onReorder: (_) {},
      onSelect: (id) {
        setState(() => _selectedId = id);
        Navigator.of(context).pop();
      },
      onDelete: (id) async {
        final ok = await _confirmDeleteIfHasTrackerData(id);
        if (!ok) return;
        _setComponents(_components.where((c) => c.id != id).toList());
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  Future<GoalOverlayComponent?> _createOverlay(Rect rectPx) async {
    final categorySuggestions = _components
        .whereType<GoalOverlayComponent>()
        .map((c) => c.goal.category)
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final res = await showAddNameAndCategoryDialog(
      context,
      title: 'Your Vision/Goal',
      categoryHint: 'Category (optional)',
      categorySuggestions: categorySuggestions,
    );
    if (!mounted) return null;
    if (res == null || res.name.trim().isEmpty) return null;
    final goalTitle = _uniqueGoalName(res.name);

    return GoalOverlayComponent(
      id: goalTitle,
      position: Offset(rectPx.left, rectPx.top),
      size: Size(rectPx.width, rectPx.height),
      rotation: 0,
      scale: 1,
      zIndex: _nextZ(),
      goal: GoalMetadata(title: goalTitle, category: res.category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgProvider;
    final bgSize = _bgImageSize;
    final overlays = _components.whereType<GoalOverlayComponent>().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${widget.title}'),
        actions: [
          IconButton(
            tooltip: 'Layers',
            icon: const Icon(Icons.layers_outlined),
            onPressed: _showLayers,
          ),
          IconButton(
            tooltip: 'Import/Replace photo',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: _importPhysicalBoard,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (bg == null || bgSize == null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_outlined, size: 44),
                        const SizedBox(height: 12),
                        const Text(
                          'Import your physical vision board photo to start.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _importPhysicalBoard,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Import photo'),
                        ),
                      ],
                    ),
                  ),
                )
              : GoalOverlayCanvasView(
                  imageProvider: bg,
                  imageSize: bgSize,
                  isEditing: true,
                  overlays: overlays,
                  selectedId: _selectedId,
                  onSelectedIdChanged: (id) => setState(() => _selectedId = id),
                  onOverlaysChanged: (nextOverlays) {
                    // Preserve any non-overlay components if they exist (unlikely for this editor).
                    final non = _components.where((c) => c is! GoalOverlayComponent).toList();
                    _setComponents([...non, ...nextOverlays]);
                  },
                  onCreateOverlay: _createOverlay,
                  onOpenOverlay: (overlay) => _openHabitTracker(overlay),
                ),
    );
  }
}

