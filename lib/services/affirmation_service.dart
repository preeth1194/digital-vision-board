import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/affirmation.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import 'boards_storage_service.dart';
import 'grid_tiles_storage_service.dart';
import 'habit_storage_service.dart';
import 'vision_board_components_storage_service.dart';

/// Local-only affirmation storage. Backed up via encrypted Google Drive backup.
final class AffirmationService {
  AffirmationService._();

  static const String _localStorageKey = 'dv_affirmations_v1';

  static Future<List<Affirmation>> getAffirmationsByCategory({
    String? category,
    SharedPreferences? prefs,
  }) async {
    return _loadLocalAffirmations(prefs: prefs, category: category);
  }

  static Future<List<Affirmation>> getAllAffirmations({
    SharedPreferences? prefs,
  }) async {
    return _loadLocalAffirmations(prefs: prefs);
  }

  static Future<String> addAffirmation(
    Affirmation affirmation, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final id = affirmation.id.isEmpty
        ? DateTime.now().millisecondsSinceEpoch.toString()
        : affirmation.id;
    final updated = affirmation.copyWith(id: id);
    final all = await _loadLocalAffirmations(prefs: p);
    all.add(updated);
    await _saveLocalAffirmations(all, prefs: p);
    return id;
  }

  static Future<bool> updateAffirmation(
    Affirmation affirmation, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await _loadLocalAffirmations(prefs: p);
    final index = all.indexWhere((a) => a.id == affirmation.id);
    if (index >= 0) {
      all[index] = affirmation;
      await _saveLocalAffirmations(all, prefs: p);
      return true;
    }
    return false;
  }

  static Future<bool> deleteAffirmation(
    String id, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await _loadLocalAffirmations(prefs: p);
    all.removeWhere((a) => a.id == id);
    await _saveLocalAffirmations(all, prefs: p);
    return true;
  }

  static Future<bool> pinAffirmation(
    String id,
    bool isPinned, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await _loadLocalAffirmations(prefs: p);
    final index = all.indexWhere((a) => a.id == id);
    if (index >= 0) {
      all[index] = all[index].copyWith(isPinned: isPinned);
      await _saveLocalAffirmations(all, prefs: p);
      return true;
    }
    return false;
  }

  static Future<List<String>> getCategoriesFromBoards({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: p);
    final allHabits = await HabitStorageService.loadAll(prefs: p);
    final categories = <String>{};

    for (final board in boards) {
      List<VisionComponent> components;
      if (board.layoutType == VisionBoardInfo.layoutGrid) {
        final tiles =
            await GridTilesStorageService.loadTiles(board.id, prefs: p);
        components = tiles
            .where((t) => t.type == 'image' && t.goal != null)
            .map((t) => ImageComponent(
                  id: t.id,
                  position: Offset.zero,
                  size: const Size(1, 1),
                  rotation: 0,
                  scale: 1,
                  zIndex: 0,
                  imagePath: t.content ?? '',
                  goal: t.goal,
                  habits:
                      allHabits.where((h) => h.componentId == t.id).toList(),
                ))
            .toList();
      } else {
        components =
            await VisionBoardComponentsStorageService.loadComponents(
                board.id,
                prefs: p);
      }

      for (final component in components) {
        if (component is ImageComponent) {
          final category = component.goal?.category;
          if (category != null && category.trim().isNotEmpty) {
            categories.add(category.trim());
          }
        }
      }
    }

    final sorted = categories.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static Future<List<Affirmation>> _loadLocalAffirmations({
    SharedPreferences? prefs,
    String? category,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_localStorageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final all = decoded
          .whereType<Map<String, dynamic>>()
          .map((json) => Affirmation.fromJson(json))
          .toList();

      if (category != null) {
        return all
            .where((a) => a.category == category || a.category == null)
            .toList();
      }
      return all;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocalAffirmations(
    List<Affirmation> affirmations, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _localStorageKey,
      jsonEncode(affirmations.map((a) => a.toJson()).toList()),
    );
  }
}
