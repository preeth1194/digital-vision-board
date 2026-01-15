import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_board_info.dart';

class BoardsStorageService {
  BoardsStorageService._();

  static const String boardsKey = 'vision_boards_list_v1';
  static const String activeBoardIdKey = 'active_vision_board_id_v1';

  static String boardComponentsKey(String boardId) => 'vision_board_${boardId}_components';
  static String boardBgColorKey(String boardId) => 'vision_board_${boardId}_bg_color';
  static String boardImagePathKey(String boardId) => 'vision_board_${boardId}_bg_image_path';
  static String boardGridTilesKey(String boardId) => 'vision_board_${boardId}_grid_tiles_v1';
  static String boardGridTilesV2Key(String boardId) => 'vision_board_${boardId}_grid_tiles_v2';
  static String boardGridCompactSpacingKey(String boardId) =>
      'vision_board_${boardId}_grid_compact_spacing_v1';

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

  static Future<void> deleteBoardData(
    String boardId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(boardComponentsKey(boardId));
    await p.remove(boardBgColorKey(boardId));
    await p.remove(boardImagePathKey(boardId));
    await p.remove(boardGridTilesKey(boardId));
    await p.remove(boardGridTilesV2Key(boardId));
    await p.remove(boardGridCompactSpacingKey(boardId));
  }
}

