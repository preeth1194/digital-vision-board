import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mood_entry.dart';

class MoodStorageService {
  MoodStorageService._();

  static const String _key = 'dv_mood_entries_v1';

  static Future<List<MoodEntry>> loadAll({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(MoodEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(
    List<MoodEntry> entries, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Upsert: one mood entry per calendar day.
  static Future<void> saveMood(
    MoodEntry entry, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    final idx = all.indexWhere((e) => e.dateKey == entry.dateKey);
    if (idx != -1) {
      all[idx] = entry;
    } else {
      all.add(entry);
    }
    await _saveAll(all, prefs: p);
  }

  /// Returns mood entries for the 7-day window starting at [weekStart].
  static Future<List<MoodEntry>> getMoodsForWeek(
    DateTime weekStart, {
    SharedPreferences? prefs,
  }) async {
    final all = await loadAll(prefs: prefs);
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return all.where((e) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();
  }

  /// Returns mood entries within [start, end) (inclusive start, exclusive end).
  static Future<List<MoodEntry>> getMoodsForRange(
    DateTime start,
    DateTime end, {
    SharedPreferences? prefs,
  }) async {
    final all = await loadAll(prefs: prefs);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return all.where((entry) {
      final d = DateTime(entry.date.year, entry.date.month, entry.date.day);
      return !d.isBefore(s) && d.isBefore(e);
    }).toList();
  }

  /// Total number of mood check-ins ever recorded.
  static Future<int> totalCheckIns({SharedPreferences? prefs}) async {
    final all = await loadAll(prefs: prefs);
    return all.length;
  }
}
