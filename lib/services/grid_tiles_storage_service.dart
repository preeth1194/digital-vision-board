import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import 'boards_storage_service.dart';

class GridTilesStorageService {
  GridTilesStorageService._();

  // v2 stores fixed template-based grid contents.
  static String gridTilesKey(String boardId) => BoardsStorageService.boardGridTilesV2Key(boardId);

  static List<GridTileModel> sortTiles(List<GridTileModel> tiles) {
    final next = List<GridTileModel>.from(tiles)
      ..sort((a, b) => a.index.compareTo(b.index));
    return next;
  }

  static Future<List<GridTileModel>> loadTiles(
    String boardId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    String? raw = p.getString(gridTilesKey(boardId));
    // Lightweight migration from v1 -> v2.
    raw ??= p.getString(BoardsStorageService.boardGridTilesKey(boardId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final tiles = decoded
          .whereType<Map<String, dynamic>>()
          .map((e) => GridTileModel.fromJson(_migrateTasksToGoalTodosInTileJson(e)))
          .toList();
      return sortTiles(tiles);
    } catch (_) {
      return [];
    }
  }

  static Future<List<GridTileModel>> saveTiles(
    String boardId,
    List<GridTileModel> tiles, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final normalized = sortTiles(tiles);
    await p.setString(
      gridTilesKey(boardId),
      jsonEncode(normalized.map((t) => t.toJson()).toList()),
    );
    return normalized;
  }

  /// Load-time migration:
  /// - Converts legacy per-tile `tasks` (and their checklist items) into goal `todo_items` text entries.
  /// - Drops CBT/feedback implicitly by not carrying those fields forward.
  /// - If a tile has tasks but no `goal`, we drop tasks (per spec).
  static Map<String, dynamic> _migrateTasksToGoalTodosInTileJson(Map<String, dynamic> json) {
    final tasksRaw = json['tasks'];
    if (tasksRaw is! List) return json;

    final goalRaw = json['goal'];
    if (goalRaw is! Map<String, dynamic>) {
      // No goal metadata to store todo items -> drop tasks.
      final next = Map<String, dynamic>.from(json);
      next.remove('tasks');
      return next;
    }

    final goal = Map<String, dynamic>.from(goalRaw);

    final existingTodoItems = <Map<String, dynamic>>[];
    final todo1 = goal['todo_items'];
    final todo2 = goal['todoItems'];
    if (todo1 is List) {
      existingTodoItems.addAll(todo1.whereType<Map<String, dynamic>>());
    }
    if (todo2 is List) {
      existingTodoItems.addAll(todo2.whereType<Map<String, dynamic>>());
    }

    final existingIds = existingTodoItems
        .map((t) => (t['id'] as String?) ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toSet();

    final migrated = <Map<String, dynamic>>[];
    for (int i = 0; i < tasksRaw.length; i++) {
      final t = tasksRaw[i];
      if (t is! Map<String, dynamic>) continue;
      final taskId = ((t['id'] as String?) ?? 'idx_$i').trim();
      final title = ((t['title'] as String?) ?? '').trim();
      if (title.isNotEmpty) {
        final id = 'todo_task_$taskId';
        if (!existingIds.contains(id)) {
          migrated.add({
            'id': id,
            'text': title,
            'is_completed': false,
            'completed_at_ms': null,
            'habit_id': null,
            'task_id': null,
          });
          existingIds.add(id);
        }
      }

      final checklistRaw = t['checklist'];
      if (checklistRaw is List) {
        for (int j = 0; j < checklistRaw.length; j++) {
          final ci = checklistRaw[j];
          if (ci is! Map<String, dynamic>) continue;
          final itemId = ((ci['id'] as String?) ?? 'idx_$j').trim();
          final text = ((ci['text'] as String?) ?? '').trim();
          if (text.isEmpty) continue;
          final id = 'todo_check_${taskId}_$itemId';
          if (existingIds.contains(id)) continue;
          migrated.add({
            'id': id,
            'text': text,
            'is_completed': false,
            'completed_at_ms': null,
            'habit_id': null,
            'task_id': null,
          });
          existingIds.add(id);
        }
      }
    }

    if (migrated.isNotEmpty) {
      goal['todo_items'] = [...existingTodoItems, ...migrated];
      goal.remove('todoItems');
    } else if (existingTodoItems.isNotEmpty) {
      // Normalize key name even if no migrated items.
      goal['todo_items'] = existingTodoItems;
      goal.remove('todoItems');
    }

    final next = Map<String, dynamic>.from(json);
    next['goal'] = goal;
    next.remove('tasks');
    return next;
  }
}

