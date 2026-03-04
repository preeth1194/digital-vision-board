import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe.dart';

class RecipeStorageService {
  RecipeStorageService._();

  static const _key = 'dv_recipes_v1';

  static Future<List<Recipe>> loadAll({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAtMs.compareTo(a.updatedAtMs));
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(
    List<Recipe> recipes, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode(recipes.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> upsertRecipe(
    Recipe recipe, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    final idx = all.indexWhere((e) => e.id == recipe.id);
    final next = recipe.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (idx >= 0) {
      all[idx] = next;
    } else {
      all.add(next);
    }
    await saveAll(all, prefs: p);
  }

  static Future<void> deleteRecipe(
    String id, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    all.removeWhere((e) => e.id == id);
    await saveAll(all, prefs: p);
  }
}
