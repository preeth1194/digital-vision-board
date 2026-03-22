import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:digital_vision_board/models/core_value.dart';
import 'package:digital_vision_board/models/vision_board_info.dart';
import 'package:digital_vision_board/services/boards_storage_service.dart';
import 'package:digital_vision_board/services/grid_tiles_storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ensureSingleBoard', () {
    test('empty storage creates one grid board and sets active id', () async {
      final prefs = await SharedPreferences.getInstance();
      final board = await BoardsStorageService.ensureSingleBoard(prefs: prefs);

      expect(board.layoutType, VisionBoardInfo.layoutGrid);
      expect(board.title, 'My vision');

      final boards = await BoardsStorageService.loadBoards(prefs: prefs);
      expect(boards.length, 1);
      expect(boards.single.id, board.id);

      final active = await BoardsStorageService.loadActiveBoardId(prefs: prefs);
      expect(active, board.id);

      final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: prefs);
      expect(tiles.isNotEmpty, true);
    });

    test('multiple boards collapse to active when valid', () async {
      final prefs = await SharedPreferences.getInstance();
      final core = CoreValues.byId(CoreValues.growthMindset);
      final keep = VisionBoardInfo(
        id: 'keep_me',
        title: 'Keep',
        createdAtMs: 1,
        coreValueId: core.id,
        iconCodePoint: core.icon.codePoint,
        tileColorValue: core.tileColor.toARGB32(),
        layoutType: VisionBoardInfo.layoutGrid,
        templateId: 'the_hero',
      );
      final drop = VisionBoardInfo(
        id: 'drop_me',
        title: 'Drop',
        createdAtMs: 2,
        coreValueId: core.id,
        iconCodePoint: core.icon.codePoint,
        tileColorValue: core.tileColor.toARGB32(),
        layoutType: VisionBoardInfo.layoutGrid,
        templateId: 'the_hero',
      );

      await prefs.setString(
        BoardsStorageService.boardsKey,
        jsonEncode([keep, drop].map((b) => b.toJson()).toList()),
      );
      await BoardsStorageService.setActiveBoardId('keep_me', prefs: prefs);
      await GridTilesStorageService.saveTiles(
        'keep_me',
        [
          // minimal tile so load succeeds
        ],
        prefs: prefs,
      );

      final sole = await BoardsStorageService.ensureSingleBoard(prefs: prefs);
      expect(sole.id, 'keep_me');

      final boards = await BoardsStorageService.loadBoards(prefs: prefs);
      expect(boards.length, 1);
    });
  });
}
