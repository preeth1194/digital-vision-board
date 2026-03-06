import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/skincare_planner.dart';

class SkincarePlannerStorageService {
  SkincarePlannerStorageService._();

  static const _key = 'dv_skincare_planner_v1';

  static Future<SkincarePlanner> loadOrDefault({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      final seeded = SkincarePlanner.defaultSeed();
      await save(seeded, prefs: p);
      return seeded;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return SkincarePlanner.fromJson(decoded);
      }
    } catch (_) {}
    final seeded = SkincarePlanner.defaultSeed();
    await save(seeded, prefs: p);
    return seeded;
  }

  static Future<void> save(
    SkincarePlanner planner, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final next = planner.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await p.setString(_key, jsonEncode(next.toJson()));
  }
}
