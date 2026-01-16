import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../models/goal_metadata.dart';
import '../models/image_component.dart';
import '../services/grid_tiles_storage_service.dart';
import '../widgets/habit_tracker_sheet.dart';

/// Full-screen viewer for a single grid tile treated as a goal.
///
/// This intentionally has no "layers" UI; it's a focused goal detail screen.
class GridGoalViewerScreen extends StatefulWidget {
  final String boardId;
  final String tileId;

  const GridGoalViewerScreen({
    super.key,
    required this.boardId,
    required this.tileId,
  });

  @override
  State<GridGoalViewerScreen> createState() => _GridGoalViewerScreenState();
}

class _GridGoalViewerScreenState extends State<GridGoalViewerScreen> {
  bool _loading = true;
  SharedPreferences? _prefs;
  List<GridTileModel> _tiles = const [];
  GridTileModel? _tile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _prefs = await SharedPreferences.getInstance();
    final tiles = await GridTilesStorageService.loadTiles(widget.boardId, prefs: _prefs);
    final tile = tiles.cast<GridTileModel?>().firstWhere(
          (t) => t?.id == widget.tileId,
          orElse: () => null,
        );
    if (!mounted) return;
    setState(() {
      _tiles = tiles;
      _tile = tile;
      _loading = false;
    });
  }

  Future<void> _saveTile(GridTileModel updated) async {
    final next = _tiles.map((t) => t.id == updated.id ? updated : t).toList();
    final normalized = await GridTilesStorageService.saveTiles(widget.boardId, next, prefs: _prefs);
    if (!mounted) return;
    setState(() {
      _tiles = normalized;
      _tile = normalized.cast<GridTileModel?>().firstWhere(
            (t) => t?.id == updated.id,
            orElse: () => updated,
          );
    });
  }

  ImageComponent _componentFromTile(GridTileModel tile) {
    final goal = tile.goal ?? GoalMetadata(title: tile.id);
    return ImageComponent(
      id: tile.id,
      position: Offset.zero,
      size: const Size(1, 1),
      rotation: 0,
      scale: 1,
      zIndex: 0,
      imagePath: (tile.type == 'image') ? (tile.content ?? '') : '',
      goal: goal,
      habits: tile.habits,
      tasks: tile.tasks,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tile = _tile;
    if (tile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Goal')),
        body: const Center(child: Text('This tile no longer exists.')),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: HabitTrackerSheet(
          component: _componentFromTile(tile),
          fullScreen: true,
          onComponentUpdated: (updated) {
            final img = updated is ImageComponent ? updated : null;
            final nextTile = tile.copyWith(
              goal: img?.goal ?? tile.goal,
              habits: updated.habits,
              tasks: updated.tasks,
            );
            _saveTile(nextTile);
          },
        ),
      ),
    );
  }
}

