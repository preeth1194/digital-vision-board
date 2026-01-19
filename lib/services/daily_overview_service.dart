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

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _toIsoDate(DateTime d) {
    final dd = _dateOnly(d);
    final yyyy = dd.year.toString().padLeft(4, '0');
    final mm = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$day';
  }

  /// Habits-only daily mood aggregation per board.
  ///
  /// Returns one entry per board with isoDate -> average rating (1..5) and ratingCount.
  static Future<List<BoardHabitMoodSummary>> buildHabitMoodByBoard({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: p);
    final out = <BoardHabitMoodSummary>[];

    for (final b in boards) {
      final comps = await _loadBoardComponents(b, prefs: p);
      final sumByIso = <String, int>{};
      final countByIso = <String, int>{};
      final habitRatingsByName = <String, HabitMoodSeries>{};

      for (final c in comps) {
        for (final h in c.habits) {
          final displayName = h.name.trim();
          if (displayName.isNotEmpty) {
            final key = displayName.toLowerCase();
            final existing = habitRatingsByName[key];
            final nextMap = existing == null
                ? <String, int>{}
                : Map<String, int>.from(existing.ratingByIsoDate);
            final nextCompleted = existing == null
                ? <String>{}
                : <String>{...existing.completedIsoDates};
            for (final entry in h.feedbackByDate.entries) {
              final iso = entry.key;
              final fb = entry.value;
              if (fb.rating <= 0) continue;
              nextMap[iso] = fb.rating;
            }
            for (final d in h.completedDates) {
              nextCompleted.add(_toIsoDate(d));
            }
            habitRatingsByName[key] =
                HabitMoodSeries(
                  name: existing?.name ?? displayName,
                  ratingByIsoDate: nextMap,
                  completedIsoDates: nextCompleted,
                );
          }

          for (final entry in h.feedbackByDate.entries) {
            final iso = entry.key;
            final fb = entry.value;
            if (fb.rating <= 0) continue;
            sumByIso[iso] = (sumByIso[iso] ?? 0) + fb.rating;
            countByIso[iso] = (countByIso[iso] ?? 0) + 1;
          }
        }
      }

      final byIso = <String, HabitMoodDaySummary>{};
      for (final entry in sumByIso.entries) {
        final iso = entry.key;
        final sum = entry.value;
        final count = countByIso[iso] ?? 0;
        if (count <= 0) continue;
        byIso[iso] = HabitMoodDaySummary(
          isoDate: iso,
          averageRating: sum / count,
          ratingCount: count,
        );
      }

      out.add(
        BoardHabitMoodSummary(
          boardId: b.id,
          boardTitle: b.title,
          byIsoDate: byIso,
          habitsByName: habitRatingsByName,
        ),
      );
    }
    return out;
  }

  /// Habits-only daily mood aggregation.
  ///
  /// Returns per-day average rating (1..5) along with count of ratings used.
  /// Source of truth is `HabitItem.feedbackByDate` across all boards/components.
  static Future<Map<String, HabitMoodDaySummary>> buildHabitMoodByIsoDate({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: p);

    final sumByIso = <String, int>{};
    final countByIso = <String, int>{};

    for (final b in boards) {
      final comps = await _loadBoardComponents(b, prefs: p);
      for (final c in comps) {
        for (final h in c.habits) {
          for (final entry in h.feedbackByDate.entries) {
            final iso = entry.key;
            final fb = entry.value;
            if (fb.rating <= 0) continue;
            sumByIso[iso] = (sumByIso[iso] ?? 0) + fb.rating;
            countByIso[iso] = (countByIso[iso] ?? 0) + 1;
          }
        }
      }
    }

    final out = <String, HabitMoodDaySummary>{};
    for (final entry in sumByIso.entries) {
      final iso = entry.key;
      final sum = entry.value;
      final count = countByIso[iso] ?? 0;
      if (count <= 0) continue;
      out[iso] = HabitMoodDaySummary(
        isoDate: iso,
        averageRating: sum / count,
        ratingCount: count,
      );
    }
    return out;
  }

  /// Habits-only mood grouped by normalized habit name (merged across boards).
  ///
  /// Returns: normalizedName -> HabitMoodSeries(name, ratingsByIsoDate)
  static Future<Map<String, HabitMoodSeries>> buildHabitMoodByHabitName({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: p);
    final byName = <String, HabitMoodSeries>{};

    for (final b in boards) {
      final comps = await _loadBoardComponents(b, prefs: p);
      for (final c in comps) {
        for (final h in c.habits) {
          final display = h.name.trim();
          if (display.isEmpty) continue;
          final key = display.toLowerCase();
          final existing = byName[key];
          final nextMap = existing == null
              ? <String, int>{}
              : Map<String, int>.from(existing.ratingByIsoDate);
          final nextCompleted =
              existing == null ? <String>{} : <String>{...existing.completedIsoDates};
          for (final entry in h.feedbackByDate.entries) {
            final iso = entry.key;
            final fb = entry.value;
            if (fb.rating <= 0) continue;
            // If multiple ratings exist for the same iso (merged), keep the latest encountered.
            nextMap[iso] = fb.rating;
          }
          for (final d in h.completedDates) {
            nextCompleted.add(_toIsoDate(d));
          }
          byName[key] = HabitMoodSeries(
            name: existing?.name ?? display,
            ratingByIsoDate: nextMap,
            completedIsoDates: nextCompleted,
          );
        }
      }
    }
    return byName;
  }

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

enum DailyRatingKind { habit }

final class BoardHabitMoodSummary {
  final String boardId;
  final String boardTitle;
  final Map<String, HabitMoodDaySummary> byIsoDate;
  final Map<String, HabitMoodSeries> habitsByName; // normalizedName -> series

  const BoardHabitMoodSummary({
    required this.boardId,
    required this.boardTitle,
    required this.byIsoDate,
    this.habitsByName = const {},
  });
}

final class HabitMoodDaySummary {
  final String isoDate;
  final double averageRating; // 1..5
  final int ratingCount;

  const HabitMoodDaySummary({
    required this.isoDate,
    required this.averageRating,
    required this.ratingCount,
  });
}

final class HabitMoodSeries {
  final String name;
  final Map<String, int> ratingByIsoDate; // iso -> 1..5
  final Set<String> completedIsoDates; // iso -> completed that day

  const HabitMoodSeries({
    required this.name,
    required this.ratingByIsoDate,
    this.completedIsoDates = const <String>{},
  });
}

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

