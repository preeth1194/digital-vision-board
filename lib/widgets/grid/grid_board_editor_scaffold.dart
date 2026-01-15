import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../models/grid_tile_model.dart';
import 'add_tile_card.dart';
import 'grid_tile_card.dart';

class GridBoardEditorScaffold extends StatelessWidget {
  final String title;
  final bool loading;
  final bool isEditing;
  final bool resizeMode;
  final List<GridTileModel> tiles;

  final VoidCallback onToggleEditMode;
  final VoidCallback onToggleResizeMode;
  final VoidCallback onAddTile;

  final Future<void> Function(GridTileModel tile) onEditTextTile;
  final Future<void> Function(GridTileModel tile) onDeleteTile;
  final Future<void> Function(GridTileModel tile, int deltaW, int deltaH) onResizeTile;

  const GridBoardEditorScaffold({
    super.key,
    required this.title,
    required this.loading,
    required this.isEditing,
    required this.resizeMode,
    required this.tiles,
    required this.onToggleEditMode,
    required this.onToggleResizeMode,
    required this.onAddTile,
    required this.onEditTextTile,
    required this.onDeleteTile,
    required this.onResizeTile,
  });

  static const int crossAxisCount = 2;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit: $title' : title),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: isEditing ? 'Switch to View Mode' : 'Switch to Edit Mode',
            icon: Icon(isEditing ? Icons.visibility : Icons.edit),
            onPressed: onToggleEditMode,
          ),
          if (isEditing)
            IconButton(
              tooltip: resizeMode ? 'Exit Resize Mode' : 'Resize Mode',
              icon: Icon(resizeMode ? Icons.close_fullscreen : Icons.open_in_full),
              onPressed: onToggleResizeMode,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: StaggeredGrid.count(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              ...tiles.map((tile) {
                return StaggeredGridTile.count(
                  crossAxisCellCount: tile.crossAxisCellCount,
                  mainAxisCellCount: tile.mainAxisCellCount,
                  child: GridTileCard(
                    tile: tile,
                    isEditing: isEditing,
                    resizeMode: resizeMode,
                    onTap: () async {
                      if (!isEditing) return;
                      if (tile.type == 'text') await onEditTextTile(tile);
                    },
                    onLongPress: () {
                      if (isEditing) onToggleResizeMode();
                    },
                    onResize: (deltaW, deltaH) => onResizeTile(tile, deltaW, deltaH),
                    onDelete: () => onDeleteTile(tile),
                  ),
                );
              }),
              if (isEditing)
                StaggeredGridTile.count(
                  crossAxisCellCount: 1,
                  mainAxisCellCount: 1,
                  child: AddTileCard(onTap: onAddTile),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

