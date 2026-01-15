import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../services/grid_board_editor_flows.dart';
import '../services/grid_tiles_storage_service.dart';
import '../widgets/grid/add_tile_dialog.dart';
import '../widgets/grid/grid_board_editor_scaffold.dart';
import '../widgets/grid/grid_tile_type.dart';

class GridBoardEditor extends StatefulWidget {
  final String boardId;
  final String title;
  final bool initialIsEditing;

  const GridBoardEditor({
    super.key,
    required this.boardId,
    required this.title,
    required this.initialIsEditing,
  });

  @override
  State<GridBoardEditor> createState() => _GridBoardEditorState();
}

class _GridBoardEditorState extends State<GridBoardEditor> {
  static const int _minMainAxisCells = 1;
  static const int _maxMainAxisCells = 4;

  // Shared pick/compress defaults (kept aligned with freeform editor)
  static const double _pickedImageMaxSide = 2048;
  static const int _pickedImageQuality = 92;

  late bool _isEditing;
  bool _resizeMode = false;
  bool _loading = true;

  SharedPreferences? _prefs;
  List<GridTileModel> _tiles = [];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.initialIsEditing;
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    final loaded = await GridTilesStorageService.loadTiles(widget.boardId, prefs: _prefs);
    if (!mounted) return;
    setState(() {
      _tiles = loaded;
      _loading = false;
    });
  }

  List<GridTileModel> _sortedTiles(List<GridTileModel> tiles) =>
      GridTilesStorageService.sortTiles(tiles);

  Future<void> _saveTiles(List<GridTileModel> tiles) async {
    final normalized = await GridTilesStorageService.saveTiles(
      widget.boardId,
      tiles,
      prefs: _prefs,
    );
    if (!mounted) return;
    setState(() => _tiles = normalized);
  }

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _resizeMode = false;
    });
  }

  void _toggleResizeMode() {
    if (!_isEditing) return;
    setState(() => _resizeMode = !_resizeMode);
  }

  Future<void> _showAddTileFlow() async {
    if (!_isEditing) return;
    final choice = await showAddGridTileDialog(context);
    if (choice == null) return;

    switch (choice) {
      case GridTileType.text:
        final next = await addTextTileFlow(context, _tiles);
        if (next != null) await _saveTiles(next);
        return;
      case GridTileType.image:
        final next = await addImageTileFlow(
          context,
          _tiles,
          pickedImageMaxSide: _pickedImageMaxSide,
          pickedImageQuality: _pickedImageQuality,
        );
        if (next != null) await _saveTiles(next);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GridBoardEditorScaffold(
      title: widget.title,
      loading: _loading,
      isEditing: _isEditing,
      resizeMode: _resizeMode,
      tiles: _sortedTiles(_tiles),
      onToggleEditMode: _toggleEditMode,
      onToggleResizeMode: _toggleResizeMode,
      onAddTile: _showAddTileFlow,
      onEditTextTile: (tile) async {
        final next = await editTextTileFlow(context, _tiles, tile);
        if (next != null) await _saveTiles(next);
      },
      onDeleteTile: (tile) async {
        final next = await deleteTileFlow(context, _tiles, tile);
        if (next != null) await _saveTiles(next);
      },
      onResizeTile: (tile, deltaW, deltaH) async {
        final next = resizeTile(
          _tiles,
          tile,
          crossAxisCount: GridBoardEditorScaffold.crossAxisCount,
          minMainAxisCells: _minMainAxisCells,
          maxMainAxisCells: _maxMainAxisCells,
          deltaW: deltaW,
          deltaH: deltaH,
        );
        await _saveTiles(next);
      },
    );
  }
}

