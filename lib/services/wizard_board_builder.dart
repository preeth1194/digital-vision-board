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

  static List<String> _placeholderPhrases({
    required String coreValueId,
    required String category,
  }) {
    final cv = CoreValues.byId(coreValueId).id;
    final cat = category.trim().toLowerCase();
    // Lightweight, local phrases (no API cost). Pexels images can later replace these.
    final byCat = <String, List<String>>{
      'health': ['Energy', 'Strong body', 'Calm mind', 'Hydrate', 'Sleep'],
      'fitness': ['Consistency', '1% better', 'Show up', 'Discipline', 'Strength'],
      'mindfulness': ['Breathe', 'Present', 'Gratitude', 'Peace', 'Reset'],
      'confidence': ['I can', 'Bold', 'Self-belief', 'Own it', 'Courage'],
      'learning': ['Read', 'Practice', 'Curiosity', 'Skill up', 'Mastery'],
      'travel': ['Explore', 'Wander', 'New places', 'Adventure', 'Passport'],
      'home': ['Cozy', 'Declutter', 'Warm light', 'Minimal', 'Sanctuary'],
      'experiences': ['Moments', 'Joy', 'Try it', 'Memories', 'Fun'],
      'relationships': ['Trust', 'Kindness', 'Communication', 'Love', 'Connection'],
      'family': ['Together', 'Support', 'Quality time', 'Care', 'Home'],
      'friends': ['Community', 'Laugh', 'Belonging', 'Plans', 'Support'],
      'income': ['Abundance', 'Save', 'Invest', 'Grow', 'Freedom'],
      'promotion': ['Impact', 'Level up', 'Lead', 'Ownership', 'Results'],
      'skills': ['Deep work', 'Focus', 'Craft', 'Learn', 'Build'],
      'leadership': ['Clarity', 'Vision', 'Empathy', 'Decide', 'Inspire'],
      'art': ['Create', 'Color', 'Flow', 'Muse', 'Express'],
      'writing': ['Draft', 'Voice', 'Daily pages', 'Story', 'Publish'],
      'music': ['Rhythm', 'Practice', 'Listen', 'Perform', 'Compose'],
      'content': ['Post', 'Audience', 'Consistency', 'Create', 'Share'],
    };

    // Some categories may be custom; fall back to core-value themed words.
    final byCoreValue = <String, List<String>>{
      CoreValues.growthMindset: ['Growth', 'Mindset', 'Habits', 'Clarity', 'Resilience'],
      CoreValues.careerAmbition: ['Career', 'Impact', 'Goals', 'Momentum', 'Excellence'],
      CoreValues.creativityExpression: ['Create', 'Inspire', 'Express', 'Imagination', 'Craft'],
      CoreValues.lifestyleAdventure: ['Adventure', 'Lifestyle', 'Freedom', 'Explore', 'Live'],
      CoreValues.connectionCommunity: ['Connection', 'Community', 'Love', 'Belong', 'Support'],
    };

    final words = byCat[cat] ?? byCoreValue[cv] ?? const ['Dream', 'Focus', 'Progress', 'Today', 'You got this'];
    // Keep it short and deterministic-ish (stable order), but caller can rotate/shuffle later.
    return words;
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

    // Ensure at least 6 tiles so the board feels "full screen" even with few goals.
    final desiredTileCount = (goals.length < 6) ? 6 : goals.length;

    final tiles = <GridTileModel>[];
    for (int i = 0; i < desiredTileCount; i++) {
      final blueprint = (i < template.tiles.length)
          ? template.tiles[i]
          : const GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1);

      if (i >= goals.length) {
        // Placeholder tile.
        // Use the first goal's category when present; otherwise, fall back to major core value theme.
        final seedGoal = goals.isNotEmpty ? goals.first : null;
        final cat = (seedGoal?.category ?? '').trim();
        final phrases = _placeholderPhrases(coreValueId: seedGoal?.coreValueId ?? state.majorCoreValueId, category: cat);
        final phrase = phrases[(i - goals.length) % phrases.length];
        tiles.add(
          GridTileModel(
            id: 'tile_$i',
            type: 'text',
            content: phrase,
            isPlaceholder: true,
            crossAxisCellCount: blueprint.crossAxisCount,
            mainAxisCellCount: blueprint.mainAxisCount,
            index: i,
          ),
        );
        continue;
      }

      final g = goals[i];
      // Use default image URL if provided, otherwise null (user will pick images later)
      final defaultImageUrl = defaultImageUrlsByGoalId?[g.id];
      tiles.add(
        GridTileModel(
          id: 'tile_$i',
          type: 'image',
          content: defaultImageUrl, // default image URL if available, otherwise null
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

