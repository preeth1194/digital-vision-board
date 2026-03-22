import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import 'boards_storage_service.dart';
import 'grid_tiles_storage_service.dart';
import 'habit_storage_service.dart';
import 'image_persistence.dart';

/// Links the onboarding habit to the sole vision board and optional motivation images.
class OnboardingHabitBoardSeed {
  OnboardingHabitBoardSeed._();

  static Future<void> apply({
    required String habitId,
    required List<String> pickedImagePaths,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final board = await BoardsStorageService.ensureSingleBoard(prefs: p);

    final habits = await HabitStorageService.loadAll(prefs: p);
    final idx = habits.indexWhere((h) => h.id == habitId);
    if (idx != -1) {
      habits[idx] = habits[idx].copyWith(boardId: board.id);
      await HabitStorageService.saveAll(habits, prefs: p);
    }

    if (pickedImagePaths.isEmpty) return;

    var tiles = await GridTilesStorageService.loadTiles(board.id, prefs: p);
    if (tiles.isEmpty) return;

    final storedPaths = <String>[];
    for (final path in pickedImagePaths) {
      final stored = await persistImageToAppStorage(path);
      if (stored != null && stored.trim().isNotEmpty) {
        storedPaths.add(stored.trim());
      }
    }
    if (storedPaths.isEmpty) return;

    var linkedHabitToTile = false;
    final next = <GridTileModel>[];
    var imgIdx = 0;
    for (var i = 0; i < tiles.length; i++) {
      var t = tiles[i];
      if (imgIdx < storedPaths.length &&
          (t.type == 'empty' || t.isPlaceholder)) {
        final path = storedPaths[imgIdx];
        final linkHabit = !linkedHabitToTile;
        if (linkHabit) linkedHabitToTile = true;
        t = t.copyWith(
          type: 'image',
          content: path,
          isPlaceholder: false,
          habitIds: linkHabit ? [habitId] : t.habitIds,
        );
        imgIdx++;
      }
      next.add(t);
    }

    await GridTilesStorageService.saveTiles(board.id, next, prefs: p);
  }
}
