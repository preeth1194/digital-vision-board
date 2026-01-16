import 'package:flutter/material.dart';

import '../../models/grid_tile_model.dart';
import '../../utils/file_image_provider.dart';
import 'mini_icon_button.dart';

class GridTileCard extends StatelessWidget {
  final GridTileModel tile;
  final bool isEditing;
  final bool resizeMode;
  final bool isSelected;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(int deltaW, int deltaH)? onResize;
  final VoidCallback? onDelete;

  const GridTileCard({
    super.key,
    required this.tile,
    required this.isEditing,
    required this.resizeMode,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.onResize,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.zero;
    final goalTitle = (tile.goal?.title ?? '').trim();
    final fallbackTitle = tile.type == 'text'
        ? (tile.content ?? '').trim()
        : (tile.type == 'image' ? 'Goal' : '');
    final title = goalTitle.isNotEmpty ? goalTitle : fallbackTitle;
    final showTitle = title.isNotEmpty && tile.type != 'empty';

    final Widget content = switch (tile.type) {
      'image' => _imageTile(borderRadius),
      _ => _textTile(context, borderRadius),
    };

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: (isEditing && isSelected)
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.7)
                      : Colors.black12,
                  width: (isEditing && isSelected) ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.none,
              child: content,
            ),
          ),
          if (showTitle)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (isEditing && isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: MiniIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Remove',
                  onPressed: onDelete,
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
    return provider != null
        ? Image(image: provider, fit: BoxFit.cover)
        : Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
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

