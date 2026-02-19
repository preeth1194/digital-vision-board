import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_service.dart';
import '../utils/app_typography.dart';
import '../utils/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/core_value.dart';
import '../models/vision_board_info.dart';
import '../models/grid_template.dart';
import '../services/boards_storage_service.dart';
import '../services/habit_storage_service.dart';
import '../services/coins_service.dart';
import '../widgets/dashboard/dashboard_body.dart';
import '../widgets/dialogs/confirm_dialog.dart';
import '../widgets/dialogs/new_board_dialog.dart';
import '../services/vision_board_components_storage_service.dart';
import '../services/reminder_summary_service.dart';
import '../services/dv_auth_service.dart';
import '../services/sync_service.dart';
import '../services/auto_sync_service.dart';
import '../services/google_drive_backup_service.dart';
import 'backup_restore_screen.dart';
import '../services/logical_date_service.dart';
import 'auth/auth_gateway_screen.dart';
import 'grid_editor.dart';
import 'wizard/create_board_wizard_screen.dart';
import 'goal_canvas_editor_screen.dart';
import 'goal_canvas_viewer_screen.dart';
import 'templates/template_gallery_screen.dart';
import 'journal/journal_notes_screen.dart';
import '../widgets/dialogs/home_screen_widget_instructions_sheet.dart';
import 'challenge_setup_screen.dart';
import 'vision_board_home_screen.dart';
import 'puzzle_game_screen.dart';
import '../services/puzzle_service.dart';
import '../services/widget_deeplink_service.dart';
import 'widget_guide_screen.dart';
import 'privacy_policy_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'earn_badges_screen.dart';
import 'subscription_screen.dart';
import '../services/subscription_service.dart';
import '../models/grid_tile_model.dart';
import '../models/habit_item.dart';
import '../models/routine.dart';
import '../models/vision_components.dart';
import '../services/grid_tiles_storage_service.dart';
import '../services/routine_storage_service.dart';
import '../models/challenge_template.dart';
import '../services/ad_service.dart';
import '../services/ad_free_service.dart';
import '../widgets/navigation/animated_bottom_nav_bar.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/rituals/add_habit_modal.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const String _addWidgetPromptShownKey = 'dv_add_widget_prompt_shown_v1';
  int _tabIndex = 1;
  bool _loading = true;
  SharedPreferences? _prefs;
  bool _checkedGuestExpiry = false;
  bool _checkedMandatoryLogin = false;

  late final AnimationController _createPanelController;
  bool _showCreatePanel = false;

  List<VisionBoardInfo> _boards = [];
  String? _activeBoardId;
  List<Routine> _routines = [];
  String? _activeRoutineId;

  bool _loadingReminders = false;
  ReminderSummary? _reminderSummary;
  Timer? _remindersAutoRefreshTimer;
  VoidCallback? _syncAuthListener;
  final ValueNotifier<int> _boardDataVersion = ValueNotifier<int>(0);

  // Coin state shared with the habits tab
  final ValueNotifier<int> _coinNotifier = ValueNotifier<int>(0);
  final GlobalKey _coinTargetKey = GlobalKey();

  // Profile avatar for app bar and drawer (refreshed when returning from Account)
  final ValueNotifier<({String? picPath, String initial, String displayName})>
      _profileAvatarNotifier =
          ValueNotifier((picPath: null, initial: '?', displayName: ''));

  @override
  void initState() {
    super.initState();
    _createPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addObserver(this);
    _init();
    _loadCoins();
    _startAutoRefreshReminders();
    _checkPuzzleDeepLink();
  }

  Future<void> _loadProfileAvatar() async {
    final displayName = await DvAuthService.getDisplayName(prefs: _prefs);
    final identifier = await DvAuthService.getUserDisplayIdentifier(prefs: _prefs);
    final picPath = await DvAuthService.getProfilePicPath(prefs: _prefs);
    final initial = (displayName != null && displayName.isNotEmpty)
        ? displayName[0].toUpperCase()
        : (identifier != null && identifier.isNotEmpty)
            ? identifier[0].toUpperCase()
            : '?';

    String resolvedName;
    if (displayName != null && displayName.isNotEmpty) {
      resolvedName = displayName;
    } else {
      resolvedName = 'Guest User';
    }

    if (mounted) {
      _profileAvatarNotifier.value = (
        picPath: picPath,
        initial: initial,
        displayName: resolvedName,
      );
    }
  }

  Future<void> _loadCoins() async {
    final coins = await CoinsService.getTotalCoins();
    _coinNotifier.value = coins;
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
    _createPanelController.dispose();
    _remindersAutoRefreshTimer?.cancel();
    if (_syncAuthListener != null) {
      SyncService.authExpired.removeListener(_syncAuthListener!);
    }
    _boardDataVersion.dispose();
    _coinNotifier.dispose();
    _profileAvatarNotifier.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshReminders();
      _loadCoins();
      _maybeShowAuthGatewayIfMandatoryAfterTenDays();
      unawaited(AutoSyncService.maybeSyncIfDue(prefs: _prefs));
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
    await HabitStorageService.migrateFromBoardsIfNeeded(prefs: _prefs);
    await SyncService.bootstrapIfNeeded(prefs: _prefs);
    await LogicalDateService.ensureInitialized(prefs: _prefs);
    await _reload();
    await _reloadRoutines();
    await SyncService.pruneLocalFeedback(prefs: _prefs);
    await SyncService.pushSnapshotsBestEffort(prefs: _prefs);
    await _refreshReminders();
    await _maybeShowAuthGatewayIfGuestExpired();
    await _maybeShowAuthGatewayIfMandatoryAfterTenDays();
    await _loadProfileAvatar();

    // Auto-sync: check if 24h backup is due
    unawaited(AutoSyncService.maybeSyncIfDue(prefs: _prefs));

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
    // DISABLED: 10-day mandatory login restriction is disabled for this build.
    return;
    // ignore: dead_code
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  Widget _buildCoinBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<int>(
      valueListenable: _coinNotifier,
      builder: (context, coins, _) {
        return GestureDetector(
          onTap: _openEarnBadges,
          behavior: HitTestBehavior.opaque,
          child: Row(
            key: _coinTargetKey,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.goldLight, AppColors.goldDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.amberBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.goldDark.withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.monetization_on_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Coin count
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.4),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  '$coins',
                  key: ValueKey(coins),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCircularIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        child: badgeCount > 0
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      icon,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 22,
                ),
              ),
      ),
    );
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
    await _loadProfileAvatar();
    if (res == true) {
      // Token refreshed (guest) or user logged in. Attempt bootstrap/sync/prune.
      await SyncService.bootstrapIfNeeded(prefs: _prefs);
      await LogicalDateService.reloadHomeTimezone(prefs: _prefs);
      await SyncService.pruneLocalFeedback(prefs: _prefs);
      await SyncService.pushSnapshotsBestEffort(prefs: _prefs);
      await _reload();
    }
  }

  Future<void> _signOut() async {
    await DvAuthService.signOut();
    try {
      await DvAuthService.continueAsGuest(prefs: _prefs);
    } catch (_) {}
    if (!mounted) return;
    await SyncService.bootstrapIfNeeded(prefs: _prefs);
    await LogicalDateService.reloadHomeTimezone(prefs: _prefs);
    await SyncService.pruneLocalFeedback(prefs: _prefs);
    await SyncService.pushSnapshotsBestEffort(prefs: _prefs);
    await _reload();
  }

  Future<void> _openEarnBadges() async {
    // Gather all habits from all boards (handles both freeform and grid layouts)
    final allHabits = <HabitItem>[];
    for (final board in _boards) {
      List<VisionComponent> components;
      if (board.layoutType == VisionBoardInfo.layoutGrid) {
        final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: _prefs);
        components = tiles
            .where((t) => t.type != 'empty')
            .map((t) => ImageComponent(
                  id: t.id,
                  position: Offset.zero,
                  size: const Size(1, 1),
                  rotation: 0,
                  scale: 1,
                  zIndex: t.index,
                  imagePath: (t.type == 'image') ? (t.content ?? '') : '',
                  goal: t.goal,
                  habits: t.habits,
                ))
            .toList();
      } else {
        components = await VisionBoardComponentsStorageService.loadComponents(
          board.id,
          prefs: _prefs,
        );
      }
      for (final comp in components) {
        allHabits.addAll(comp.habits);
      }
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EarnBadgesScreen(
          allHabits: allHabits,
          totalCoins: _coinNotifier.value,
          coinNotifier: _coinNotifier,
        ),
      ),
    );
  }

  Future<void> _openChallengeSetup() async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChallengeSetupScreen(
          template: ChallengeTemplates.seventyFiveHard,
        ),
      ),
    );
    if (mounted && res == true) {
      _boardDataVersion.value++;
    }
  }

  Future<void> _openPuzzleGame() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    
    var imagePath = await PuzzleService.getCurrentPuzzleImage(
      boards: _boards,
      prefs: prefs,
    );

    if (imagePath == null || imagePath.isEmpty) {
      if (!mounted) return;
      final cropped = await ImageService.pickAndCropPuzzleImage(
        context,
        source: ImageSource.gallery,
      );
      if (cropped == null || !mounted) return;
      await PuzzleService.setPuzzleImage(cropped, prefs: prefs);
      imagePath = cropped;
    }

    if (!mounted || imagePath == null) return;
    final resolvedPath = imagePath;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PuzzleGameScreen(
          imagePath: resolvedPath,
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

  void _toggleCreatePanel() {
    if (_showCreatePanel) {
      _createPanelController.reverse().then((_) {
        if (mounted) setState(() => _showCreatePanel = false);
      });
    } else {
      setState(() => _showCreatePanel = true);
      _createPanelController.forward(from: 0.0);
    }
  }

  void _hideCreatePanel() {
    if (!_showCreatePanel) return;
    _createPanelController.reverse().then((_) {
      if (mounted) setState(() => _showCreatePanel = false);
    });
  }

  Future<void> _addHabitFromPanel({bool timerEnabled = false}) async {
    _hideCreatePanel();

    final habits = await HabitStorageService.loadAll(prefs: _prefs);
    if (!mounted) return;

    // Gate: non-subscribed users with 3+ habits must watch ads on the Habits tab
    const freeLimit = 3;
    if (habits.length >= freeLimit) {
      final shouldShowAds = await AdFreeService.shouldShowAds(prefs: _prefs);
      if (shouldShowAds) {
        final session = await AdService.getActiveSession(prefs: _prefs);
        if (session != null) {
          final watched = await AdService.getWatchedCount(session, prefs: _prefs);
          if (watched >= AdService.requiredAdsPerHabit) {
            // Session complete — allow and fall through
          } else {
            if (!mounted) return;
            // Switch to Habits tab so user can see the ad card
            setState(() => _tabIndex = 7);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Watch ${AdService.requiredAdsPerHabit - watched} more ad(s) to unlock a new habit.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
        } else {
          // Create a new ad session and switch to Habits tab
          final sessionKey = 'habit_unlock_${DateTime.now().millisecondsSinceEpoch}';
          await AdService.setActiveSession(sessionKey, prefs: _prefs);
          if (!mounted) return;
          setState(() => _tabIndex = 7);
          _boardDataVersion.value++;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Watch 5 ads to unlock a new habit slot!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
    }

    final req = await showAddHabitModal(
      context,
      existingHabits: habits,
      initialTimerEnabled: timerEnabled,
    );
    if (req == null || !mounted) return;
    final newHabit = HabitItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: req.name,
      category: req.category,
      frequency: req.frequency,
      weeklyDays: req.weeklyDays,
      deadline: req.deadline,
      afterHabitId: req.afterHabitId,
      timeOfDay: req.timeOfDay,
      reminderMinutes: req.reminderMinutes,
      reminderEnabled: req.reminderEnabled,
      chaining: req.chaining,
      cbtEnhancements: req.cbtEnhancements,
      timeBound: req.timeBound,
      locationBound: req.locationBound,
      trackingSpec: req.trackingSpec,
      iconIndex: req.iconIndex,
      completedDates: const [],
      actionSteps: req.actionSteps,
      startTimeMinutes: req.startTimeMinutes,
    );
    await HabitStorageService.addHabit(newHabit, prefs: _prefs);
    _boardDataVersion.value++;
  }

  Future<void> _onTemplatePicked(String layoutType) async {
    _hideCreatePanel();
    final boardsBefore = _boards.length;

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
        builder: (_) => GoalCanvasEditorScreen(
              boardId: id,
              title: board.title,
            ),
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
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return switch (board.layoutType) {
            VisionBoardInfo.layoutGrid => GridEditorScreen(
                boardId: board.id,
                title: board.title,
                initialIsEditing: startInEditMode,
                template: gridTemplate,
              ),
            _ => startInEditMode
                ? GoalCanvasEditorScreen(boardId: board.id, title: board.title)
                : GoalCanvasViewerScreen(boardId: board.id, title: board.title),
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

    const visibleTabIndices = <int>[1, 7, 6, 2]; // Dashboard, Rituals, Routine, Journal
    final visibleNavIndex = visibleTabIndices.indexOf(_tabIndex);

    final body = DashboardBody(
      tabIndex: _tabIndex,
      boards: _boards,
      activeBoardId: _activeBoardId,
      routines: _routines,
      activeRoutineId: _activeRoutineId,
      prefs: _prefs,
      boardDataVersion: _boardDataVersion,
      coinNotifier: _coinNotifier,
      coinTargetKey: _coinTargetKey,
      onCreateBoard: _toggleCreatePanel,
      onOpenEditor: (b) => _openBoard(b, startInEditMode: true),
      onOpenViewer: (b) => _openBoard(b, startInEditMode: false),
      onDeleteBoard: _deleteBoard,
      onSwitchToRoutine: () => setState(() => _tabIndex = 6),
      onStartChallenge: _openChallengeSetup,
    );

    final scaffold = Scaffold(
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.65,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ValueListenableBuilder<({String? picPath, String initial, String displayName})>(
                valueListenable: _profileAvatarNotifier,
                builder: (context, profile, _) {
                  return FutureBuilder<String?>(
                    future: DvAuthService.getUserId(prefs: _prefs),
                    builder: (context, snap) {
                      final id = (snap.data ?? '').trim();
                      final isGuest = id.isEmpty;
                      final displayName = isGuest
                          ? 'Guest session'
                          : profile.displayName.isNotEmpty
                              ? profile.displayName
                              : 'Signed in';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProfileAvatar(
                            initial: profile.initial,
                            imagePath: profile.picPath,
                            radius: 38,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _openAccount();
                            },
                            child: Text(
                              isGuest ? 'Sign In / Sign Up' : 'View Profile',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: SubscriptionService.isSubscribed,
              builder: (context, subscribed, _) {
                return ListTile(
                  leading: Icon(
                    Icons.workspace_premium_rounded,
                    color: subscribed ? AppColors.coinGold : null,
                  ),
                  title: Text(subscribed ? 'Premium Active' : 'Go Premium'),
                  trailing: subscribed
                      ? Icon(Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.secondary, size: 20)
                      : null,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen()),
                    );
                  },
                );
              },
            ),
            ValueListenableBuilder<SyncState>(
              valueListenable: AutoSyncService.state,
              builder: (context, syncState, _) {
                return FutureBuilder<bool>(
                  future: GoogleDriveBackupService.isLinked(prefs: _prefs),
                  builder: (context, linkSnap) {
                    final linked = linkSnap.data ?? false;

                    if (!linked) {
                      return ListTile(
                        leading: Icon(Icons.cloud_off_outlined,
                            color: Theme.of(context).colorScheme.onSurfaceVariant),
                        title: const Text('Backup not set up'),
                        subtitle: const Text('Tap to link Google account'),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const BackupRestoreScreen()),
                          );
                        },
                      );
                    }

                    if (syncState == SyncState.syncing) {
                      return ListTile(
                        leading: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: const Text('Syncing...'),
                        subtitle: const Text('Encrypting and uploading'),
                      );
                    }

                    if (syncState == SyncState.error) {
                      return ListTile(
                        leading: Icon(Icons.cloud_off_outlined,
                            color: Theme.of(context).colorScheme.error),
                        title: const Text('Sync failed'),
                        subtitle: const Text('Tap sync to retry'),
                        trailing: IconButton(
                          icon: const Icon(Icons.sync),
                          onPressed: () =>
                              AutoSyncService.syncNow(prefs: _prefs),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const BackupRestoreScreen()),
                          );
                        },
                      );
                    }

                    return ListTile(
                      leading: Icon(Icons.cloud_done_outlined,
                          color: Theme.of(context).colorScheme.primary),
                      title: Text(AutoSyncService.lastSyncText),
                      subtitle: AutoSyncService.nextSyncText.isNotEmpty
                          ? Text(AutoSyncService.nextSyncText)
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.sync),
                        onPressed: () =>
                            AutoSyncService.syncNow(prefs: _prefs),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const BackupRestoreScreen()),
                        );
                      },
                    );
                  },
                );
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
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('App Tour'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(replayMode: true),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy Policy'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
            FutureBuilder<String?>(
              future: DvAuthService.getUserId(prefs: _prefs),
              builder: (context, snap) {
                final id = (snap.data ?? '').trim();
                if (id.isEmpty) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _signOut();
                  },
                );
              },
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habit Seeding',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Seed your new habits',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      // Hide app bar for routine screen (tabIndex == 6) since it has its own header
      appBar: (_tabIndex == 6 || _tabIndex == 2) ? null : AppBar(
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Avatar with menu
              Builder(
                builder: (scaffoldContext) => GestureDetector(
                  onTap: () => Scaffold.of(scaffoldContext).openDrawer(),
                  child: ValueListenableBuilder<({String? picPath, String initial, String displayName})>(
                    valueListenable: _profileAvatarNotifier,
                    builder: (context, profile, _) => ProfileAvatar(
                      initial: profile.initial,
                      imagePath: profile.picPath,
                      radius: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<({String? picPath, String initial, String displayName})>(
                  valueListenable: _profileAvatarNotifier,
                  builder: (context, profile, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        profile.displayName.isNotEmpty
                            ? profile.displayName
                            : 'Guest User',
                        style: AppTypography.heading3(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Coin badge
              _buildCoinBadge(context),
            ],
          ),
        ),
      ),
      body: body,
      bottomNavigationBar: const _NavBarSpacer(),
    );

    final navBar = AnimatedBottomNavBar(
      currentIndex: visibleNavIndex < 0 ? 0 : visibleNavIndex,
      suppressHighlight: _showCreatePanel,
      onTap: (i) {
        final nextTab = visibleTabIndices[i];
        if (_showCreatePanel) {
          _createPanelController.value = 0;
          setState(() {
            _showCreatePanel = false;
            _tabIndex = nextTab;
          });
        } else {
          setState(() => _tabIndex = nextTab);
        }
        _refreshReminders();
        _loadCoins();
      },
      onCenterTap: _toggleCreatePanel,
      items: const [
        AnimatedNavItem(
          icon: Icons.home_outlined,
          activeIcon: Icons.home_rounded,
          label: 'Home',
        ),
        AnimatedNavItem(
          icon: Icons.repeat_rounded,
          activeIcon: Icons.repeat_rounded,
          label: 'Habits',
        ),
        AnimatedNavItem(
          icon: Icons.schedule_outlined,
          activeIcon: Icons.schedule_rounded,
          label: 'Routine',
        ),
        AnimatedNavItem(
          icon: Icons.book_outlined,
          activeIcon: Icons.book_rounded,
          label: 'Journal',
        ),
      ],
    );

    return Stack(
      children: [
        scaffold,
        if (_showCreatePanel) _buildCreatePanelOverlay(),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: navBar,
        ),
      ],
    );
  }

  Widget _buildCreatePanelOverlay() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    const barHeight = 64.0;
    const circleOverflow = 20.0;
    final navTotalHeight = barHeight + circleOverflow + bottomPad;
    const panelContentHeight = 320.0;
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _createPanelController,
      builder: (context, _) {
        final t = CurvedAnimation(
          parent: _createPanelController,
          curve: Curves.easeOutCubic,
        ).value;

        return Stack(
          children: [
            // Scrim
            Positioned.fill(
              child: GestureDetector(
                onTap: _hideCreatePanel,
                child: Container(
                  color: Colors.black.withOpacity(0.35 * t),
                ),
              ),
            ),
            // Panel sliding up from behind the nav bar
            Positioned(
              left: 0,
              right: 0,
              bottom: navTotalHeight - circleOverflow,
              child: Transform.translate(
                offset: Offset(0, panelContentHeight * (1 - t)),
                child: Opacity(
                  opacity: t,
                  child: ClipPath(
                    clipper: _NotchedBottomClipper(
                      cutoutRadius: 34.0,
                      cutoutCenterOffset: 10.0,
                    ),
                    child: Material(
                      color: colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: SizedBox(
                        height: panelContentHeight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 16, bottom: 8),
                                child: Text(
                                  'Create New',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Card(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.self_improvement_outlined,
                                    color: colorScheme.primary,
                                  ),
                                  title: const Text('New Habit'),
                                  subtitle: const Text(
                                    'Build a daily practice',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _addHabitFromPanel(),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Card(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.schedule_outlined,
                                    color: colorScheme.primary,
                                  ),
                                  title: const Text('New Routine'),
                                  subtitle: const Text(
                                    'Habit with timer enabled',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => _addHabitFromPanel(timerEnabled: true),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Card(
                                child: ListTile(
                                  leading: Icon(
                                    Icons.military_tech_rounded,
                                    color: colorScheme.primary,
                                  ),
                                  title: const Text('75 Hard Challenge'),
                                  subtitle: const Text(
                                    '75-day mental toughness program',
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    _hideCreatePanel();
                                    _openChallengeSetup();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NavBarSpacer extends StatelessWidget {
  const _NavBarSpacer();

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return SizedBox(height: 64.0 + 20.0 + bottomPad);
  }
}

class _NotchedBottomClipper extends CustomClipper<Path> {
  final double cutoutRadius;
  final double cutoutCenterOffset;

  _NotchedBottomClipper({
    required this.cutoutRadius,
    required this.cutoutCenterOffset,
  });

  @override
  Path getClip(Size size) {
    final rect = Path()
      ..addRRect(RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.width, size.height),
        topLeft: const Radius.circular(20),
        topRight: const Radius.circular(20),
      ));

    final cutout = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height + cutoutCenterOffset),
        radius: cutoutRadius,
      ));

    return Path.combine(PathOperation.difference, rect, cutout);
  }

  @override
  bool shouldReclip(_NotchedBottomClipper oldClipper) =>
      cutoutRadius != oldClipper.cutoutRadius ||
      cutoutCenterOffset != oldClipper.cutoutCenterOffset;
}
