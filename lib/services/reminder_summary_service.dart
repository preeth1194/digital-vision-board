import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit_item.dart';
import '../models/vision_board_info.dart';
import 'habit_storage_service.dart';

enum ReminderKind { habit }

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
  final Map<String, List<ReminderItem>> itemsByIsoDate;

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
    if (!hasWeeklySchedule) return true;
    return habit.weeklyDays.contains(date.weekday);
  }

  static Future<ReminderSummary> build({
    required List<VisionBoardInfo> boards,
    required SharedPreferences prefs,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final today = _dateOnly(current);
    final end = _endOfMonth(today);
    final nowMinutes = (current.hour * 60) + current.minute;

    final itemsByIso = <String, List<ReminderItem>>{};
    int todayPending = 0;

    final allHabits = await HabitStorageService.loadAll(prefs: prefs);

    for (final h in allHabits) {
      if (!h.reminderEnabled || h.reminderMinutes == null) continue;
      final boardTitle = boards
          .cast<VisionBoardInfo?>()
          .firstWhere((b) => b?.id == h.boardId, orElse: () => null)
          ?.title ?? '';
      for (DateTime d = today; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        if (!_isHabitScheduledOnDate(h, d)) continue;
        if (h.isCompletedForCurrentPeriod(d)) continue;
        if (d == today && h.reminderMinutes! <= nowMinutes) continue;

        final item = ReminderItem(
          kind: ReminderKind.habit,
          date: d,
          minutesSinceMidnight: h.reminderMinutes,
          boardId: h.boardId ?? '',
          boardTitle: boardTitle,
          label: h.name,
        );
        (itemsByIso[item.isoDate] ??= []).add(item);
        if (d == today) todayPending++;
      }
    }

    for (final entry in itemsByIso.entries) {
      entry.value.sort((a, b) {
        final am = a.minutesSinceMidnight ?? 999999;
        final bm = b.minutesSinceMidnight ?? 999999;
        if (am != bm) return am.compareTo(bm);
        if (a.kind != b.kind) return a.kind.index.compareTo(b.kind.index);
        return a.label.compareTo(b.label);
      });
    }

    return ReminderSummary(todayPendingCount: todayPending, itemsByIsoDate: itemsByIso);
  }
}
