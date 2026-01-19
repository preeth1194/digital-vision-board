import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/goal_overlay_component.dart';
import '../models/vision_components.dart';
import '../../services/board/boards_storage_service.dart';
import '../../services/board/vision_board_components_storage_service.dart';
import '../../widgets/common/editor/layers_sheet.dart';
import '../../widgets/habits/habit_tracker_sheet.dart';
import '../../widgets/board/physical_board/goal_overlay_canvas_view.dart';
import 'global_insights_screen.dart';
import 'habits_list_screen.dart';
import 'physical_board_editor_screen.dart';
import 'todos_list_screen.dart';

/// View-only screen for Physical Vision Boards.
///
/// - Shows scanned/photo background with goal overlays.
/// - Tapping an overlay opens its habit/task tracker.
/// - Bottom navigation: Photo / Habits / Tasks / Insights.
class PhysicalBoardViewerScreen extends StatefulWidget {
  final String boardId;
  final String title;

  const PhysicalBoardViewerScreen({
    super.key,
    required this.boardId,
    required this.title,
  });

  @override
  State<PhysicalBoardViewerScreen> createState() => _PhysicalBoardViewerScreenState();
}

class _PhysicalBoardViewerScreenState extends State<PhysicalBoardViewerScreen> {
  bool _loading = true;
  int _tabIndex = 0; // 0: Photo, 1: Habits, 2: Todo, 3: Insights
  String? _selectedId;
  String? _lastOpenedGoalComponentId;

  SharedPreferences? _prefs;

  ImageProvider? _bgProvider;
  Size? _bgImageSize; // source image pixel dimensions
  List<VisionComponent> _components = [];

  String get _imagePathKey => BoardsStorageService.boardImagePathKey(widget.boardId);

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = _prefs ?? await SharedPreferences.getInstance();
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
  }

  Future<void> _saveComponents(List<VisionComponent> updated) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await VisionBoardComponentsStorageService.saveComponents(widget.boardId, updated, prefs: prefs);
    if (!mounted) return;
    setState(() => _components = updated);
  }

  Future<void> _openHabitTracker(VisionComponent component, {int initialTabIndex = 0}) async {
    if (!mounted) return;
    setState(() {
      _selectedId = component.id;
      _lastOpenedGoalComponentId = component.id;
    });
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final maxHeight = MediaQuery.sizeOf(context).height - topInset;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(maxHeight: maxHeight),
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => HabitTrackerSheet(
        boardId: widget.boardId,
        component: component,
        initialTabIndex: initialTabIndex,
        onComponentUpdated: (updated) {
          final next = _components.map((c) => c.id == updated.id ? updated : c).toList();
          _saveComponents(next);
        },
        fullScreen: false,
      ),
    );
  }

  Future<void> _showLayers() async {
    final topToBottom = [..._components]..sort((a, b) => b.zIndex.compareTo(a.zIndex));
    final overlays = topToBottom.whereType<GoalOverlayComponent>().toList();
    if (overlays.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No goals yet.')),
      );
      return;
    }

    await showLayersSheet(
      context,
      componentsTopToBottom: overlays,
      selectedId: _selectedId,
      allowReorder: false,
      allowDelete: false,
      onReorder: (_) {},
      onDelete: (_) {},
      onSelect: (id) {
        setState(() => _selectedId = id);
        Navigator.of(context).pop();
      },
      onComplete: (id) {
        final existing = _components.whereType<GoalOverlayComponent>().cast<GoalOverlayComponent?>().firstWhere(
              (c) => c?.id == id,
              orElse: () => null,
            );
        if (existing == null) return;
        final updated = existing.copyWith(isDisabled: !existing.isDisabled);
        final next = _components.map((c) => c.id == id ? updated : c).toList();
        _saveComponents(next);
      },
    );
  }

  Future<void> _openEditor() async {
    await Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => PhysicalBoardEditorScreen(
          boardId: widget.boardId,
          title: widget.title,
          autoStartImport: false,
        ),
      ),
    )
        .then((_) async {
      if (mounted) await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _tabIndex == 0
        ? widget.title
        : _tabIndex == 1
            ? 'Habits'
            : _tabIndex == 2
                ? 'Todo'
                : 'Insights';

    final bg = _bgProvider;
    final bgSize = _bgImageSize;
    final overlays = _components.whereType<GoalOverlayComponent>().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_tabIndex == 0)
            IconButton(
              tooltip: 'Layers',
              icon: const Icon(Icons.layers_outlined),
              onPressed: _showLayers,
            ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _openEditor,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : switch (_tabIndex) {
              1 => HabitsListScreen(
                  components: _components,
                  onComponentsUpdated: _saveComponents,
                  showAppBar: false,
                ),
              2 => TodosListScreen(
                  components: _components,
                  onComponentsUpdated: _saveComponents,
                  showAppBar: false,
                  allowManageTodos: true,
                  preferredGoalComponentId: _lastOpenedGoalComponentId,
                  onOpenComponent: (c) => _openHabitTracker(c, initialTabIndex: 1),
                ),
              3 => GlobalInsightsScreen(components: _components),
              _ => (bg == null || bgSize == null)
                  ? const Center(child: Text('No photo found for this board.'))
                  : GoalOverlayCanvasView(
                      imageProvider: bg,
                      imageSize: bgSize,
                      isEditing: false,
                      overlays: overlays,
                      selectedId: _selectedId,
                      onSelectedIdChanged: (id) => setState(() => _selectedId = id),
                      onOverlaysChanged: (_) {},
                      onCreateOverlay: (_) async => null,
                      onOpenOverlay: (overlay) => _openHabitTracker(overlay),
                    ),
            },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.photo_outlined), label: 'Photo'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Habits'),
          BottomNavigationBarItem(icon: Icon(Icons.playlist_add_check), label: 'Todo'),
          BottomNavigationBarItem(icon: Icon(Icons.insights_outlined), label: 'Insights'),
        ],
      ),
    );
  }
}

