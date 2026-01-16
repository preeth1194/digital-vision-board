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
}

