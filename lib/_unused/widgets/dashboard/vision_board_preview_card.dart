import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/vision_board_info.dart';
import '../../models/grid_tile_model.dart';
import '../../models/vision_components.dart';
import '../../services/grid_tiles_storage_service.dart';
import '../../services/vision_board_components_storage_service.dart';
import '../../utils/file_image_provider.dart';
import '../../utils/app_typography.dart';

/// Widget that displays a minified preview of a vision board.
/// Shows grid tiles for grid boards, or a placeholder for other board types.
class VisionBoardPreviewCard extends StatelessWidget {
  final VisionBoardInfo board;
  final String? activeBoardId;
  final SharedPreferences? prefs;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const VisionBoardPreviewCard({
    super.key,
    required this.board,
    this.activeBoardId,
    this.prefs,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = board.id == activeBoardId;
    final tileColor = Color(board.tileColorValue);
    final iconData = boardIconFromCodePoint(board.iconCodePoint);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      elevation: isActive ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isActive
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Stack(
        children: [
          // Preview content with reduced opacity
          Opacity(
            opacity: 0.65,
            child: FutureBuilder<Widget>(
              future: _buildPreviewContent(context),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingPlaceholder(context, tileColor);
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _buildPlaceholder(context, tileColor, iconData);
                }
                return snapshot.data!;
              },
            ),
          ),
          // Tap area - positioned first so buttons can be on top
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Container(),
              ),
            ),
          ),
          // Board name overlay at bottom - on top of tap area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          board.title,
                          style: AppTypography.heading3(context).copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isActive)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Selected',
                              style: AppTypography.caption(context).copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Action buttons - on top of everything, fully interactive
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white),
                          tooltip: 'Edit',
                          onPressed: onEdit,
                          iconSize: 20,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white),
                          tooltip: 'Delete',
                          onPressed: onDelete,
                          iconSize: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Widget> _buildPreviewContent(BuildContext context) async {
    if (board.layoutType == VisionBoardInfo.layoutGrid) {
      return _buildGridPreview(context);
    } else {
      return _buildComponentPreview(context);
    }
  }

  Future<Widget> _buildGridPreview(BuildContext context) async {
    final tiles = await GridTilesStorageService.loadTiles(
      board.id,
      prefs: prefs,
    );

    if (tiles.isEmpty) {
      final tileColor = Color(board.tileColorValue);
      final iconData = boardIconFromCodePoint(board.iconCodePoint);
      return _buildPlaceholder(context, tileColor, iconData);
    }

    // Filter to only image tiles and limit to 9 max
    final imageTiles = tiles
        .where((t) => t.type == 'image' && (t.content ?? '').trim().isNotEmpty)
        .take(9)
        .toList();

    if (imageTiles.isEmpty) {
      final tileColor = Color(board.tileColorValue);
      final iconData = boardIconFromCodePoint(board.iconCodePoint);
      return _buildPlaceholder(context, tileColor, iconData);
    }

    // Use 3x3 grid for compact preview
    const crossAxisCount = 3;
    const spacing = 2.0;
    const height = 150.0; // Reduced from 200 to 150

    return SizedBox(
      height: height,
      child: StaggeredGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        children: imageTiles.map((tile) {
          final imagePath = (tile.content ?? '').trim();
          final provider = fileImageProviderFromPath(imagePath);

          return StaggeredGridTile.count(
            crossAxisCellCount: 1,
            mainAxisCellCount: 1,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: provider != null
                  ? Image(
                      image: provider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildEmptyTile(context);
                      },
                    )
                  : _buildEmptyTile(context),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<Widget> _buildComponentPreview(BuildContext context) async {
    final components = await VisionBoardComponentsStorageService.loadComponents(
      board.id,
      prefs: prefs,
    );

    // Find first image component
    final imageComponents = components
        .whereType<ImageComponent>()
        .where((c) => (c.imagePath ?? '').trim().isNotEmpty)
        .toList();
    final imageComponent = imageComponents.isNotEmpty ? imageComponents.first : null;

    if (imageComponent == null) {
      final tileColor = Color(board.tileColorValue);
      final iconData = boardIconFromCodePoint(board.iconCodePoint);
      return _buildPlaceholder(context, tileColor, iconData);
    }

    final imagePath = (imageComponent.imagePath ?? '').trim();
    final provider = fileImageProviderFromPath(imagePath);

    return SizedBox(
      height: 150, // Reduced from 200 to 150
      child: provider != null
          ? Image(
              image: provider,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                final tileColor = Color(board.tileColorValue);
                final iconData = boardIconFromCodePoint(board.iconCodePoint);
                return _buildPlaceholder(context, tileColor, iconData);
              },
            )
          : _buildPlaceholder(
              context,
              Color(board.tileColorValue),
              boardIconFromCodePoint(board.iconCodePoint),
            ),
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    Color tileColor,
    IconData iconData,
  ) {
    final iconColor = tileColor.computeLuminance() < 0.45
        ? Colors.white
        : Colors.black87;

    return Container(
      height: 150, // Reduced from 200 to 150
      color: tileColor,
      child: Center(
        child: Icon(
          iconData,
          size: 48, // Reduced from 64 to 48
          color: iconColor.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder(BuildContext context, Color tileColor) {
    return Container(
      height: 150, // Reduced from 200 to 150
      color: tileColor.withOpacity(0.3),
      child: Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyTile(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
      child: Icon(
        Icons.image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
        size: 24,
      ),
    );
  }
}
