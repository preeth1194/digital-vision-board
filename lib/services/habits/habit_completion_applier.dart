import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import 'boards_storage_service.dart';
import 'grid_tiles_storage_service.dart';
import 'logical_date_service.dart';
import 'sync_service.dart';
import 'vision_board_components_storage_service.dart';

/// Marks habits completed in storage + enqueues sync, without requiring UI.
///
/// Used by background geofence/timer completion while the app is alive.
final class HabitCompletionApplier {
  HabitCompletionApplier._();

  static Future<VisionBoardInfo?> _loadBoardInfo(
    String boardId, {
    required SharedPreferences prefs,
  }) async {
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    return boards.where((b) => b.id == boardId).cast<VisionBoardInfo?>().firstWhere((_) => true, orElse: () => null);
  }

  static bool _isEligibleToday(HabitItem habit) {
    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return false;
    if (habit.isCompletedForCurrentPeriod(now)) return false;
    return true;
  }

  /// Toggle completion for the current logical day and enqueue sync with the correct `deleted` flag.
  ///
  /// This is used by home-screen widget actions (deep links / intents).
  static Future<bool> toggleForToday({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDateIso,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: p);

    final info = await _loadBoardInfo(boardId, prefs: p);
    final layoutType = info?.layoutType;
    if (layoutType == null) return false;

    if (layoutType == VisionBoardInfo.layoutGrid) {
      return _toggleInGrid(
        boardId: boardId,
        componentId: componentId,
        habitId: habitId,
        logicalDateIso: logicalDateIso,
        prefs: p,
      );
    }

    return _toggleInComponents(
      boardId: boardId,
      componentId: componentId,
      habitId: habitId,
      logicalDateIso: logicalDateIso,
      prefs: p,
    );
  }

  static Future<bool> markCompleted({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDateIso,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await LogicalDateService.ensureInitialized(prefs: p);

    final info = await _loadBoardInfo(boardId, prefs: p);
    final layoutType = info?.layoutType;
    if (layoutType == null) return false;

    if (layoutType == VisionBoardInfo.layoutGrid) {
      return _markCompletedInGrid(
        boardId: boardId,
        componentId: componentId,
        habitId: habitId,
        logicalDateIso: logicalDateIso,
        prefs: p,
      );
    }

    return _markCompletedInComponents(
      boardId: boardId,
      componentId: componentId,
      habitId: habitId,
      logicalDateIso: logicalDateIso,
      prefs: p,
    );
  }

  static Future<bool> _markCompletedInComponents({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDateIso,
    required SharedPreferences prefs,
  }) async {
    final comps = await VisionBoardComponentsStorageService.loadComponents(boardId, prefs: prefs);
    final idx = comps.indexWhere((c) => c.id == componentId);
    if (idx == -1) return false;

    final component = comps[idx];
    final hIdx = component.habits.indexWhere((h) => h.id == habitId);
    if (hIdx == -1) return false;
    final habit = component.habits[hIdx];
    if (!_isEligibleToday(habit)) return false;

    final now = LogicalDateService.now();
    final updatedHabit = habit.toggleForDate(now);
    final nextHabits = component.habits.map((h) => h.id == habitId ? updatedHabit : h).toList();
    comps[idx] = component.copyWithCommon(habits: nextHabits);

    await VisionBoardComponentsStorageService.saveComponents(boardId, comps, prefs: prefs);

    await SyncService.enqueueHabitCompletion(
      boardId: boardId,
      componentId: componentId,
      habitId: habitId,
      logicalDate: logicalDateIso,
      deleted: false,
      prefs: prefs,
    );
    return true;
  }

  static Future<bool> _toggleInComponents({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDateIso,
    required SharedPreferences prefs,
  }) async {
    final comps = await VisionBoardComponentsStorageService.loadComponents(boardId, prefs: prefs);
    final idx = comps.indexWhere((c) => c.id == componentId);
    if (idx == -1) return false;

    final component = comps[idx];
    final hIdx = component.habits.indexWhere((h) => h.id == habitId);
    if (hIdx == -1) return false;
    final habit = component.habits[hIdx];

    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return false;
    final wasCompleted = habit.isCompletedForCurrentPeriod(now);

    final updatedHabit = habit.toggleForDate(now);
    final nextHabits = component.habits.map((h) => h.id == habitId ? updatedHabit : h).toList();
    comps[idx] = component.copyWithCommon(habits: nextHabits);

    await VisionBoardComponentsStorageService.saveComponents(boardId, comps, prefs: prefs);
    await SyncService.enqueueHabitCompletion(
      boardId: boardId,
      componentId: componentId,
      habitId: habitId,
      logicalDate: logicalDateIso,
      deleted: wasCompleted,
      prefs: prefs,
    );
    return true;
  }

  static Future<bool> _toggleInGrid({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDateIso,
    required SharedPreferences prefs,
  }) async {
    final tiles = await GridTilesStorageService.loadTiles(boardId, prefs: prefs);
    final idx = tiles.indexWhere((t) => t.id == componentId);
    if (idx == -1) return false;

    final tile = tiles[idx];
    final hIdx = tile.habits.indexWhere((h) => h.id == habitId);
    if (hIdx == -1) return false;
    final habit = tile.habits[hIdx];

    final now = LogicalDateService.now();
    if (!habit.isScheduledOnDate(now)) return false;
    final wasCompleted = habit.isCompletedForCurrentPeriod(now);

    final updatedHabit = habit.toggleForDate(now);
    final nextHabits = tile.habits.map((h) => h.id == habitId ? updatedHabit : h).toList();
    tiles[idx] = tile.copyWith(habits: nextHabits);

    await GridTilesStorageService.saveTiles(boardId, tiles, prefs: prefs);
    await SyncService.enqueueHabitCompletion(
      boardId: boardId,
      componentId: componentId,
      habitId: habitId,
      logicalDate: logicalDateIso,
      deleted: wasCompleted,
      prefs: prefs,
    );
    return true;
  }

  static Future<bool> _markCompletedInGrid({
    required String boardId,
    required String componentId,
    required String habitId,
    required String logicalDateIso,
    required SharedPreferences prefs,
  }) async {
    final tiles = await GridTilesStorageService.loadTiles(boardId, prefs: prefs);
    final idx = tiles.indexWhere((t) => t.id == componentId);
    if (idx == -1) return false;

    final tile = tiles[idx];
    final hIdx = tile.habits.indexWhere((h) => h.id == habitId);
    if (hIdx == -1) return false;
    final habit = tile.habits[hIdx];
    if (!_isEligibleToday(habit)) return false;

    final now = LogicalDateService.now();
    final updatedHabit = habit.toggleForDate(now);
    final nextHabits = tile.habits.map((h) => h.id == habitId ? updatedHabit : h).toList();
    tiles[idx] = tile.copyWith(habits: nextHabits);

    await GridTilesStorageService.saveTiles(boardId, tiles, prefs: prefs);

    await SyncService.enqueueHabitCompletion(
      boardId: boardId,
      componentId: componentId,
      habitId: habitId,
      logicalDate: logicalDateIso,
      deleted: false,
      prefs: prefs,
    );
    return true;
  }
}

