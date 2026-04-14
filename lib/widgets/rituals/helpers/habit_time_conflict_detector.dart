import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/habit_item.dart';
import '../../../models/vision_board_info.dart';
import '../../../models/vision_components.dart';
import '../../../services/boards_storage_service.dart';
import '../../../services/grid_tiles_storage_service.dart';
import '../../../services/vision_board_components_storage_service.dart';

// ============================================================================
// ConflictResult
// ============================================================================

class ConflictResult {
  final bool hasConflict;
  final String? conflictingHabitName;
  final TimeOfDay? suggestedTime;
  final String? slotInfo;

  const ConflictResult({
    required this.hasConflict,
    this.conflictingHabitName,
    this.suggestedTime,
    this.slotInfo,
  });
}

// ============================================================================
// HabitTimeConflictDetector
// ============================================================================

class HabitTimeConflictDetector {
  HabitTimeConflictDetector._();

  static Future<List<HabitItem>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: prefs);
    final List<HabitItem> habits = [];
    for (final board in boards) {
      List<VisionComponent> components;
      if (board.layoutType == VisionBoardInfo.layoutGrid) {
        final tiles = await GridTilesStorageService.loadTiles(
          board.id,
          prefs: prefs,
        );
        components = tiles
            .where((t) => t.type != 'empty')
            .map(
              (t) => ImageComponent(
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
            )
            .toList();
      } else {
        components = await VisionBoardComponentsStorageService.loadComponents(
          board.id,
          prefs: prefs,
        );
      }
      for (final comp in components) {
        habits.addAll(comp.habits);
      }
    }
    return habits;
  }

  static ConflictResult check({
    required List<HabitItem> allHabits,
    required TimeOfDay startTime,
    required int durationMinutes,
    String? excludeHabitId,
  }) {
    final startMins = startTime.hour * 60 + startTime.minute;
    final duration = durationMinutes;
    final newEnd = startMins + duration;

    final List<(int, int, String)> occupied = [];
    String? conflictName;

    for (final h in allHabits) {
      if (h.id == excludeHabitId) continue;
      final hStart = h.startTimeMinutes;
      if (hStart == null) continue;
      final tb = h.timeBound;
      if (tb == null || !tb.enabled || tb.durationMinutes <= 0) continue;

      final hEnd = hStart + tb.durationMinutes;
      occupied.add((hStart, hEnd, h.name));

      if (startMins < hEnd && hStart < newEnd) {
        conflictName = h.name;
      }
    }

    final endTime = TimeOfDay(hour: (newEnd ~/ 60) % 24, minute: newEnd % 60);

    if (conflictName != null) {
      occupied.sort((a, b) => a.$1.compareTo(b.$1));
      final suggested = findNearestAvailable(
        preferredStart: startMins,
        duration: duration,
        occupied: occupied,
      );
      return ConflictResult(
        hasConflict: true,
        conflictingHabitName: conflictName,
        suggestedTime: suggested,
        slotInfo: null,
      );
    } else {
      final startStr = formatTime(startTime);
      final endStr = formatTime(endTime);
      return ConflictResult(
        hasConflict: false,
        conflictingHabitName: null,
        suggestedTime: null,
        slotInfo: '$startStr – $endStr is available',
      );
    }
  }

  static TimeOfDay? findNearestAvailable({
    required int preferredStart,
    required int duration,
    required List<(int, int, String)> occupied,
  }) {
    const maxMins = 24 * 60;
    int? bestStart;
    int bestDist = maxMins;

    bool fits(int cs) {
      if (cs < 0 || cs + duration > maxMins) return false;
      final ce = cs + duration;
      for (final (s, e, _) in occupied) {
        if (cs < e && s < ce) return false;
      }
      return true;
    }

    void tryCandidate(int c) {
      if (!fits(c)) return;
      final dist = (c - preferredStart).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestStart = c;
      }
    }

    tryCandidate(0);
    for (final (_, e, _) in occupied) {
      tryCandidate(e);
    }
    for (final (s, _, _) in occupied) {
      tryCandidate(s - duration);
    }

    if (bestStart == null) return null;
    return TimeOfDay(hour: bestStart! ~/ 60, minute: bestStart! % 60);
  }

  static String formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $p';
  }
}
