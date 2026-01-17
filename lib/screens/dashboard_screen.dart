import 'dart:async';

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
import '../services/vision_board_components_storage_service.dart';
import '../services/reminder_summary_service.dart';
import 'grid_editor.dart';
import 'goal_canvas_editor_screen.dart';
import 'goal_canvas_viewer_screen.dart';
import 'physical_board_editor_screen.dart';
import 'physical_board_viewer_screen.dart';
import 'vision_board_editor_screen.dart';
import '../models/goal_overlay_component.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int _tabIndex = 0;
  bool _loading = true;
  SharedPreferences? _prefs;

  List<VisionBoardInfo> _boards = [];
  String? _activeBoardId;

  bool _loadingReminders = false;
  ReminderSummary? _reminderSummary;
  Timer? _remindersAutoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _startAutoRefreshReminders();
  }

  @override
  void dispose() {
    _remindersAutoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshReminders();
    }
  }

  void _startAutoRefreshReminders() {
    _remindersAutoRefreshTimer?.cancel();
    _remindersAutoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _refreshReminders();
    });
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _reload();
    await _refreshReminders();
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

  Future<void> _refreshReminders() async {
    if (_loadingReminders) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    setState(() => _loadingReminders = true);
    try {
      final summary = await ReminderSummaryService.build(boards: _boards, prefs: prefs);
      if (!mounted) return;
      setState(() => _reminderSummary = summary);
    } finally {
      if (mounted) setState(() => _loadingReminders = false);
    }
  }

  static String _monthDayLabel(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[(d.month - 1).clamp(0, 11)];
    return '$m ${d.day}';
  }

  static String _timeLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hh = ((h % 12) == 0) ? 12 : (h % 12);
    final ampm = h >= 12 ? 'PM' : 'AM';
    return '$hh:${m.toString().padLeft(2, '0')} $ampm';
  }

  Future<void> _openRemindersSheet() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final summary =
        _reminderSummary ?? await ReminderSummaryService.build(boards: _boards, prefs: prefs);
    if (!mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    List<DateTime> days = [];
    for (DateTime d = today; !d.isAfter(endOfMonth); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        final paddingBottom = MediaQuery.paddingOf(ctx).bottom;
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.85,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Reminders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + paddingBottom),
                    children: [
                      for (final d in days) ...[
                        Builder(
                          builder: (_) {
                            final iso = ReminderSummaryService.toIsoDate(d);
                            final items = summary.itemsByIsoDate[iso] ?? const <ReminderItem>[];
                            if (items.isEmpty) return const SizedBox.shrink();
                            final title = (d == today)
                                ? 'Today'
                                : (d == tomorrow)
                                    ? 'Tomorrow'
                                    : _monthDayLabel(d);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),
                                Text(
                                  title,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 8),
                                ...items.map((it) {
                                  final leading = it.kind == ReminderKind.habit
                                      ? const Icon(Icons.notifications_active_outlined)
                                      : const Icon(Icons.event_outlined);
                                  final time = it.minutesSinceMidnight == null
                                      ? null
                                      : _timeLabel(it.minutesSinceMidnight!);
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      leading: leading,
                                      title: Text(it.label),
                                      subtitle: Text(
                                        time == null ? it.boardTitle : '${it.boardTitle} • $time',
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            );
                          },
                        ),
                      ],
                      if (summary.itemsByIsoDate.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: Text('No reminders for the rest of this month.')),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
    if (layoutType == 'import_physical') {
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
          builder: (_) => PhysicalBoardEditorScreen(
            boardId: id,
            title: config.title,
            autoStartImport: true,
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
    await _reload();
    await _refreshReminders();
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
    await _refreshReminders();
  }

  Future<void> _openBoard(VisionBoardInfo board, {required bool startInEditMode}) async {
    await _setActiveBoard(board.id);
    if (!mounted) return;
    final gridTemplate = GridTemplates.byId(board.templateId);

    // Heuristic routing: boards that have GoalOverlayComponent are treated as physical boards,
    // even if the stored layoutType is freeform (legacy import behavior).
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final loadedComponents = await VisionBoardComponentsStorageService.loadComponents(board.id, prefs: prefs);
    final isPhysical = loadedComponents.any((c) => c is GoalOverlayComponent);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          if (isPhysical) {
            return startInEditMode
                ? PhysicalBoardEditorScreen(boardId: board.id, title: board.title, autoStartImport: false)
                : PhysicalBoardViewerScreen(boardId: board.id, title: board.title);
          }
          return switch (board.layoutType) {
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
          };
        },
      ),
    );
    await _clearActiveBoard();
    await _reload();
    await _refreshReminders();
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
        actions: [
          Builder(
            builder: (ctx) {
              final count = _reminderSummary?.todayPendingCount ?? 0;
              final icon = IconButton(
                tooltip: 'Reminders',
                onPressed: _openRemindersSheet,
                icon: const Icon(Icons.notifications_outlined),
              );
              if (count <= 0) return icon;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  icon,
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (i) {
          setState(() => _tabIndex = i);
          _refreshReminders();
        },
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

