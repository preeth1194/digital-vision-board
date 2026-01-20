import 'dart:async';

import 'package:flutter/material.dart';
import '../utils/app_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/core_value.dart';
import '../models/vision_board_info.dart';
import '../models/grid_template.dart';
import '../services/boards_storage_service.dart';
import '../widgets/dashboard/dashboard_body.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/new_board_dialog.dart';
import '../services/vision_board_components_storage_service.dart';
import '../services/reminder_summary_service.dart';
import '../services/dv_auth_service.dart';
import '../services/sync_service.dart';
import '../services/logical_date_service.dart';
import 'auth/auth_gateway_screen.dart';
import 'grid_editor.dart';
import 'wizard/create_board_wizard_screen.dart';
import 'goal_canvas_editor_screen.dart';
import 'goal_canvas_viewer_screen.dart';
import 'physical_board_editor_screen.dart';
import 'physical_board_viewer_screen.dart';
import 'settings_screen.dart';
import 'templates/template_gallery_screen.dart';
import 'vision_board_editor_screen.dart';
import '../models/goal_overlay_component.dart';
import 'journal_notes_screen.dart';
import '../widgets/dialogs/home_screen_widget_instructions_sheet.dart';
import 'vision_board_home_screen.dart';
import 'puzzle_game_screen.dart';
import '../services/puzzle_service.dart';
import '../services/widget_deeplink_service.dart';
import 'widget_guide_screen.dart';
import '../models/routine.dart';
import '../services/routine_storage_service.dart';
import 'routine_editor_screen.dart';
import 'routine_execution_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  static const String _addWidgetPromptShownKey = 'dv_add_widget_prompt_shown_v1';
  int _tabIndex = 1;
  bool _loading = true;
  SharedPreferences? _prefs;
  bool _checkedGuestExpiry = false;
  bool _checkedMandatoryLogin = false;

  List<VisionBoardInfo> _boards = [];
  String? _activeBoardId;
  List<Routine> _routines = [];
  String? _activeRoutineId;

  bool _loadingReminders = false;
  ReminderSummary? _reminderSummary;
  Timer? _remindersAutoRefreshTimer;
  VoidCallback? _syncAuthListener;
  final ValueNotifier<int> _boardDataVersion = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
    _startAutoRefreshReminders();
    _checkPuzzleDeepLink();
  }

  Future<void> _checkPuzzleDeepLink() async {
    // Check if puzzle should be opened from widget deep link
    final shouldOpen = await WidgetDeepLinkService.shouldOpenPuzzle(prefs: _prefs);
    if (shouldOpen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openPuzzleGame();
        }
      });
    }
  }

  @override
  void dispose() {
    _remindersAutoRefreshTimer?.cancel();
    if (_syncAuthListener != null) {
      SyncService.authExpired.removeListener(_syncAuthListener!);
    }
    _boardDataVersion.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshReminders();
      // Best-effort: if user is still on a guest session after 10 days, re-prompt.
      _maybeShowAuthGatewayIfMandatoryAfterTenDays();
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
    await DvAuthService.migrateLegacyTokenIfNeeded(prefs: _prefs);
    await SyncService.bootstrapIfNeeded(prefs: _prefs);
    await LogicalDateService.ensureInitialized(prefs: _prefs);
    await _reload();
    await _reloadRoutines();
    await SyncService.pruneLocalFeedback(prefs: _prefs);
    await SyncService.pushSnapshotsBestEffort(prefs: _prefs);
    await _refreshReminders();
    await _maybeShowAuthGatewayIfGuestExpired();
    await _maybeShowAuthGatewayIfMandatoryAfterTenDays();

    _syncAuthListener ??= () {
      if (!mounted) return;
      if (SyncService.authExpired.value) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AuthGatewayScreen(forced: true),
            fullscreenDialog: true,
          ),
        );
      }
    };
    SyncService.authExpired.addListener(_syncAuthListener!);
  }

  Future<void> _maybeShowAuthGatewayIfMandatoryAfterTenDays() async {
    if (_checkedMandatoryLogin) return;
    _checkedMandatoryLogin = true;

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;

    final firstInstallMs = await DvAuthService.getFirstInstallMs(prefs: prefs);
    if (firstInstallMs == null || firstInstallMs <= 0) return;
    final ageMs = DateTime.now().millisecondsSinceEpoch - firstInstallMs;
    if (ageMs < const Duration(days: 10).inMilliseconds) return;

    // Only force prompt for guest users (logged-in users should not be interrupted).
    final isGuest = await DvAuthService.isGuestSession(prefs: prefs);
    if (!isGuest) return;
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AuthGatewayScreen(forced: true),
          fullscreenDialog: true,
        ),
      );
    });
  }

  Future<void> _maybeShowAuthGatewayIfGuestExpired() async {
    if (_checkedGuestExpiry) return;
    _checkedGuestExpiry = true;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final expired = await DvAuthService.isGuestExpired(prefs: prefs);
    if (!expired) return;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AuthGatewayScreen(forced: true),
          fullscreenDialog: true,
        ),
      );
    });
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

  Future<void> _reloadRoutines() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final routines = await RoutineStorageService.loadRoutines(prefs: prefs);
    final activeId = await RoutineStorageService.loadActiveRoutineId(prefs: prefs);
    if (!mounted) return;
    setState(() {
      _routines = routines;
      _activeRoutineId = activeId;
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

  Future<void> _openLandingScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VisionBoardHomeScreen()),
    );
    // Refresh data when returning from landing screen
    await _refreshReminders();
  }

  Future<void> _openRemindersSheet() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final summary =
        _reminderSummary ?? await ReminderSummaryService.build(boards: _boards, prefs: prefs);
    if (!mounted) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayIso = ReminderSummaryService.toIsoDate(today);
    final todayItems = summary.itemsByIsoDate[todayIso] ?? const <ReminderItem>[];

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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Reminders',
                    style: AppTypography.heading3(context),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + paddingBottom),
                    children: [
                      if (todayItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: Text('No reminders today.')),
                        ),
                      ...todayItems.map((it) {
                        final leading = it.kind == ReminderKind.habit
                            ? const Icon(Icons.notifications_active_outlined)
                            : const Icon(Icons.event_outlined);
                        final time = it.minutesSinceMidnight == null ? null : _timeLabel(it.minutesSinceMidnight!);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: leading,
                            title: Text(it.label),
                            subtitle: Text(time == null ? it.boardTitle : '${it.boardTitle} • $time'),
                          ),
                        );
                      }),
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

  Future<void> _maybePromptAddWidgetIfFirstBoardCreated({required int boardsBefore}) async {
    if (boardsBefore != 0) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    final already = prefs.getBool(_addWidgetPromptShownKey) ?? false;
    if (already) return;
    if (_boards.isEmpty) return;
    if (!mounted) return;

    // Mark as shown up-front so it remains one-time even if user background-kills mid-sheet.
    await prefs.setBool(_addWidgetPromptShownKey, true);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add home-screen widget?',
                  style: AppTypography.heading3(context),
                ),
                const SizedBox(height: 8),
                const Text('Get a quick view of today’s habits and mark them complete from your home screen.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    showHomeScreenWidgetInstructionsSheet(context);
                  },
                  child: const Text('Yes'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Not now'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAccount() async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AuthGatewayScreen(forced: false),
        fullscreenDialog: true,
      ),
    );
    if (res == true) {
      // Token refreshed (guest) or user logged in. Attempt bootstrap/sync/prune.
      await SyncService.bootstrapIfNeeded(prefs: _prefs);
      await LogicalDateService.reloadHomeTimezone(prefs: _prefs);
      await SyncService.pruneLocalFeedback(prefs: _prefs);
      await SyncService.pushSnapshotsBestEffort(prefs: _prefs);
      await _reload();
    }
  }

  void _openSettings() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  Future<void> _openPuzzleGame() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    
    final imagePath = await PuzzleService.getCurrentPuzzleImage(
      boards: _boards,
      prefs: prefs,
    );

    if (imagePath == null || imagePath.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No puzzle images available. Add goal images to your vision boards.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleGameScreen(
          imagePath: imagePath,
          prefs: prefs,
        ),
      ),
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

  Future<void> _createRoutine() async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RoutineEditorScreen()),
    );
    if (mounted && res == true) {
      await _reloadRoutines();
    }
  }

  Future<void> _openRoutine(Routine routine) async {
    await RoutineStorageService.setActiveRoutineId(routine.id, prefs: _prefs);
    if (!mounted) return;
    setState(() => _activeRoutineId = routine.id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutineExecutionScreen(routine: routine),
      ),
    );
    await RoutineStorageService.clearActiveRoutineId(prefs: _prefs);
    if (!mounted) return;
    setState(() => _activeRoutineId = null);
    await _reloadRoutines();
  }

  Future<void> _editRoutine(Routine routine) async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoutineEditorScreen(routine: routine),
      ),
    );
    if (mounted && res == true) {
      await _reloadRoutines();
    }
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete routine?',
      message: 'Delete "${routine.title}"? This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (!ok) return;

    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await RoutineStorageService.deleteRoutineData(routine.id, prefs: prefs);

      final next = _routines.where((r) => r.id != routine.id).toList();
      await RoutineStorageService.saveRoutines(next, prefs: prefs);
      if (_activeRoutineId == routine.id) {
        await RoutineStorageService.clearActiveRoutineId(prefs: prefs);
      }
      if (!mounted) return;
      setState(() {
        _routines = next;
        if (_activeRoutineId == routine.id) _activeRoutineId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${routine.title}"')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting routine: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _createBoard() async {
    final boardsBefore = _boards.length;
    final layoutType = await showTemplatePickerSheet(context);
    if (!mounted) return;
    if (layoutType == null) return;

    if (layoutType == 'browse_templates') {
      final res = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const TemplateGalleryScreen()),
      );
      if (mounted && res == true) {
        await _reload();
        await _refreshReminders();
        await _maybePromptAddWidgetIfFirstBoardCreated(boardsBefore: boardsBefore);
      }
      return;
    }

    if (layoutType == 'create_wizard') {
      final res = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const CreateBoardWizardScreen()),
      );
      if (mounted && res == true) {
        await _reload();
        await _refreshReminders();
        await _maybePromptAddWidgetIfFirstBoardCreated(boardsBefore: boardsBefore);
      }
      return;
    }

    final config = await showNewBoardDialog(context);
    if (!mounted) return;
    if (config == null || config.title.isEmpty) return;

    final core = CoreValues.byId(config.coreValueId);
    final id = 'board_${DateTime.now().millisecondsSinceEpoch}';
    final board = VisionBoardInfo(
      id: id,
      title: config.title,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      coreValueId: core.id,
      iconCodePoint: core.icon.codePoint,
      tileColorValue: core.tileColor.toARGB32(),
      layoutType: layoutType,
      templateId: null,
    );

    final next = [board, ..._boards];
    await _saveBoards(next);
    await _setActiveBoard(id);
    if (!mounted) return;
    setState(() => _boards = next);

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => switch (layoutType) {
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
    await _maybePromptAddWidgetIfFirstBoardCreated(boardsBefore: boardsBefore);
  }

  Future<void> _deleteBoard(VisionBoardInfo board) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete board?',
      message: 'Delete "${board.title}"? This cannot be undone.',
      confirmText: 'Delete',
      confirmColor: Theme.of(context).colorScheme.error,
    );
    if (!ok) return;

    try {
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${board.title}"')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting board: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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
    if (!mounted) return;

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

    const visibleTabIndices = <int>[1, 2, 3, 4]; // Dashboard, Journal, Affirmations, Insights
    final visibleNavIndex = visibleTabIndices.indexOf(_tabIndex);

    final appBarTitle = _tabIndex == 1
        ? 'Dashboard'
        : _tabIndex == 2
            ? 'Journal'
            : _tabIndex == 3
                ? 'Affirmations'
                : _tabIndex == 4
                    ? 'Insights'
                    : 'Digital Vision Board';

    final body = DashboardBody(
      tabIndex: _tabIndex,
      boards: _boards,
      activeBoardId: _activeBoardId,
      routines: _routines,
      activeRoutineId: _activeRoutineId,
      prefs: _prefs,
      boardDataVersion: _boardDataVersion,
      onCreateBoard: _createBoard,
      onCreateRoutine: _createRoutine,
      onOpenEditor: (b) => _openBoard(b, startInEditMode: true),
      onOpenViewer: (b) => _openBoard(b, startInEditMode: false),
      onDeleteBoard: _deleteBoard,
      onOpenRoutine: _openRoutine,
      onEditRoutine: _editRoutine,
      onDeleteRoutine: _deleteRoutine,
    );

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Digital Vision Board',
                    style: AppTypography.heading3(context),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<String?>(
                    future: DvAuthService.getCanvaUserId(prefs: _prefs),
                    builder: (context, snap) {
                      final id = (snap.data ?? '').trim();
                      final label = id.isEmpty ? 'Guest session' : 'Signed in';
                      return Text(
                        label,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      );
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('User profile'),
              onTap: () async {
                Navigator.of(context).pop();
                await _openAccount();
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () async {
                Navigator.of(context).pop();
                await _openRemindersSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                _openSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.extension),
              title: const Text('Puzzle Game'),
              onTap: () async {
                Navigator.of(context).pop();
                await _openPuzzleGame();
              },
            ),
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Widget Guide'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WidgetGuideScreen()),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(appBarTitle),
        automaticallyImplyLeading: true,
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
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
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
        currentIndex: visibleNavIndex < 0 ? 0 : visibleNavIndex,
        onTap: (i) {
          final nextTab = visibleTabIndices[i];
          setState(() => _tabIndex = nextTab);
          _refreshReminders();
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).colorScheme.surface,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.book_outlined), label: 'Journal'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_awesome), label: 'Affirmations'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Insights'),
        ],
      ),
    );
  }
}

