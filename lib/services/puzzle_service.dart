import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import '../models/image_component.dart';
import '../models/grid_tile_model.dart';
import 'boards_storage_service.dart';
import 'vision_board_components_storage_service.dart';
import 'grid_tiles_storage_service.dart';

class PuzzleService {
  PuzzleService._();

  static const String _puzzleImagePathKey = 'puzzle_image_path';
  static const String _puzzleLastRotationKey = 'puzzle_last_rotation_ms';
  static const Duration _rotationInterval = Duration(hours: 4);

  /// Get the current puzzle image path.
  /// Automatically rotates to a new random image if 4 hours have passed.
  static Future<String?> getCurrentPuzzleImage({
    SharedPreferences? prefs,
    List<VisionBoardInfo>? boards,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boardsList = boards ?? await BoardsStorageService.loadBoards(prefs: p);

    final lastRotationMs = p.getInt(_puzzleLastRotationKey);
    final now = DateTime.now().millisecondsSinceEpoch;
    final shouldRotate = lastRotationMs == null ||
        (now - lastRotationMs) >= _rotationInterval.inMilliseconds;

    if (shouldRotate) {
      // Auto-rotate to a new random image
      final availableImages = await getAllAvailableGoalImages(
        boards: boardsList,
        prefs: p,
      );
      if (availableImages.isNotEmpty) {
        final random = Random();
        final selected = availableImages[random.nextInt(availableImages.length)];
        await setPuzzleImage(selected, prefs: p);
        return selected;
      }
    }

    // Return stored image or null if none available
    final stored = p.getString(_puzzleImagePathKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    // If no stored image, try to get a random one
    final availableImages = await getAllAvailableGoalImages(
      boards: boardsList,
      prefs: p,
    );
    if (availableImages.isNotEmpty) {
      final random = Random();
      final selected = availableImages[random.nextInt(availableImages.length)];
      await setPuzzleImage(selected, prefs: p);
      return selected;
    }

    return null;
  }

  /// Manually set the puzzle image.
  static Future<void> setPuzzleImage(
    String imagePath, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_puzzleImagePathKey, imagePath);
    await p.setInt(_puzzleLastRotationKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Get all available goal images from all boards.
  static Future<List<String>> getAllAvailableGoalImages({
    List<VisionBoardInfo>? boards,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boardsList = boards ?? await BoardsStorageService.loadBoards(prefs: p);
    final images = <String>[];

    for (final board in boardsList) {
      if (board.layoutType == VisionBoardInfo.layoutGrid) {
        // Load grid tiles
        final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: p);
        for (final tile in tiles) {
          if (tile.type == 'image' && (tile.content ?? '').trim().isNotEmpty) {
            final path = tile.content!.trim();
            if (!images.contains(path)) {
              images.add(path);
            }
          }
        }
      } else {
        // Load components
        final components = await VisionBoardComponentsStorageService.loadComponents(
          board.id,
          prefs: p,
        );
        for (final component in components) {
          if (component is ImageComponent) {
            final path = (component.imagePath ?? '').trim();
            if (path.isNotEmpty && !images.contains(path)) {
              images.add(path);
            }
          }
        }
      }
    }

    return images;
  }

  /// Get time until next automatic rotation.
  static Future<Duration?> getTimeUntilNextRotation({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final lastRotationMs = p.getInt(_puzzleLastRotationKey);
    if (lastRotationMs == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = now - lastRotationMs;
    final remaining = _rotationInterval.inMilliseconds - elapsed;

    if (remaining <= 0) return Duration.zero;
    return Duration(milliseconds: remaining);
  }
}
