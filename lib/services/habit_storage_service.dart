import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import 'boards_storage_service.dart';
import 'grid_tiles_storage_service.dart';
import 'vision_board_components_storage_service.dart';

/// Standalone habit storage — the single source of truth for all habits.
///
/// Habits are stored in a flat list under [_key] in SharedPreferences.
/// Each habit may optionally reference a board and component via
/// [HabitItem.boardId] / [HabitItem.componentId].
class HabitStorageService {
  HabitStorageService._();

  static const String _key = 'dv_habits_v1';
  static const String _migratedKey = 'dv_habits_migrated_v1';

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  static Future<List<HabitItem>> loadAll({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(HabitItem.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(
    List<HabitItem> habits, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode(habits.map((h) => h.toJson()).toList()),
    );
  }

  static Future<HabitItem> addHabit(
    HabitItem habit, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    all.add(habit);
    await saveAll(all, prefs: p);
    return habit;
  }

  static Future<void> updateHabit(
    HabitItem habit, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    final idx = all.indexWhere((h) => h.id == habit.id);
    if (idx != -1) {
      all[idx] = habit;
    } else {
      all.add(habit);
    }
    await saveAll(all, prefs: p);
  }

  static Future<void> deleteHabit(
    String id, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    all.removeWhere((h) => h.id == id);
    await saveAll(all, prefs: p);
  }

  // ---------------------------------------------------------------------------
  // Lookup helpers
  // ---------------------------------------------------------------------------

  static Future<List<HabitItem>> getHabitsByIds(
    List<String> ids, {
    SharedPreferences? prefs,
  }) async {
    if (ids.isEmpty) return [];
    final all = await loadAll(prefs: prefs);
    final idSet = ids.toSet();
    return all.where((h) => idSet.contains(h.id)).toList();
  }

  static Future<List<HabitItem>> getHabitsForComponent(
    String componentId, {
    SharedPreferences? prefs,
  }) async {
    final all = await loadAll(prefs: prefs);
    return all.where((h) => h.componentId == componentId).toList();
  }

  static Future<List<HabitItem>> getHabitsForBoard(
    String boardId, {
    SharedPreferences? prefs,
  }) async {
    final all = await loadAll(prefs: prefs);
    return all.where((h) => h.boardId == boardId).toList();
  }

  /// Syncs habits from updated components to standalone storage.
  /// - [boardId]: the board these components belong to (grid or canvas).
  /// - [updatedComponents]: components with their current .habits.
  /// - [previousHabitIdsByComponentId]: optional map componentId -> set of habit ids
  ///   that were on that component before; any such id not in the component's current
  ///   habits will be deleted from storage.
  static Future<void> syncComponentsHabits(
    String boardId,
    List<VisionComponent> updatedComponents,
    Map<String, Set<String>>? previousHabitIdsByComponentId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    for (final c in updatedComponents) {
      final prevIds = previousHabitIdsByComponentId?[c.id] ?? <String>{};
      final newIds = c.habits.map((h) => h.id).toSet();
      for (final id in prevIds) {
        if (!newIds.contains(id)) await deleteHabit(id, prefs: p);
      }
      for (final h in c.habits) {
        await updateHabit(h.copyWith(boardId: boardId, componentId: c.id), prefs: p);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Migration
  // ---------------------------------------------------------------------------

  /// One-time migration: extract habits from all boards into standalone storage.
  ///
  /// Safe to call multiple times — skips if already migrated.
  static Future<void> migrateFromBoardsIfNeeded({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    if (p.getBool(_migratedKey) == true) return;

    final boards = await BoardsStorageService.loadBoards(prefs: p);
    final List<HabitItem> all = [];
    final seenIds = <String>{};

    for (final board in boards) {
      if (board.layoutType == VisionBoardInfo.layoutGrid) {
        final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: p);
        for (final tile in tiles) {
          for (final habit in tile.habits) {
            if (seenIds.contains(habit.id)) continue;
            seenIds.add(habit.id);
            all.add(habit.copyWith(
              boardId: board.id,
              componentId: tile.id,
            ));
          }
        }
      } else {
        final components = await VisionBoardComponentsStorageService
            .loadComponents(board.id, prefs: p);
        for (final comp in components) {
          for (final habit in comp.habits) {
            if (seenIds.contains(habit.id)) continue;
            seenIds.add(habit.id);
            all.add(habit.copyWith(
              boardId: board.id,
              componentId: comp.id,
            ));
          }
        }
      }
    }

    if (all.isNotEmpty) {
      await saveAll(all, prefs: p);
    }
    await p.setBool(_migratedKey, true);
  }
}
