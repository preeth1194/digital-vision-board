import 'package:flutter/material.dart';

import 'grid_tile_type.dart';

Future<GridTileType?> showAddGridTileDialog(BuildContext context) {
  return showDialog<GridTileType>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add to grid'),
      content: const Text('Choose what to add'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.of(context).pop(GridTileType.text),
          icon: const Icon(Icons.text_fields),
          label: const Text('Add Text'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(GridTileType.image),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Add Image'),
        ),
      ],
    ),
  );
}

