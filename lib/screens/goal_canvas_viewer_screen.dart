import 'dart:async';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_components.dart';
import '../utils/app_colors.dart';
import '../services/boards_storage_service.dart';
import '../services/google_drive_backup_service.dart';
import '../services/image_persistence.dart';
import '../services/vision_board_components_storage_service.dart';
import '../services/habit_storage_service.dart';
import '../widgets/editor/layers_sheet.dart';
import '../widgets/habit_tracker_sheet.dart';
import '../widgets/vision_board_builder.dart';
import 'goal_canvas_editor_screen.dart';
import 'global_insights_screen.dart';
import 'habits_list_screen.dart';
import 'todos_list_screen.dart';

/// View-only screen for Goal Canvas.
///
/// Tap a goal layer to open its habit tracker.
class GoalCanvasViewerScreen extends StatefulWidget {
  final String boardId;
  final String title;

  const GoalCanvasViewerScreen({
    super.key,
    required this.boardId,
    required this.title,
  });

  @override
  State<GoalCanvasViewerScreen> createState() => _GoalCanvasViewerScreenState();
}

class _GoalCanvasViewerScreenState extends State<GoalCanvasViewerScreen> {
  bool _loading = true;
  List<VisionComponent> _components = [];
  Color _backgroundColor = AppColors.offWhite;
  ImageProvider? _backgroundImage;
  Size? _canvasSize;
  String? _selectedId;
  String? _lastOpenedGoalComponentId;
  bool _uploading = false;
  int _tabIndex = 0; // 0: Canvas, 1: Habits, 2: Todo, 3: Insights

  final GlobalKey _exportKey = GlobalKey();

  String get _backgroundColorKey => BoardsStorageService.boardBgColorKey(widget.boardId);
  String get _backgroundImagePathKey => BoardsStorageService.boardImagePathKey(widget.boardId);

  @override
  void initState() {
    super.initState();
    _load();
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
      _components = loaded;
      if (bgColor != null) _backgroundColor = Color(bgColor);
      if (bgPath != null && bgPath.isNotEmpty) {
        _backgroundImage = io.File(bgPath).existsSync() ? FileImage(io.File(bgPath)) : null;
      } else {
        _backgroundImage = null;
      }
      if (cw != null && ch != null && cw > 0 && ch > 0) {
        _canvasSize = Size(cw, ch);
      }
      _loading = false;
    });
  }

  Future<void> _saveComponents(List<VisionComponent> updated) async {
    final prefs = await SharedPreferences.getInstance();
    // Sync habits to HabitStorageService when writing components.
    final previousHabitIds = <String, Set<String>>{};
    for (final c in _components) {
      final ids = <String>{...c.habits.map((h) => h.id), ...c.habitIds};
      if (ids.isNotEmpty) previousHabitIds[c.id] = ids;
    }
    await HabitStorageService.syncComponentsHabits(
      widget.boardId,
      updated,
      previousHabitIds,
      prefs: prefs,
    );
    await VisionBoardComponentsStorageService.saveComponents(widget.boardId, updated, prefs: prefs);
    if (!mounted) return;
    setState(() => _components = updated);
  }

  Future<void> _openHabitTracker(VisionComponent component, {int initialTabIndex = 0}) async {
    if (component is! ImageComponent) return; // only image goals have habits
    setState(() {
      _selectedId = component.id;
      _lastOpenedGoalComponentId = component.id;
    });
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
        initialTabIndex: initialTabIndex,
        onComponentUpdated: (updated) {
          final next = _components.map((c) => c.id == updated.id ? updated : c).toList();
          _saveComponents(next);
        },
      ),
    );
  }

  Future<void> _showLayers() async {
    final images = _components.whereType<ImageComponent>().toList()
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

    if (images.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No goals yet.')),
      );
      return;
    }

    await showLayersSheet(
      context,
      componentsTopToBottom: images,
      selectedId: _selectedId,
      // Viewer: read-only layers list (selection only).
      onDelete: (_) {},
      onReorder: (_) {},
      onSelect: (id) => setState(() => _selectedId = id),
      onComplete: (id) {
        final existing = _components.whereType<ImageComponent>().firstWhere((c) => c.id == id);
        final updated = existing.copyWith(isDisabled: !existing.isDisabled);
        final next = _components.map((c) => c.id == id ? updated : c).toList();
        _saveComponents(next);
      },
      allowReorder: false,
      allowDelete: false,
    );
  }

  Future<void> _uploadToGoogleDrive() async {
    if (_uploading) return;
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google Drive upload is not supported on web yet.')),
      );
      return;
    }

    try {
      setState(() => _uploading = true);

      final boundary = _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Switch to the Canvas tab to export.');
      }

      final pixelRatio = View.of(context).devicePixelRatio;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to encode PNG.');
      final bytes = byteData.buffer.asUint8List();

      final path = await persistImageBytesToAppStorage(bytes, extension: 'png');
      if (path == null || path.isEmpty) {
        throw Exception('Failed to save exported image to device storage.');
      }

      final fileId = await GoogleDriveBackupService.backupPng(
        filePath: path,
        fileName: 'goal_canvas_${widget.boardId}.png',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded to Google Drive (file id: $fileId).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Drive upload failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_tabIndex == 0)
            IconButton(
              tooltip: 'Layers',
              icon: const Icon(Icons.layers_outlined),
              onPressed: _showLayers,
            ),
          PopupMenuButton<String>(
            icon: _uploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'upload_drive') _uploadToGoogleDrive();
              if (value == 'edit') {
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (_) => GoalCanvasEditorScreen(
                      boardId: widget.boardId,
                      title: widget.title,
                    ),
                  ),
                )
                    .then((_) {
                  if (mounted) _load();
                });
              }
            },
            itemBuilder: (context) {
              // Only allow editing/exporting when viewing the canvas itself.
              if (_tabIndex != 0) return const [];
              return const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 12),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'upload_drive',
                  child: Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined),
                      SizedBox(width: 12),
                      Text('Upload to Google Drive'),
                    ],
                  ),
                ),
              ];
            },
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
              _ => RepaintBoundary(
                  key: _exportKey,
                  child: VisionBoardBuilder(
                    components: _components,
                    isEditing: false,
                    selectedComponentId: _selectedId,
                    onSelectedComponentIdChanged: (id) => setState(() => _selectedId = id),
                    onComponentsChanged: _saveComponents,
                    onOpenComponent: (c) => _openHabitTracker(c),
                    backgroundColor: _backgroundColor,
                    backgroundImage: _backgroundImage,
                    backgroundImageSize: null,
                    canvasSize: _canvasSize,
                  ),
                ),
            },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_outlined),
            label: 'Canvas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            label: 'Habits',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_add_check),
            label: 'Todo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
        ],
      ),
    );
  }
}

