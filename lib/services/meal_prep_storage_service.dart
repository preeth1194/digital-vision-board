import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/meal_prep_week.dart';

class MealPrepStorageService {
  MealPrepStorageService._();

  static const _key = 'dv_meal_prep_weeks_v1';

  static Future<List<MealPrepWeek>> loadAll({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(MealPrepWeek.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(
    List<MealPrepWeek> weeks, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_key, jsonEncode(weeks.map((e) => e.toJson()).toList()));
  }

  static Future<void> upsertWeek(
    MealPrepWeek week, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    final idx = all.indexWhere((e) => e.id == week.id);
    final next = week.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (idx >= 0) {
      all[idx] = next;
    } else {
      all.add(next);
    }
    await saveAll(all, prefs: p);
  }
}
