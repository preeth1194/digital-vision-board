import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_board_info.dart';
import '../services/boards_storage_service.dart';
import '../widgets/dashboard/dashboard_body.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/new_board_dialog.dart';
import 'grid_board_editor.dart';
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
    if (layoutType == null) return;
    final config = await showNewBoardDialog(context);
    if (config == null || config.title.isEmpty) return;

    final id = 'board_${DateTime.now().millisecondsSinceEpoch}';
    final board = VisionBoardInfo(
      id: id,
      title: config.title,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      iconCodePoint: config.iconCodePoint,
      tileColorValue: config.tileColorValue,
      layoutType: layoutType,
    );

    final next = [board, ..._boards];
    await _saveBoards(next);
    await _setActiveBoard(id);
    if (!mounted) return;
    setState(() => _boards = next);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => layoutType == VisionBoardInfo.layoutGrid
            ? GridBoardEditor(boardId: id, title: board.title, initialIsEditing: true)
            : VisionBoardEditorScreen(boardId: id, title: board.title, initialIsEditing: true),
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => board.layoutType == VisionBoardInfo.layoutGrid
            ? GridBoardEditor(boardId: board.id, title: board.title, initialIsEditing: startInEditMode)
            : VisionBoardEditorScreen(boardId: board.id, title: board.title, initialIsEditing: startInEditMode),
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
      appBar: AppBar(title: const Text('Digital Vision Board'), automaticallyImplyLeading: false),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Habits'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Insights'),
        ],
      ),
    );
  }
}

