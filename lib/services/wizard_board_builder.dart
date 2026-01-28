import 'package:shared_preferences/shared_preferences.dart';

import '../models/core_value.dart';
import '../models/goal_metadata.dart';
import '../models/grid_template.dart';
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

  static GridTemplate _chooseTemplateFor(int goalCount) {
    if (goalCount <= 1) return GridTemplates.travelCollage; // 4x2 hero tile for focus
    if (goalCount <= 3) return GridTemplates.masonryMix;
    if (goalCount <= 6) return GridTemplates.hero;
    return GridTemplates.simpleGrid;
  }

  static WizardBoardBuildResult build({
    required String boardId,
    required CreateBoardWizardState state,
    Map<String, String>? defaultImageUrlsByGoalId,
  }) {
    final core = CoreValues.byId(state.majorCoreValueId);

    // Group ordering: coreValue -> category -> goals (name)
    final goals = List.of(state.goals)
      ..sort((a, b) {
        final c = a.coreValueId.compareTo(b.coreValueId);
        if (c != 0) return c;
        final cat = a.category.compareTo(b.category);
        if (cat != 0) return cat;
        return a.name.compareTo(b.name);
      });

    final template = _chooseTemplateFor(goals.length);
    final blueprints = GridTemplates.optimalSizesForTileCount(goals.length);

    final board = VisionBoardInfo(
      id: boardId,
      title: state.boardName.trim(),
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
      coreValueId: core.id,
      iconCodePoint: core.icon.codePoint,
      tileColorValue: core.tileColor.toARGB32(),
      layoutType: VisionBoardInfo.layoutGrid,
      templateId: template.id,
    );

    // One tile per goal; no extra placeholder tiles. Sizes fill viewport by goal count.
    final desiredTileCount = goals.length;

    final tiles = <GridTileModel>[];
    for (int i = 0; i < desiredTileCount; i++) {
      final blueprint = (i < blueprints.length)
          ? blueprints[i]
          : const GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1);

      final g = goals[i];
      // Use default image URL if provided, otherwise use goal name as text content
      final defaultImageUrl = defaultImageUrlsByGoalId?[g.id];
      final hasImage = defaultImageUrl != null && defaultImageUrl.trim().isNotEmpty;
      
      tiles.add(
        GridTileModel(
          id: 'tile_$i',
          type: hasImage ? 'image' : 'text',
          content: hasImage ? defaultImageUrl : g.name, // image URL or goal name as text
          isPlaceholder: false,
          crossAxisCellCount: blueprint.crossAxisCount,
          mainAxisCellCount: blueprint.mainAxisCount,
          index: i,
          goal: GoalMetadata(
            title: g.name,
            deadline: g.deadline,
            category: g.category,
            cbt: GoalCbtMetadata(coreValue: CoreValues.byId(g.coreValueId).label, visualization: g.whyImportant),
            actionPlan: g.wantsActionPlan ? const GoalActionPlan(frequency: 'Daily') : null,
            todoItems: g.todoItems,
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

