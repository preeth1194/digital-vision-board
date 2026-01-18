import 'package:shared_preferences/shared_preferences.dart';

import '../models/core_value.dart';
import '../models/goal_metadata.dart';
import '../models/grid_tile_model.dart';
import '../models/vision_board_info.dart';
import '../models/wizard/wizard_state.dart';
import 'boards_storage_service.dart';
import 'grid_tiles_storage_service.dart';

final class WizardBoardBuildResult {
  final VisionBoardInfo board;
  final List<GridTileModel> tiles;

  const WizardBoardBuildResult({required this.board, required this.tiles});
}

final class WizardBoardBuilderService {
  WizardBoardBuilderService._();

  static WizardBoardBuildResult build({
    required String boardId,
    required CreateBoardWizardState state,
  }) {
    final core = CoreValues.byId(state.majorCoreValueId);

    final board = VisionBoardInfo(
      id: boardId,
      title: state.boardName.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      coreValueId: core.id,
      iconCodePoint: core.icon.codePoint,
      tileColorValue: core.tileColor.toARGB32(),
      layoutType: VisionBoardInfo.layoutGrid,
      templateId: null, // GridTemplates.byId(null) => hero (safe default)
    );

    // Group ordering: coreValue -> category -> goals (name)
    final goals = List.of(state.goals)
      ..sort((a, b) {
        final c = a.coreValueId.compareTo(b.coreValueId);
        if (c != 0) return c;
        final cat = a.category.compareTo(b.category);
        if (cat != 0) return cat;
        return a.name.compareTo(b.name);
      });

    final tiles = <GridTileModel>[];
    for (int i = 0; i < goals.length; i++) {
      final g = goals[i];
      tiles.add(
        GridTileModel(
          id: 'tile_$i',
          type: 'image',
          content: null, // user will pick images later
          crossAxisCellCount: 1,
          mainAxisCellCount: 1,
          index: i,
          goal: GoalMetadata(
            title: g.name,
            deadline: g.deadline,
            category: g.category,
            cbt: GoalCbtMetadata(coreValue: CoreValues.byId(g.coreValueId).label, visualization: g.whyImportant),
            actionPlan: g.wantsActionPlan ? const GoalActionPlan(frequency: 'Daily') : null,
          ),
          habits: g.wantsActionPlan ? g.habits : const [],
          tasks: g.wantsActionPlan ? g.tasks : const [],
        ),
      );
    }

    return WizardBoardBuildResult(board: board, tiles: tiles);
  }

  static Future<void> persist({
    required WizardBoardBuildResult result,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = await BoardsStorageService.loadBoards(prefs: p);
    await BoardsStorageService.saveBoards([result.board, ...existing], prefs: p);
    await BoardsStorageService.setActiveBoardId(result.board.id, prefs: p);
    await GridTilesStorageService.saveTiles(result.board.id, result.tiles, prefs: p);
  }
}

