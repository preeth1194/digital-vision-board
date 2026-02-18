import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/grid_tile_model.dart';
import '../services/image_service.dart';
import '../widgets/dialogs/text_input_dialog.dart';
import '../widgets/grid/image_source_sheet.dart';

String _newTileId() => 'tile_${DateTime.now().millisecondsSinceEpoch}';

Future<List<GridTileModel>?> addTextTileFlow(
  BuildContext context,
  List<GridTileModel> tiles,
) async {
  final String? text =
      await showTextInputDialog(context, title: 'Add text', initialText: '');
  if (text == null || text.trim().isEmpty) return null;

  return [
    ...tiles,
    GridTileModel(
      id: _newTileId(),
      type: 'text',
      content: text.trim(),
      crossAxisCellCount: 1,
      mainAxisCellCount: 1,
      index: tiles.length,
    ),
  ];
}

Future<List<GridTileModel>?> addImageTileFlow(
  BuildContext context,
  List<GridTileModel> tiles, {
  required double pickedImageMaxSide,
  required int pickedImageQuality,
}) async {
  final ImageSource? source = await showImageSourceSheet(context);
  if (source == null) return null;

  final String? croppedPath = await ImageService.pickAndCropImage(
    context,
    source: source,
    maxWidth: pickedImageMaxSide,
    maxHeight: pickedImageMaxSide,
    imageQuality: pickedImageQuality,
  );
  if (croppedPath == null || croppedPath.isEmpty) return null;

  return [
    ...tiles,
    GridTileModel(
      id: _newTileId(),
      type: 'image',
      content: croppedPath,
      crossAxisCellCount: 1,
      mainAxisCellCount: 1,
      index: tiles.length,
    ),
  ];
}

Future<List<GridTileModel>?> editTextTileFlow(
  BuildContext context,
  List<GridTileModel> tiles,
  GridTileModel tile,
) async {
  final String? text = await showTextInputDialog(
    context,
    title: 'Edit text',
    initialText: tile.content ?? '',
  );
  if (text == null) return null;
  final updated = tile.copyWith(content: text.trim());
  return tiles.map((t) => t.id == tile.id ? updated : t).toList();
}

Future<List<GridTileModel>?> deleteTileFlow(
  BuildContext context,
  List<GridTileModel> tiles,
  GridTileModel tile,
) async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remove tile?'),
      content: const Text('This tile will be removed from the grid.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirm != true) return null;
  return tiles.where((t) => t.id != tile.id).toList();
}

List<GridTileModel> resizeTile(
  List<GridTileModel> tiles,
  GridTileModel tile, {
  required int crossAxisCount,
  required int minMainAxisCells,
  required int maxMainAxisCells,
  int deltaW = 0,
  int deltaH = 0,
}) {
  final nextW = (tile.crossAxisCellCount + deltaW).clamp(1, crossAxisCount);
  final nextH =
      (tile.mainAxisCellCount + deltaH).clamp(minMainAxisCells, maxMainAxisCells);
  final updated = tile.copyWith(crossAxisCellCount: nextW, mainAxisCellCount: nextH);
  return tiles.map((t) => t.id == tile.id ? updated : t).toList();
}

