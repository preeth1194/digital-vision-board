import 'package:flutter/foundation.dart';

@immutable
class GridTileBlueprint {
  /// Tile width in grid "cells" (columns).
  final int crossAxisCount;

  /// Tile height in grid "cells" (rows).
  final int mainAxisCount;

  const GridTileBlueprint({
    required this.crossAxisCount,
    required this.mainAxisCount,
  });
}

@immutable
class GridTemplate {
  /// Unique ID (e.g. 'classic_4').
  final String id;

  /// Display name (e.g. 'Travel Collage').
  final String name;

  /// Layout structure (sizes only; no user data).
  final List<GridTileBlueprint> tiles;

  const GridTemplate({
    required this.id,
    required this.name,
    required this.tiles,
  });
}

/// Hardcoded templates using quilt-style tile sizes.
///
/// Note: The editor renders these into a `StaggeredGrid.count` with
/// `crossAxisCount: 4` (standard mobile grid).
class GridTemplates {
  GridTemplates._();

  static const GridTemplate hero = GridTemplate(
    id: 'the_hero',
    name: 'The Hero',
    tiles: [
      // 1 large square (2x2)
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 2),
      // followed by 10 small squares (1x1) => 11 tiles total
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
    ],
  );

  static const GridTemplate split = GridTemplate(
    id: 'the_split',
    name: 'The Split',
    tiles: [
      // 2 tall vertical rectangles side-by-side (hero columns)
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 4),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 4),
      // plus additional smaller tiles to reach 10 tiles total
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 2),
    ],
  );

  static const GridTemplate masonryMix = GridTemplate(
    id: 'masonry_mix',
    name: 'Masonry Mix',
    tiles: [
      // Alternating 1x1 and 1x2 blocks (quilt-like feel).
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
    ],
  );

  static const GridTemplate simpleGrid = GridTemplate(
    id: 'simple_grid',
    name: 'Simple Grid',
    tiles: [
      // Uniform 1x1 tiles in a 4-column grid.
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
    ],
  );

  static const GridTemplate travelCollage = GridTemplate(
    id: 'travel_collage',
    name: 'Travel Collage',
    tiles: [
      GridTileBlueprint(crossAxisCount: 4, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 2),
      GridTileBlueprint(crossAxisCount: 2, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 1, mainAxisCount: 1),
      GridTileBlueprint(crossAxisCount: 4, mainAxisCount: 1),
    ],
  );

  static const List<GridTemplate> all = [
    hero,
    split,
    masonryMix,
    simpleGrid,
    travelCollage,
  ];

  static GridTemplate byId(String? id) {
    if (id == null) return hero;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return hero;
  }

  /// Returns tile blueprints that fill the viewport for [tileCount] tiles.
  /// Uses 4 columns; [viewportWidth] and [viewportHeight] drive cell extent and row count.
  static List<GridTileBlueprint> optimalSizesForTileCount(
    int tileCount, {
    double viewportWidth = 400,
    double viewportHeight = 700,
  }) {
    if (tileCount <= 0) return [];
    const crossAxisCount = 4;
    const spacing = 10.0;
    const horizontalPadding = 32.0;
    const appBarHeight = 56.0;
    const bottomBarHeight = 56.0;
    const verticalPadding = 32.0;
    const safePadding = 48.0;

    final gridWidth = (viewportWidth - horizontalPadding).clamp(1.0, double.infinity);
    final cellExtent = (gridWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;
    final availableHeight = viewportHeight - appBarHeight - bottomBarHeight - verticalPadding - safePadding;
    final rowCount = (availableHeight / (cellExtent + spacing)).floor().clamp(1, 20);
    // Each tile spans 2 columns; main axis = rows distributed over N tiles.
    final mainPerTile = ((rowCount * 2) / tileCount).ceil().clamp(1, 8);
    final c = 2;
    final m = mainPerTile;

    return List.generate(
      tileCount,
      (_) => GridTileBlueprint(crossAxisCount: c, mainAxisCount: m),
    );
  }
}

