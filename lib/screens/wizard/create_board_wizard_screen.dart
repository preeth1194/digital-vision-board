import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/grid_template.dart';
import '../../models/grid_tile_model.dart';
import '../../models/goal_metadata.dart';
import '../../services/grid_tiles_storage_service.dart';
import '../../services/image_persistence.dart';
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

      // Fire-and-forget: fetch a Pexels image in the background so the
      // editor opens instantly instead of blocking on a slow backend.
      _preloadHeroImage(createdId, prefs);

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

  /// Downloads a Pexels image and persists it to the hero tile.
  /// Context-free so it can safely run after navigation.
  static Future<void> _preloadHeroImage(String boardId, SharedPreferences prefs) async {
    try {
      final urls = await StockImagesService.searchPexelsUrls(
        query: 'vision board inspiration goals',
        perPage: 5,
      );
      debugPrint('[CreateBoardWizard] Pexels returned ${urls.length} URLs');
      if (urls.isEmpty) return;

      final imageUrl = urls.first;
      debugPrint('[CreateBoardWizard] Downloading: $imageUrl');

      final res = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 30));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[CreateBoardWizard] Download failed: HTTP ${res.statusCode}');
        return;
      }

      final bytes = Uint8List.fromList(res.bodyBytes);
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('[CreateBoardWizard] Could not decode image');
        return;
      }

      final maxSide = decoded.width > decoded.height ? decoded.width : decoded.height;
      const targetMax = 2048;
      final out = maxSide > targetMax
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? targetMax : null,
              height: decoded.height > decoded.width ? targetMax : null,
              interpolation: img.Interpolation.cubic,
            )
          : decoded;

      final jpg = img.encodeJpg(out, quality: 90);
      final savedPath = await persistImageBytesToAppStorage(jpg, extension: 'jpg');
      debugPrint('[CreateBoardWizard] savedPath: $savedPath');
      if (savedPath == null || savedPath.trim().isEmpty) return;

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
      debugPrint('[CreateBoardWizard] Hero tile updated successfully');
    } catch (e, st) {
      debugPrint('[CreateBoardWizard] _preloadHeroImage failed: $e\n$st');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
