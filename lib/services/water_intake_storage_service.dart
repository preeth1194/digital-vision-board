import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/water_intake_entry.dart';

class WaterIntakeStorageService {
  WaterIntakeStorageService._();

  static const String _key = 'dv_water_intake_v1';

  static Future<List<WaterIntakeEntry>> loadAll({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(WaterIntakeEntry.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns today's entry, or a fresh one with 0 glasses if none exists.
  static Future<WaterIntakeEntry> loadToday({
    SharedPreferences? prefs,
  }) async {
    final dateKey = WaterIntakeEntry.todayKey();
    final all = await loadAll(prefs: prefs);
    return all.firstWhere(
      (e) => e.dateKey == dateKey,
      orElse: () => WaterIntakeEntry(dateKey: dateKey, glasses: 0),
    );
  }

  static Future<void> save(
    WaterIntakeEntry entry, {
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

  /// Increments today's glass count by [delta] (can be negative), clamped to [0, goal].
  static Future<WaterIntakeEntry> addGlass(
    int delta, {
    SharedPreferences? prefs,
  }) async {
    final today = await loadToday(prefs: prefs);
    final updated = today.copyWith(
      glasses: (today.glasses + delta).clamp(0, today.goal),
    );
    await save(updated, prefs: prefs);
    return updated;
  }

  /// Updates only the daily goal for today's entry.
  static Future<WaterIntakeEntry> updateGoal(
    int goal, {
    SharedPreferences? prefs,
  }) async {
    final today = await loadToday(prefs: prefs);
    final updated = today.copyWith(goal: goal.clamp(1, 30));
    await save(updated, prefs: prefs);
    return updated;
  }
}
