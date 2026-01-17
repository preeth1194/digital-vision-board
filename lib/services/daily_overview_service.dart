import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import 'boards_storage_service.dart';
import 'grid_tiles_storage_service.dart';
import 'vision_board_components_storage_service.dart';

final class DailyOverviewService {
  DailyOverviewService._();

  static Future<Map<String, DailyMoodSummary>> buildMoodByIsoDate({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: p);
    final byIso = <String, List<DailyRatingItem>>{};

    for (final b in boards) {
      final comps = await _loadBoardComponents(b, prefs: p);
      for (final c in comps) {
        // Habits
        for (final h in c.habits) {
          for (final entry in h.feedbackByDate.entries) {
            final iso = entry.key;
            final fb = entry.value;
            if (fb.rating <= 0) continue;
            (byIso[iso] ??= []).add(
              DailyRatingItem(
                isoDate: iso,
                boardId: b.id,
                boardTitle: b.title,
                componentId: c.id,
                kind: DailyRatingKind.habit,
                title: h.name,
                rating: fb.rating,
                note: fb.note,
              ),
            );
          }
        }

        // Tasks + checklist
        for (final t in c.tasks) {
          for (final entry in t.completionFeedbackByDate.entries) {
            final iso = entry.key;
            final fb = entry.value;
            if (fb.rating <= 0) continue;
            (byIso[iso] ??= []).add(
              DailyRatingItem(
                isoDate: iso,
                boardId: b.id,
                boardTitle: b.title,
                componentId: c.id,
                kind: DailyRatingKind.task,
                title: t.title,
                rating: fb.rating,
                note: fb.note,
              ),
            );
          }
          for (final item in t.checklist) {
            for (final entry in item.feedbackByDate.entries) {
              final iso = entry.key;
              final fb = entry.value;
              if (fb.rating <= 0) continue;
              (byIso[iso] ??= []).add(
                DailyRatingItem(
                  isoDate: iso,
                  boardId: b.id,
                  boardTitle: b.title,
                  componentId: c.id,
                  kind: DailyRatingKind.checklistItem,
                  title: '${t.title}: ${item.text}',
                  rating: fb.rating,
                  note: fb.note,
                ),
              );
            }
          }
        }
      }
    }

    final summaries = <String, DailyMoodSummary>{};
    for (final entry in byIso.entries) {
      final iso = entry.key;
      final items = entry.value;
      if (items.isEmpty) continue;
      final sum = items.fold<int>(0, (a, b) => a + b.rating);
      final avg = sum / items.length;
      summaries[iso] = DailyMoodSummary(
        isoDate: iso,
        averageRating: avg,
        ratingCount: items.length,
        items: items,
      );
    }
    return summaries;
  }

  static List<VisionComponent> _componentsFromGridTiles(List<GridTileModel> tiles) {
    final comps = <VisionComponent>[];
    for (final t in tiles) {
      if (t.type == 'empty') continue;
      comps.add(
        ImageComponent(
          id: t.id,
          position: Offset.zero,
          size: const Size(1, 1),
          rotation: 0,
          scale: 1,
          zIndex: t.index,
          imagePath: (t.type == 'image') ? (t.content ?? '') : '',
          goal: t.goal,
          habits: t.habits,
          tasks: t.tasks,
        ),
      );
    }
    return comps;
  }

  static Future<List<VisionComponent>> _loadBoardComponents(
    VisionBoardInfo board, {
    required SharedPreferences prefs,
  }) async {
    if (board.layoutType == VisionBoardInfo.layoutGrid) {
      final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: prefs);
      return _componentsFromGridTiles(tiles);
    }
    return VisionBoardComponentsStorageService.loadComponents(board.id, prefs: prefs);
  }
}

enum DailyRatingKind { habit, checklistItem, task }

final class DailyRatingItem {
  final String isoDate;
  final String boardId;
  final String boardTitle;
  final String componentId;
  final DailyRatingKind kind;
  final String title;
  final int rating; // 1..5
  final String? note;

  const DailyRatingItem({
    required this.isoDate,
    required this.boardId,
    required this.boardTitle,
    required this.componentId,
    required this.kind,
    required this.title,
    required this.rating,
    required this.note,
  });
}

final class DailyMoodSummary {
  final String isoDate;
  final double averageRating; // 1..5
  final int ratingCount;
  final List<DailyRatingItem> items;

  const DailyMoodSummary({
    required this.isoDate,
    required this.averageRating,
    required this.ratingCount,
    required this.items,
  });
}

