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
      final tiles =
          decoded.map((e) => GridTileModel.fromJson(e as Map<String, dynamic>)).toList();
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
}

