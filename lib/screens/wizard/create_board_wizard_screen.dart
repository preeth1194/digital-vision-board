import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/grid_template.dart';
import '../../models/grid_tile_model.dart';
import '../../models/goal_metadata.dart';
import '../../services/grid_tiles_storage_service.dart';
import '../../services/image_service.dart';
import '../../services/stock_images_service.dart';
import '../../services/wizard_board_builder.dart';
import '../grid_editor.dart';

/// Creates a board with one large "Vision Board" tile pre-loaded with a Pexels
/// image, then opens the grid editor.
class CreateBoardWizardScreen extends StatefulWidget {
  const CreateBoardWizardScreen({super.key});

  @override
  State<CreateBoardWizardScreen> createState() => _CreateBoardWizardScreenState();
}

class _CreateBoardWizardScreenState extends State<CreateBoardWizardScreen> {
  bool _launched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_launched) {
      _launched = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _createAndOpen());
    }
  }

  static const _singleTileTemplate = GridTemplate(
    id: 'single_hero',
    name: 'Single Hero',
    tiles: [
      GridTileBlueprint(crossAxisCount: 4, mainAxisCount: 3),
    ],
  );

  Future<void> _createAndOpen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final createdId = 'board_${DateTime.now().millisecondsSinceEpoch}';

      final result = WizardBoardBuilderService.buildEmpty(
        boardId: createdId,
        template: _singleTileTemplate,
      );
      await WizardBoardBuilderService.persist(result: result, prefs: prefs);

      // Best-effort: fetch a Pexels image for the hero tile.
      if (mounted) {
        await _preloadHeroImage(createdId, prefs);
      }

      if (!mounted) return;
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => GridEditorScreen(
            boardId: createdId,
            title: result.board.title,
            initialIsEditing: true,
            template: _singleTileTemplate,
            isNewBoard: true,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(done == true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create board: ${e.toString()}')),
      );
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _preloadHeroImage(String boardId, SharedPreferences prefs) async {
    try {
      final urls = await StockImagesService.searchPexelsUrls(
        query: 'vision board inspiration goals',
        perPage: 5,
      );
      if (urls.isEmpty || !mounted) return;

      final imageUrl = urls.first;
      final savedPath = await ImageService.downloadResizeAndPersistJpegFromUrl(
        context,
        url: imageUrl,
        maxSidePx: 2048,
        jpegQuality: 90,
      );
      if (savedPath == null || savedPath.trim().isEmpty || !mounted) return;

      final tiles = await GridTilesStorageService.loadTiles(boardId, prefs: prefs);
      if (tiles.isEmpty) return;

      final heroTile = tiles.first;
      final updated = tiles.map((t) {
        if (t.id == heroTile.id) {
          return t.copyWith(
            type: 'image',
            content: savedPath.trim(),
            isPlaceholder: false,
            goal: const GoalMetadata(title: 'Vision Board'),
          );
        }
        return t;
      }).toList();
      await GridTilesStorageService.saveTiles(boardId, updated, prefs: prefs);
    } catch (_) {
      // Non-fatal: board still works without the pre-loaded image.
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
