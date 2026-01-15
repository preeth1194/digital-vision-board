import 'package:flutter/material.dart';

import '../../models/grid_tile_model.dart';
import '../../utils/file_image_provider.dart';
import 'mini_icon_button.dart';

class GridTileCard extends StatelessWidget {
  final GridTileModel tile;
  final bool isEditing;
  final bool resizeMode;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(int deltaW, int deltaH)? onResize;
  final VoidCallback? onDelete;

  const GridTileCard({
    super.key,
    required this.tile,
    required this.isEditing,
    required this.resizeMode,
    required this.onTap,
    required this.onLongPress,
    required this.onResize,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(16);

    final Widget content = switch (tile.type) {
      'image' => _imageTile(borderRadius),
      _ => _textTile(context, borderRadius),
    };

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: borderRadius,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: Colors.black12),
              ),
              clipBehavior: Clip.antiAlias,
              child: content,
            ),
          ),
          if (isEditing && resizeMode)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MiniIconButton(
                      icon: Icons.remove,
                      tooltip: 'Width -',
                      onPressed: () => onResize?.call(-1, 0),
                    ),
                    MiniIconButton(
                      icon: Icons.add,
                      tooltip: 'Width +',
                      onPressed: () => onResize?.call(1, 0),
                    ),
                    const SizedBox(width: 8),
                    MiniIconButton(
                      icon: Icons.expand_less,
                      tooltip: 'Height -',
                      onPressed: () => onResize?.call(0, -1),
                    ),
                    MiniIconButton(
                      icon: Icons.expand_more,
                      tooltip: 'Height +',
                      onPressed: () => onResize?.call(0, 1),
                    ),
                    const Spacer(),
                    MiniIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Remove',
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageTile(BorderRadius borderRadius) {
    final path = tile.content ?? '';
    final provider = fileImageProviderFromPath(path);
    return ClipRRect(
      borderRadius: borderRadius,
      child: provider != null
          ? Image(image: provider, fit: BoxFit.cover)
          : Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
    );
  }

  Widget _textTile(BuildContext context, BorderRadius borderRadius) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.55),
        borderRadius: borderRadius,
      ),
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          (tile.content ?? '').trim().isEmpty ? 'Tap to edit' : (tile.content ?? ''),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

