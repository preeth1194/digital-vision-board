import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/vision_board_info.dart';
import '../models/goal_metadata.dart';
import '../models/image_component.dart';
import '../models/grid_tile_model.dart';
import 'boards_storage_service.dart';
import 'vision_board_components_storage_service.dart';
import 'grid_tiles_storage_service.dart';

/// Service for persisting puzzle game state (piece positions, completion status).
final class PuzzleStateService {
  PuzzleStateService._();

  static String _normalizeImagePath(String imagePath) {
    // Normalize path for consistent key generation
    return imagePath.trim();
  }

  static String _stateKey(String imagePath) {
    final normalized = _normalizeImagePath(imagePath);
    return 'puzzle_state_${normalized.hashCode}';
  }

  /// Save puzzle state for a given image.
  static Future<void> savePuzzleState({
    required String imagePath,
    required List<int?> piecePositions, // pieceIndex -> position
    required List<int?> positionPieces, // position -> pieceIndex
    required bool isCompleted,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final key = _stateKey(imagePath);
    
    final state = {
      'imagePath': imagePath,
      'piecePositions': piecePositions.map((p) => p ?? -1).toList(),
      'positionPieces': positionPieces.map((p) => p ?? -1).toList(),
      'isCompleted': isCompleted,
      'savedAtMs': DateTime.now().millisecondsSinceEpoch,
    };

    await p.setString(key, jsonEncode(state));
  }

  /// Load puzzle state for a given image.
  /// Returns null if no state exists or image path doesn't match.
  static Future<PuzzleState?> loadPuzzleState({
    required String imagePath,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final key = _stateKey(imagePath);
    final raw = p.getString(key);
    
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedImagePath = decoded['imagePath'] as String?;
      
      // Verify image path matches (in case hash collision)
      if (savedImagePath != imagePath) return null;

      final piecePositionsRaw = decoded['piecePositions'] as List<dynamic>?;
      final positionPiecesRaw = decoded['positionPieces'] as List<dynamic>?;
      
      if (piecePositionsRaw == null || positionPiecesRaw == null) return null;

      final piecePositions = piecePositionsRaw
          .map((v) => (v as num).toInt() == -1 ? null : (v as num).toInt())
          .toList();
      final positionPieces = positionPiecesRaw
          .map((v) => (v as num).toInt() == -1 ? null : (v as num).toInt())
          .toList();

      return PuzzleState(
        imagePath: imagePath,
        piecePositions: piecePositions,
        positionPieces: positionPieces,
        isCompleted: decoded['isCompleted'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Clear puzzle state for a given image.
  static Future<void> clearPuzzleState({
    required String imagePath,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final key = _stateKey(imagePath);
    await p.remove(key);
  }

  /// Find goal metadata associated with an image path.
  /// Searches all boards for matching image.
  static Future<GoalMetadata?> getGoalForImage({
    required String imagePath,
    List<VisionBoardInfo>? boards,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boardsList = boards ?? await BoardsStorageService.loadBoards(prefs: p);
    final normalizedPath = imagePath.trim();

    // Search all boards
    for (final board in boardsList) {
      if (board.layoutType == VisionBoardInfo.layoutGrid) {
        // Search grid tiles
        final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: p);
        for (final tile in tiles) {
          if (tile.type == 'image' && 
              (tile.content ?? '').trim() == normalizedPath &&
              tile.goal != null) {
            return tile.goal;
          }
        }
      } else {
        // Search components
        final components = await VisionBoardComponentsStorageService.loadComponents(
          board.id,
          prefs: p,
        );
        for (final component in components) {
          if (component is ImageComponent &&
              component.imagePath.trim() == normalizedPath &&
              component.goal != null) {
            return component.goal;
          }
        }
      }
    }

    return null;
  }
}

/// Puzzle state model.
class PuzzleState {
  final String imagePath;
  final List<int?> piecePositions; // pieceIndex -> position
  final List<int?> positionPieces; // position -> pieceIndex
  final bool isCompleted;

  const PuzzleState({
    required this.imagePath,
    required this.piecePositions,
    required this.positionPieces,
    required this.isCompleted,
  });
}
