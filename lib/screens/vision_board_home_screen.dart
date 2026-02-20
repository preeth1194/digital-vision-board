import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_board_info.dart';
import '../services/boards_storage_service.dart';
import '../services/dv_auth_service.dart';
import '../widgets/flip/flip_card.dart';
import 'auth/auth_gateway_screen.dart';
import 'dashboard_screen.dart';
import 'vision_board_home_widgets.dart';

/// Landing screen:
/// - If no boards exist => show Dashboard
/// - If boards exist => show a flip-card view for the default (active) board
class VisionBoardHomeScreen extends StatefulWidget {
  const VisionBoardHomeScreen({super.key});

  @override
  State<VisionBoardHomeScreen> createState() => _VisionBoardHomeScreenState();
}

class _VisionBoardHomeScreenState extends State<VisionBoardHomeScreen> {
  bool _loading = true;
  SharedPreferences? _prefs;
  List<VisionBoardInfo> _boards = const [];
  String? _activeBoardId;
  int _refreshNonce = 0;
  bool _checkedMandatoryLogin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await DvAuthService.ensureFirstInstallRecorded(prefs: prefs);
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    final activeId = await BoardsStorageService.loadActiveBoardId(prefs: prefs);
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _boards = boards;
      _activeBoardId = activeId;
      _loading = false;
    });
    await _maybeShowAuthGatewayIfMandatoryAfterTenDays();
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

  VisionBoardInfo? _activeBoard() {
    if (_boards.isEmpty) return null;
    final activeId = (_activeBoardId ?? '').trim();
    final found = _boards.cast<VisionBoardInfo?>().firstWhere(
          (b) => b?.id == activeId,
          orElse: () => null,
        );
    return found ?? _boards.first;
  }

  Future<void> _pickDefaultBoard() async {
    if (_boards.length < 2) return;
    final picked = await showBoardPickerSheet(context, boards: _boards, activeBoardId: _activeBoardId);
    if (picked == null) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    await BoardsStorageService.setActiveBoardId(picked.id, prefs: prefs);
    if (!mounted) return;
    setState(() => _activeBoardId = picked.id);
  }

  Future<void> _openDashboard() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
    await _load();
    if (!mounted) return;
    // Force the flip-card children to remount so they re-load tiles/components
    // and reflect completions made in Dashboard / other screens.
    setState(() => _refreshNonce++);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_boards.isEmpty) {
      return const DashboardScreen();
    }

    final board = _activeBoard();
    if (board == null) return const DashboardScreen();

    return Scaffold(
        appBar: AppBar(
          title: Text(board.title),
          actions: [
            if (_boards.length > 1)
              IconButton(
                tooltip: 'Change default board',
                icon: const Icon(Icons.swap_horiz),
                onPressed: _pickDefaultBoard,
              ),
            IconButton(
              tooltip: 'Dashboard',
              icon: const Icon(Icons.dashboard_outlined),
              onPressed: _openDashboard,
            ),
          ],
        ),
        body: FlipCard(
          key: ValueKey('flip-${board.id}-$_refreshNonce'),
          front: VisionBoardHomeFront(key: ValueKey('front-${board.id}-$_refreshNonce'), board: board),
          back: VisionBoardHomeBack(key: ValueKey('back-${board.id}-$_refreshNonce'), board: board),
        ),
      );
  }
}

