import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/calorie_entry.dart';

class CalorieStorageService {
  CalorieStorageService._();

  static const String _key = 'dv_calorie_entries_v1';

  static Future<List<CalorieEntry>> loadAll({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(CalorieEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns today's entry, or a fresh one with 0 calories if none exists.
  static Future<CalorieEntry> loadToday({
    SharedPreferences? prefs,
  }) async {
    final dateKey = CalorieEntry.todayKey();
    final all = await loadAll(prefs: prefs);
    return all.firstWhere(
      (e) => e.dateKey == dateKey,
      orElse: () => CalorieEntry(dateKey: dateKey, calories: 0),
    );
  }

  static Future<void> save(
    CalorieEntry entry, {
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
    await p.setString(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  /// Adds [amount] calories to today's entry (clamped to [0, goal * 3]).
  static Future<CalorieEntry> addCalories(
    int amount, {
    SharedPreferences? prefs,
  }) async {
    final today = await loadToday(prefs: prefs);
    final updated = today.copyWith(
      calories: (today.calories + amount).clamp(0, today.goal * 3),
    );
    await save(updated, prefs: prefs);
    return updated;
  }

  /// Resets today's calorie count to 0.
  static Future<CalorieEntry> resetToday({SharedPreferences? prefs}) async {
    final today = await loadToday(prefs: prefs);
    final updated = today.copyWith(calories: 0);
    await save(updated, prefs: prefs);
    return updated;
  }

  /// Updates only the daily calorie goal.
  static Future<CalorieEntry> updateGoal(
    int goal, {
    SharedPreferences? prefs,
  }) async {
    final today = await loadToday(prefs: prefs);
    final updated = today.copyWith(goal: goal.clamp(500, 10000));
    await save(updated, prefs: prefs);
    return updated;
  }
}
