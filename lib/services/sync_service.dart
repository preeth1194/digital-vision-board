import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import 'boards_storage_service.dart';
import 'grid_tiles_storage_service.dart';
import 'habit_progress_widget_snapshot_service.dart';
import 'logical_date_service.dart';
import 'vision_board_components_storage_service.dart';

/// Sync layer stub. Server push/bootstrap have been removed; user data is
/// now backed up via encrypted Google Drive archives. Only local pruning
/// and the authExpired notifier remain for backward compatibility.
final class SyncService {
  SyncService._();

  static const int localRetainDays = 30;

  static final ValueNotifier<bool> authExpired = ValueNotifier<bool>(false);

  /// No-op: server bootstrap has been removed.
  static Future<void> bootstrapIfNeeded({SharedPreferences? prefs}) async {}

  /// No-op: server push has been removed. Keeps the widget snapshot refresh
  /// for callers that record habit completions.
  static Future<void> enqueueHabitCompletion({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDate,
    int? rating,
    String? note,
    bool deleted = false,
    SharedPreferences? prefs,
  }) async {
    Future<void>(() async {
      await HabitProgressWidgetSnapshotService
          .refreshIfAffectedBoardBestEffort(boardId, prefs: prefs);
    });
  }

  /// No-op: server push has been removed.
  static Future<void> pushSnapshotsBestEffort({
    SharedPreferences? prefs,
    Duration minInterval = const Duration(hours: 12),
  }) async {}

  /// No-op: outbox has been removed.
  static Future<void> flush({SharedPreferences? prefs}) async {}

  /// Prune old habit feedback from local board storage (still useful).
  static Future<void> pruneLocalFeedback({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: p);
    final today = LogicalDateService.today();
    final cutoff = today.subtract(const Duration(days: localRetainDays - 1));
    final cutoffIso = LogicalDateService.toIsoDate(cutoff);

    final boards = await BoardsStorageService.loadBoards(prefs: p);
    for (final b in boards) {
      if (b.layoutType == VisionBoardInfo.layoutGrid) {
        final tiles = await GridTilesStorageService.loadTiles(b.id, prefs: p);
        final nextTiles = tiles.map((t) => _pruneTile(t, cutoffIso)).toList();
        await GridTilesStorageService.saveTiles(b.id, nextTiles, prefs: p);
      } else {
        final comps = await VisionBoardComponentsStorageService
            .loadComponents(b.id, prefs: p);
        final next = comps.map((c) => _pruneComponent(c, cutoffIso)).toList();
        await VisionBoardComponentsStorageService.saveComponents(
            b.id, next, prefs: p);
      }
    }
  }

  static VisionComponent _pruneComponent(
      VisionComponent c, String cutoffIso) {
    final habits = c.habits.map((h) {
      final nextFb = <String, HabitCompletionFeedback>{};
      for (final e in h.feedbackByDate.entries) {
        if (e.key.compareTo(cutoffIso) >= 0) nextFb[e.key] = e.value;
      }
      return h.copyWith(feedbackByDate: nextFb);
    }).toList();
    return c.copyWithCommon(habits: habits, tasks: const []);
  }

  static GridTileModel _pruneTile(GridTileModel t, String cutoffIso) {
    final habits = t.habits.map((h) {
      final nextFb = <String, HabitCompletionFeedback>{};
      for (final e in h.feedbackByDate.entries) {
        if (e.key.compareTo(cutoffIso) >= 0) nextFb[e.key] = e.value;
      }
      return h.copyWith(feedbackByDate: nextFb);
    }).toList();
    return t.copyWith(habits: habits, tasks: const []);
  }
}
