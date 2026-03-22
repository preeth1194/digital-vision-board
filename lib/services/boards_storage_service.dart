import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/core_value.dart';
import '../models/grid_template.dart';
import '../models/grid_tile_model.dart';
import '../models/vision_board_info.dart';
import 'grid_tiles_storage_service.dart';

class BoardsStorageService {
  BoardsStorageService._();

  static const String boardsKey = 'vision_boards_list_v1';
  static const String activeBoardIdKey = 'active_vision_board_id_v1';

  static String boardComponentsKey(String boardId) => 'vision_board_${boardId}_components';
  static String boardBgColorKey(String boardId) => 'vision_board_${boardId}_bg_color';
  static String boardImagePathKey(String boardId) => 'vision_board_${boardId}_bg_image_path';
  // Logical canvas size for template-based boards (stored in template pixel space).
  static String boardCanvasWidthKey(String boardId) => 'vision_board_${boardId}_canvas_w';
  static String boardCanvasHeightKey(String boardId) => 'vision_board_${boardId}_canvas_h';
  static String boardGridTilesKey(String boardId) => 'vision_board_${boardId}_grid_tiles_v1';
  static String boardGridTilesV2Key(String boardId) => 'vision_board_${boardId}_grid_tiles_v2';
  static String boardGridCompactSpacingKey(String boardId) =>
      'vision_board_${boardId}_grid_compact_spacing_v1';
  static String boardGridStyleSeedKey(String boardId) => 'vision_board_${boardId}_grid_style_seed_v1';
  static String boardGridBorderRadiusKey(String boardId) => 'vision_board_${boardId}_grid_border_radius_v1';
  static String boardGridTileBgColorKey(String boardId) => 'vision_board_${boardId}_grid_tile_bg_color_v1';
  static String boardGridViewportSizedKey(String boardId) => 'vision_board_${boardId}_grid_viewport_sized_v1';

  static Future<List<VisionBoardInfo>> loadBoards({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(boardsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => VisionBoardInfo.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveBoards(
    List<VisionBoardInfo> boards, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      boardsKey,
      jsonEncode(boards.map((b) => b.toJson()).toList()),
    );
  }

  static Future<void> updateBoardTemplateId(
    String boardId,
    String? templateId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boards = await loadBoards(prefs: p);
    if (boards.isEmpty) return;
    final next = boards
        .map((b) => b.id == boardId ? b.copyWith(templateId: templateId) : b)
        .toList();
    await saveBoards(next, prefs: p);
  }

  static Future<String?> loadActiveBoardId({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getString(activeBoardIdKey);
  }

  static Future<void> setActiveBoardId(
    String boardId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(activeBoardIdKey, boardId);
  }

  static Future<void> clearActiveBoardId({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(activeBoardIdKey);
  }

  /// Ensures at most one vision board exists, creates a default grid board if none.
  ///
  /// If multiple boards are stored (legacy), keeps the active board when valid,
  /// otherwise the first; deletes prefs data for all others.
  static Future<VisionBoardInfo> ensureSingleBoard({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    var boards = await loadBoards(prefs: p);
    final activeRaw = (await loadActiveBoardId(prefs: p) ?? '').trim();

    if (boards.length > 1) {
      VisionBoardInfo? keep;
      if (activeRaw.isNotEmpty) {
        for (final b in boards) {
          if (b.id == activeRaw) {
            keep = b;
            break;
          }
        }
      }
      final kept = keep ?? boards.first;
      for (final b in boards) {
        if (b.id != kept.id) {
          await deleteBoardData(b.id, prefs: p);
        }
      }
      boards = [kept];
      await saveBoards(boards, prefs: p);
      await setActiveBoardId(kept.id, prefs: p);
    }

    if (boards.isEmpty) {
      final id = 'board_${DateTime.now().millisecondsSinceEpoch}';
      final tpl = GridTemplates.hero;
      final core = CoreValues.byId(CoreValues.growthMindset);
      final board = VisionBoardInfo(
        id: id,
        title: 'My vision',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        coreValueId: core.id,
        iconCodePoint: core.icon.codePoint,
        tileColorValue: core.tileColor.toARGB32(),
        layoutType: VisionBoardInfo.layoutGrid,
        templateId: tpl.id,
      );
      final tiles = <GridTileModel>[
        for (int i = 0; i < tpl.tiles.length; i++)
          GridTileModel(
            id: 'tile_$i',
            type: 'empty',
            content: null,
            isPlaceholder: true,
            crossAxisCellCount: tpl.tiles[i].crossAxisCount,
            mainAxisCellCount: tpl.tiles[i].mainAxisCount,
            index: i,
          ),
      ];
      await saveBoards([board], prefs: p);
      await setActiveBoardId(id, prefs: p);
      await GridTilesStorageService.saveTiles(id, tiles, prefs: p);
      return board;
    }

    final activeId = activeRaw.isNotEmpty ? activeRaw : boards.first.id;
    final match = boards.cast<VisionBoardInfo?>().firstWhere(
          (b) => b?.id == activeId,
          orElse: () => null,
        );
    final board = match ?? boards.first;
    if (board.id != activeId || activeRaw.isEmpty) {
      await setActiveBoardId(board.id, prefs: p);
    }
    return board;
  }

  static Future<void> deleteBoardData(
    String boardId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(boardComponentsKey(boardId));
    await p.remove(boardBgColorKey(boardId));
    await p.remove(boardImagePathKey(boardId));
    await p.remove(boardCanvasWidthKey(boardId));
    await p.remove(boardCanvasHeightKey(boardId));
    await p.remove(boardGridTilesKey(boardId));
    await p.remove(boardGridTilesV2Key(boardId));
    await p.remove(boardGridCompactSpacingKey(boardId));
    await p.remove(boardGridBorderRadiusKey(boardId));
    await p.remove(boardGridTileBgColorKey(boardId));
    await p.remove(boardGridViewportSizedKey(boardId));
  }
}

