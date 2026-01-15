import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';

class GridTilesStorageService {
  GridTilesStorageService._();

  static String gridTilesKey(String boardId) => 'vision_board_${boardId}_grid_tiles_v1';

  static List<GridTileModel> sortTiles(List<GridTileModel> tiles) {
    final next = List<GridTileModel>.from(tiles)
      ..sort((a, b) => a.index.compareTo(b.index));
    return next;
  }

  static List<GridTileModel> normalizeIndices(List<GridTileModel> tiles) {
    final sorted = sortTiles(tiles);
    return List<GridTileModel>.generate(
      sorted.length,
      (i) => sorted[i].index == i ? sorted[i] : sorted[i].copyWith(index: i),
    );
  }

  static Future<List<GridTileModel>> loadTiles(
    String boardId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(gridTilesKey(boardId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final tiles =
          decoded.map((e) => GridTileModel.fromJson(e as Map<String, dynamic>)).toList();
      return normalizeIndices(tiles);
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
    final normalized = normalizeIndices(tiles);
    await p.setString(
      gridTilesKey(boardId),
      jsonEncode(normalized.map((t) => t.toJson()).toList()),
    );
    return normalized;
  }
}

