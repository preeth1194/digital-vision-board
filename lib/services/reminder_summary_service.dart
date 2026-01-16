import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/grid_tile_model.dart';
import '../models/habit_item.dart';
import '../models/task_item.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import 'grid_tiles_storage_service.dart';
import 'vision_board_components_storage_service.dart';

enum ReminderKind { habit, taskDue }

class ReminderItem {
  final ReminderKind kind;
  final DateTime date; // date-only
  final int? minutesSinceMidnight; // for habits
  final String boardId;
  final String boardTitle;
  final String label;

  const ReminderItem({
    required this.kind,
    required this.date,
    required this.minutesSinceMidnight,
    required this.boardId,
    required this.boardTitle,
    required this.label,
  });

  String get isoDate => ReminderSummaryService.toIsoDate(date);
}

class ReminderSummary {
  final int todayPendingCount;
  final Map<String, List<ReminderItem>> itemsByIsoDate; // sorted keys not guaranteed

  const ReminderSummary({
    required this.todayPendingCount,
    required this.itemsByIsoDate,
  });
}

class ReminderSummaryService {
  ReminderSummaryService._();

  static String toIsoDate(DateTime d) {
    final dd = DateTime(d.year, d.month, d.day);
    final yyyy = dd.year.toString().padLeft(4, '0');
    final mm = dd.month.toString().padLeft(2, '0');
    final day = dd.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$day';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfMonth(DateTime now) => DateTime(now.year, now.month + 1, 0);

  static bool _isHabitScheduledOnDate(HabitItem habit, DateTime date) {
    final freq = (habit.frequency ?? '').trim().toLowerCase();
    final hasWeeklySchedule = freq == 'weekly' && habit.weeklyDays.isNotEmpty;
    if (!hasWeeklySchedule) return true; // daily, or weekly-legacy without explicit weekdays
    return habit.weeklyDays.contains(date.weekday);
  }

  static int? _parseIsoToComparable(String? iso) {
    final s = (iso ?? '').trim();
    if (s.isEmpty) return null;
    // ISO yyyy-mm-dd is lexicographically comparable; convert to int yyyymmdd for safety.
    final parts = s.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return (y * 10000) + (m * 100) + d;
  }

  static DateTime? _parseIsoDate(String? iso) {
    final s = (iso ?? '').trim();
    if (s.isEmpty) return null;
    try {
      final d = DateTime.parse(s);
      return _dateOnly(d);
    } catch (_) {
      return null;
    }
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

  static Future<ReminderSummary> build({
    required List<VisionBoardInfo> boards,
    required SharedPreferences prefs,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final today = _dateOnly(current);
    final tomorrow = today.add(const Duration(days: 1));
    final end = _endOfMonth(today);

    final todayIso = toIsoDate(today);
    final todayKey = _parseIsoToComparable(todayIso)!;
    final endKey = _parseIsoToComparable(toIsoDate(end))!;

    final nowMinutes = (current.hour * 60) + current.minute;

    final itemsByIso = <String, List<ReminderItem>>{};
    int todayPending = 0;

    for (final b in boards) {
      final components = await _loadBoardComponents(b, prefs: prefs);

      // Habits reminders
      for (final c in components) {
        for (final h in c.habits) {
          if (!h.reminderEnabled || h.reminderMinutes == null) continue;
          // Iterate days from today..endOfMonth
          for (DateTime d = today; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
            if (!_isHabitScheduledOnDate(h, d)) continue;
            if (h.isCompletedForCurrentPeriod(d)) continue;

            // "Today pending": only future times.
            if (d == today && h.reminderMinutes! <= nowMinutes) continue;

            final item = ReminderItem(
              kind: ReminderKind.habit,
              date: d,
              minutesSinceMidnight: h.reminderMinutes,
              boardId: b.id,
              boardTitle: b.title,
              label: h.name,
            );
            (itemsByIso[item.isoDate] ??= []).add(item);
            if (d == today) todayPending++;
          }
        }
      }

      // Tasks due dates (checklist items)
      for (final c in components) {
        for (final t in c.tasks) {
          for (final ci in t.checklist) {
            if (ci.isCompleted) continue;
            final dueIso = (ci.dueDate ?? '').trim();
            final dueKey = _parseIsoToComparable(dueIso);
            if (dueKey == null) continue;
            if (dueKey < todayKey || dueKey > endKey) continue;

            final dueDate = _parseIsoDate(dueIso);
            if (dueDate == null) continue;

            final item = ReminderItem(
              kind: ReminderKind.taskDue,
              date: dueDate,
              minutesSinceMidnight: null,
              boardId: b.id,
              boardTitle: b.title,
              label: '${t.title}: ${ci.text}',
            );
            (itemsByIso[item.isoDate] ??= []).add(item);
            if (dueDate == today) todayPending++;
          }
        }
      }
    }

    // Sort each day’s list by time (habits first by time) then label.
    for (final entry in itemsByIso.entries) {
      entry.value.sort((a, b) {
        final am = a.minutesSinceMidnight ?? 999999;
        final bm = b.minutesSinceMidnight ?? 999999;
        if (am != bm) return am.compareTo(bm);
        if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
        return a.label.compareTo(b.label);
      });
    }

    // Ensure tomorrow section exists if empty? UI can decide; we just provide data.
    // (Leave as-is.)
    // References to tomorrow are used by UI helpers.
    // ignore: unused_local_variable
    final _ = tomorrow;

    return ReminderSummary(todayPendingCount: todayPending, itemsByIsoDate: itemsByIso);
  }
}

