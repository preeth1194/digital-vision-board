import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_board_info.dart';
import '../models/grid_template.dart';
import '../models/grid_tile_model.dart';
import '../services/boards_storage_service.dart';
import '../services/grid_tiles_storage_service.dart';
import '../widgets/dashboard/dashboard_body.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/new_board_dialog.dart';
import 'grid_editor.dart';
import 'goal_canvas_editor_screen.dart';
import 'goal_canvas_viewer_screen.dart';
import 'physical_board_editor_screen.dart';
import 'vision_board_editor_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _tabIndex = 0;
  bool _loading = true;
  SharedPreferences? _prefs;

  List<VisionBoardInfo> _boards = [];
  String? _activeBoardId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _reload();
  }

  Future<void> _reload() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    final activeId = await BoardsStorageService.loadActiveBoardId(prefs: prefs);
    if (!mounted) return;
    setState(() {
      _boards = boards;
      _activeBoardId = activeId;
      _loading = false;
    });
  }

  Future<void> _saveBoards(List<VisionBoardInfo> boards) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await BoardsStorageService.saveBoards(boards, prefs: prefs);
  }

  Future<void> _setActiveBoard(String boardId) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await BoardsStorageService.setActiveBoardId(boardId, prefs: prefs);
    if (!mounted) return;
    setState(() => _activeBoardId = boardId);
  }

  Future<void> _clearActiveBoard() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await BoardsStorageService.clearActiveBoardId(prefs: prefs);
    if (!mounted) return;
    setState(() => _activeBoardId = null);
  }

  Future<void> _createBoard() async {
    final layoutType = await showTemplatePickerSheet(context);
    if (!mounted) return;
    if (layoutType == null) return;

    // Handle import options - these skip the normal board creation flow
    if (layoutType == 'import_physical' || layoutType == 'import_canva') {
      // Create a temporary freeform board for import
      final config = await showNewBoardDialog(context);
      if (!mounted) return;
      if (config == null || config.title.isEmpty) return;

      final id = 'board_${DateTime.now().millisecondsSinceEpoch}';
      final board = VisionBoardInfo(
        id: id,
        title: config.title,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        iconCodePoint: config.iconCodePoint,
        tileColorValue: config.tileColorValue,
        layoutType: VisionBoardInfo.layoutFreeform,
        templateId: null,
      );

      final next = [board, ..._boards];
      await _saveBoards(next);
      await _setActiveBoard(id);
      if (!mounted) return;
      setState(() => _boards = next);

      // Navigate to editor and trigger import
      if (!mounted) return;
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => layoutType == 'import_physical'
              ? PhysicalBoardEditorScreen(
                  boardId: id,
                  title: config.title,
                  initialIsEditing: true,
                  autoStartImport: true,
                )
              : VisionBoardEditorScreen(
                  boardId: id,
                  title: config.title,
                  initialIsEditing: true,
                  autoImportType: layoutType,
                ),
        ),
      );

      if (mounted) {
        if (result == true) await _reload();
        setState(() => _activeBoardId = id);
      }
      return;
    }

    GridTemplate? gridTemplate;
    if (layoutType == VisionBoardInfo.layoutGrid) {
      gridTemplate = await showGridTemplateSelectorSheet(context);
      if (!mounted) return;
      if (gridTemplate == null) return;
    }

    final config = await showNewBoardDialog(context);
    if (!mounted) return;
    if (config == null || config.title.isEmpty) return;

    final id = 'board_${DateTime.now().millisecondsSinceEpoch}';
    final board = VisionBoardInfo(
      id: id,
      title: config.title,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      iconCodePoint: config.iconCodePoint,
      tileColorValue: config.tileColorValue,
      layoutType: layoutType,
      templateId: gridTemplate?.id,
    );

    final next = [board, ..._boards];
    await _saveBoards(next);
    await _setActiveBoard(id);
    if (!mounted) return;
    setState(() => _boards = next);

    if (layoutType == VisionBoardInfo.layoutGrid && gridTemplate != null) {
      // Initialize the fixed template tiles (empty placeholders).
      final tiles = List<GridTileModel>.generate(
        gridTemplate.tiles.length,
        (i) => GridTileModel(
          id: 'tile_$i',
          type: 'empty',
          content: null,
          crossAxisCellCount: gridTemplate!.tiles[i].crossAxisCount,
          mainAxisCellCount: gridTemplate.tiles[i].mainAxisCount,
          index: i,
        ),
      );
      await GridTilesStorageService.saveTiles(id, tiles, prefs: _prefs);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (layoutType) {
          VisionBoardInfo.layoutGrid => GridEditorScreen(
              boardId: id,
              title: board.title,
              initialIsEditing: true,
              template: gridTemplate ?? GridTemplates.hero,
            ),
          VisionBoardInfo.layoutGoalCanvas => GoalCanvasEditorScreen(
              boardId: id,
              title: board.title,
            ),
          _ => VisionBoardEditorScreen(boardId: id, title: board.title, initialIsEditing: true),
        },
      ),
    );
    await _clearActiveBoard();
  }

  Future<void> _deleteBoard(VisionBoardInfo board) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete board?',
      message: 'Delete "${board.title}"? This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );
    if (!ok) return;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await BoardsStorageService.deleteBoardData(board.id, prefs: prefs);

    final next = _boards.where((b) => b.id != board.id).toList();
    await _saveBoards(next);
    if (_activeBoardId == board.id) await BoardsStorageService.clearActiveBoardId(prefs: prefs);
    if (!mounted) return;
    setState(() {
      _boards = next;
      if (_activeBoardId == board.id) _activeBoardId = null;
    });
  }

  Future<void> _openBoard(VisionBoardInfo board, {required bool startInEditMode}) async {
    await _setActiveBoard(board.id);
    if (!mounted) return;
    final gridTemplate = GridTemplates.byId(board.templateId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (board.layoutType) {
          VisionBoardInfo.layoutGrid => GridEditorScreen(
              boardId: board.id,
              title: board.title,
              initialIsEditing: startInEditMode,
              template: gridTemplate,
            ),
          VisionBoardInfo.layoutGoalCanvas => startInEditMode
              ? GoalCanvasEditorScreen(boardId: board.id, title: board.title)
              : GoalCanvasViewerScreen(boardId: board.id, title: board.title),
          _ => VisionBoardEditorScreen(
              boardId: board.id,
              title: board.title,
              initialIsEditing: startInEditMode,
            ),
        },
      ),
    );
    await _clearActiveBoard();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final body = DashboardBody(
      tabIndex: _tabIndex,
      boards: _boards,
      activeBoardId: _activeBoardId,
      prefs: _prefs,
      onCreateBoard: _createBoard,
      onOpenEditor: (b) => _openBoard(b, startInEditMode: true),
      onOpenViewer: (b) => _openBoard(b, startInEditMode: false),
      onDeleteBoard: _deleteBoard,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Digital Vision Board'),
        automaticallyImplyLeading: false,
        // Material 3认为 AppBar can be translucent; make it solid so navigation is always visible.
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Habits'),
          BottomNavigationBarItem(icon: Icon(Icons.checklist), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Insights'),
        ],
      ),
    );
  }
}

