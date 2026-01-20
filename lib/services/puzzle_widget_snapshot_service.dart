import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle_state_service.dart';
import 'puzzle_service.dart';
import 'puzzle_widget_native_bridge.dart';
import '../models/vision_board_info.dart';
import 'boards_storage_service.dart';

/// Builds and stores a compact JSON snapshot for the native puzzle widget.
///
/// Data source:
/// - Current puzzle image from PuzzleService
/// - Puzzle state from PuzzleStateService (piece positions, completion status)
/// - Goal title if puzzle is completed
final class PuzzleWidgetSnapshotService {
  PuzzleWidgetSnapshotService._();

  static const String snapshotPrefsKey = 'puzzle_widget_snapshot_v1';

  static Future<void> refreshBestEffort({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    try {
      final json = await _buildSnapshotJson(prefs: p);
      if (json == null) return;
      await p.setString(snapshotPrefsKey, json);
      // iOS widgets can't read FlutterSharedPreferences; mirror into App Group (best-effort).
      await PuzzleWidgetNativeBridge.writeSnapshotToAppGroupBestEffort(json);
      await PuzzleWidgetNativeBridge.updateWidgetsBestEffort();
    } catch (_) {
      // Best-effort: ignore errors (widgets are optional).
    }
  }

  static Future<String?> _buildSnapshotJson({required SharedPreferences prefs}) async {
    // Get current puzzle image
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    final imagePath = await PuzzleService.getCurrentPuzzleImage(
      boards: boards,
      prefs: prefs,
    );

    if (imagePath == null || imagePath.isEmpty) {
      // No puzzle image available
      return null;
    }

    // Load puzzle state
    final state = await PuzzleStateService.loadPuzzleState(
      imagePath: imagePath,
      prefs: prefs,
    );

    String? goalTitle;
    if (state?.isCompleted == true) {
      // Get goal title if puzzle is completed
      final goal = await PuzzleService.getGoalForImagePath(
        imagePath: imagePath,
        boards: boards,
        prefs: prefs,
      );
      goalTitle = goal?.title;
    }

    final snap = <String, dynamic>{
      'v': 1,
      'generatedAtMs': DateTime.now().millisecondsSinceEpoch,
      'imagePath': imagePath,
      'piecePositions': state?.piecePositions.map((p) => p ?? -1).toList() ?? <int>[],
      'positionPieces': state?.positionPieces.map((p) => p ?? -1).toList() ?? <int>[],
      'isCompleted': state?.isCompleted ?? false,
      'goalTitle': goalTitle,
    };

    return jsonEncode(snap);
  }

  /// Load the current snapshot.
  static Future<Map<String, dynamic>?> loadSnapshot({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(snapshotPrefsKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
