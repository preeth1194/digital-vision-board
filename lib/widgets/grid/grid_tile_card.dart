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
    final colorScheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.zero;
    final goalTitle = (tile.goal?.title ?? '').trim();
    final fallbackTitle = tile.type == 'text'
        ? (tile.content ?? '').trim()
        : (tile.type == 'image' ? 'Goal' : '');
    final title = goalTitle.isNotEmpty ? goalTitle : fallbackTitle;
    final showTitle = title.isNotEmpty && tile.type != 'empty';

    final Widget content = switch (tile.type) {
      'image' => _imageTile(context, borderRadius, colorScheme),
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
                      ? colorScheme.primary.withValues(alpha: 0.7)
                      : colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                  color: colorScheme.shadow.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.surface, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          if (isEditing && isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.shadow.withValues(alpha: 0.55),
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

  Widget _imageTile(BuildContext context, BorderRadius borderRadius, ColorScheme colorScheme) {
    final path = tile.content ?? '';
    final provider = fileImageProviderFromPath(path);
    return provider != null
        ? Image(image: provider, fit: BoxFit.cover)
        : Container(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
  }

  Alignment _getTextAlignmentForTile(GridTileModel tile) {
    int hash32(String s) {
      int h = 0x811c9dc5;
      for (int i = 0; i < s.length; i++) {
        h ^= s.codeUnitAt(i);
        h = (h * 0x01000193) & 0x7fffffff;
      }
      return h;
    }
    
    final v = hash32('${tile.id}::alignment');
    final alignments = [
      Alignment.topLeft,
      Alignment.topCenter,
      Alignment.topRight,
      Alignment.centerLeft,
      Alignment.center,
      Alignment.centerRight,
      Alignment.bottomLeft,
      Alignment.bottomCenter,
      Alignment.bottomRight,
    ];
    return alignments[v % alignments.length];
  }

  TextAlign _getTextAlignFromAlignment(Alignment alignment) {
    if (alignment.x < -0.3) return TextAlign.left;
    if (alignment.x > 0.3) return TextAlign.right;
    return TextAlign.center;
  }

  Widget _textTile(BuildContext context, BorderRadius borderRadius) {
    final textAlignment = _getTextAlignmentForTile(tile);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: borderRadius,
      ),
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: textAlignment,
        child: Text(
          (tile.content ?? '').trim().isEmpty ? 'Tap to edit' : (tile.content ?? ''),
          textAlign: _getTextAlignFromAlignment(textAlignment),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

