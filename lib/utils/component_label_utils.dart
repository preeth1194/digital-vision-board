import '../models/goal_metadata.dart';
import '../models/vision_components.dart';

/// Centralized helpers for user-facing labels for a component/tile.
final class ComponentLabelUtils {
  ComponentLabelUtils._();

  static String categoryOrTitleOrId(VisionComponent component) {
    GoalMetadata? goal;
    if (component is ImageComponent) goal = component.goal;

    final category = (goal?.category ?? '').trim();
    if (category.isNotEmpty) return category;

    final title = (goal?.title ?? '').trim();
    // Avoid showing internal grid ids like "tile_0" as a user-facing title.
    if (title.isNotEmpty && !_looksLikeInternalTileId(title)) return title;

    // Avoid showing internal grid ids like "tile_0" as a user-facing label.
    if (_looksLikeInternalTileId(component.id)) return 'Goal';
    return component.id;
  }

  static bool _looksLikeInternalTileId(String s) {
    final v = s.trim().toLowerCase();
    return v.startsWith('tile_');
  }
}

