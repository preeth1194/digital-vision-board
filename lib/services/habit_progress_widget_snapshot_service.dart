import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_board_info.dart';
import '../services/boards_storage_service.dart';
import '../services/habit_progress_widget_native_bridge.dart';
import '../services/habit_storage_service.dart';
import '../services/habit_timer_state_service.dart';
import '../services/logical_date_service.dart';

/// Builds and stores a compact JSON snapshot for the native home-screen widgets.
///
/// Data source:
/// - "default/active" board (falls back to first board if active id is missing)
/// - today's eligible habits
/// - excludes any habit with a time target (timer-based or location-bound dwell/arrival)
final class HabitProgressWidgetSnapshotService {
  HabitProgressWidgetSnapshotService._();

  static const String snapshotPrefsKey = 'habit_progress_widget_snapshot_v1';

  static Future<void> refreshBestEffort({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    try {
      await LogicalDateService.ensureInitialized(prefs: p);
      final json = await _buildSnapshotJson(prefs: p);
      if (json == null) return;
      await p.setString(snapshotPrefsKey, json);
      // iOS widgets can't read FlutterSharedPreferences; mirror into App Group (best-effort).
      await HabitProgressWidgetNativeBridge.writeSnapshotToAppGroupBestEffort(json);
      await HabitProgressWidgetNativeBridge.updateWidgetsBestEffort();
    } catch (_) {
      // Best-effort: ignore errors (widgets are optional).
    }
  }

  /// Only refresh if [affectedBoardId] matches the active board id (or the implicit default board when active is unset).
  static Future<void> refreshIfAffectedBoardBestEffort(
    String affectedBoardId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    try {
      final active = await _loadActiveBoard(prefs: p);
      if (active == null) return;
      if (active.id != affectedBoardId) return;
      await refreshBestEffort(prefs: p);
    } catch (_) {
      // ignore
    }
  }

  static Future<VisionBoardInfo?> _loadActiveBoard({required SharedPreferences prefs}) async {
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    if (boards.isEmpty) return null;
    final activeId = (await BoardsStorageService.loadActiveBoardId(prefs: prefs) ?? '').trim();
    if (activeId.isEmpty) return boards.first;
    return boards.cast<VisionBoardInfo?>().firstWhere((b) => b?.id == activeId, orElse: () => null) ?? boards.first;
  }

  static Future<String?> _buildSnapshotJson({required SharedPreferences prefs}) async {
    final board = await _loadActiveBoard(prefs: prefs);
    if (board == null) return null;

    final now = LogicalDateService.now();
    final iso = LogicalDateService.toIsoDate(now);

    final pending = <Map<String, dynamic>>[];
    int eligibleTotal = 0;

    final allHabits = await HabitStorageService.loadAll(prefs: prefs);
    final boardHabits = allHabits.where((h) => h.boardId == board.id).toList();

    for (final h in boardHabits) {
      if (!h.isScheduledOnDate(now)) continue;
      if (HabitTimerStateService.targetMsForHabit(h) > 0) continue;
      eligibleTotal++;
      if (!h.isCompletedForCurrentPeriod(now)) {
        pending.add({
          'componentId': h.componentId,
          'habitId': h.id,
          'name': h.name,
        });
      }
    }

    final top3 = pending.take(3).toList();
    final allDone = eligibleTotal > 0 && pending.isEmpty;

    final snap = <String, dynamic>{
      'v': 1,
      'generatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'isoDate': iso,
      'boardId': board.id,
      'boardTitle': board.title,
      'eligibleTotal': eligibleTotal,
      'pendingTotal': pending.length,
      'pending': top3,
      'allDone': allDone,
    };

    return jsonEncode(snap);
  }
}

