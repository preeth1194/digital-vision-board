import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/affirmation.dart';
import '../models/vision_board_info.dart';
import '../models/vision_components.dart';
import 'boards_storage_service.dart';
import 'dv_auth_service.dart';
import 'grid_tiles_storage_service.dart';
import 'habit_storage_service.dart';
import 'vision_board_components_storage_service.dart';

/// Service for managing affirmations with backend sync and local storage fallback
final class AffirmationService {
  AffirmationService._();

  static const String _localStorageKey = 'dv_affirmations_v1';
  static const String _lastSyncKey = 'dv_affirmations_last_sync_v1';

  static Uri _url(String path) => Uri.parse('${DvAuthService.backendBaseUrl()}$path');

  /// Get affirmations, optionally filtered by category
  static Future<List<Affirmation>> getAffirmationsByCategory({
    String? category,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    
    // Try backend first if authenticated
    if (token != null) {
      try {
        final queryParams = category != null ? '?category=${Uri.encodeComponent(category)}' : '';
        final res = await http.get(
          _url('/api/affirmations$queryParams'),
          headers: {'Authorization': 'Bearer $token'},
        );
        
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final affirmationsRaw = decoded['affirmations'] as List<dynamic>?;
          if (affirmationsRaw != null) {
            final affirmations = affirmationsRaw
                .whereType<Map<String, dynamic>>()
                .map((json) => Affirmation.fromJson(json))
                .toList();
            // Cache locally
            await _saveLocalAffirmations(affirmations, prefs: p);
            return affirmations;
          }
        }
      } catch (e) {
        // Fall through to local storage
      }
    }
    
    // Fallback to local storage
    return _loadLocalAffirmations(prefs: p, category: category);
  }

  /// Get all affirmations
  static Future<List<Affirmation>> getAllAffirmations({SharedPreferences? prefs}) async {
    return getAffirmationsByCategory(category: null, prefs: prefs);
  }

  /// Add a new affirmation
  static Future<String> addAffirmation(
    Affirmation affirmation, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    
    // Try backend first if authenticated
    if (token != null) {
      try {
        final res = await http.post(
          _url('/api/affirmations'),
          headers: {
            'Authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(affirmation.toJson()),
        );
        
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body) as Map<String, dynamic>;
          final id = decoded['id'] as String?;
          if (id != null) {
            // Refresh local cache
            await getAffirmationsByCategory(prefs: p);
            return id;
          }
        }
      } catch (e) {
        // Fall through to local storage
      }
    }
    
    // Fallback to local storage
    final id = affirmation.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : affirmation.id;
    final updated = affirmation.copyWith(id: id);
    final all = await _loadLocalAffirmations(prefs: p);
    all.add(updated);
    await _saveLocalAffirmations(all, prefs: p);
    return id;
  }

  /// Update an existing affirmation
  static Future<bool> updateAffirmation(
    Affirmation affirmation, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    
    // Try backend first if authenticated
    if (token != null) {
      try {
        final res = await http.put(
          _url('/api/affirmations/${affirmation.id}'),
          headers: {
            'Authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(affirmation.toJson()),
        );
        
        if (res.statusCode == 200) {
          // Refresh local cache
          await getAffirmationsByCategory(prefs: p);
          return true;
        }
      } catch (e) {
        // Fall through to local storage
      }
    }
    
    // Fallback to local storage
    final all = await _loadLocalAffirmations(prefs: p);
    final index = all.indexWhere((a) => a.id == affirmation.id);
    if (index >= 0) {
      all[index] = affirmation;
      await _saveLocalAffirmations(all, prefs: p);
      return true;
    }
    return false;
  }

  /// Delete an affirmation
  static Future<bool> deleteAffirmation(
    String id, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    
    // Try backend first if authenticated
    if (token != null) {
      try {
        final res = await http.delete(
          _url('/api/affirmations/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );
        
        if (res.statusCode == 200) {
          // Refresh local cache
          await getAffirmationsByCategory(prefs: p);
          return true;
        }
      } catch (e) {
        // Fall through to local storage
      }
    }
    
    // Fallback to local storage
    final all = await _loadLocalAffirmations(prefs: p);
    all.removeWhere((a) => a.id == id);
    await _saveLocalAffirmations(all, prefs: p);
    return true;
  }

  /// Pin or unpin an affirmation
  static Future<bool> pinAffirmation(
    String id,
    bool isPinned, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final token = await DvAuthService.getDvToken(prefs: p);
    
    // Try backend first if authenticated
    if (token != null) {
      try {
        final res = await http.put(
          _url('/api/affirmations/$id/pin'),
          headers: {
            'Authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({'is_pinned': isPinned}),
        );
        
        if (res.statusCode == 200) {
          // Refresh local cache
          await getAffirmationsByCategory(prefs: p);
          return true;
        }
      } catch (e) {
        // Fall through to local storage
      }
    }
    
    // Fallback to local storage
    final all = await _loadLocalAffirmations(prefs: p);
    final index = all.indexWhere((a) => a.id == id);
    if (index >= 0) {
      all[index] = all[index].copyWith(isPinned: isPinned);
      await _saveLocalAffirmations(all, prefs: p);
      return true;
    }
    return false;
  }

  /// Extract unique categories from all vision boards
  static Future<List<String>> getCategoriesFromBoards({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final boards = await BoardsStorageService.loadBoards(prefs: p);
    final allHabits = await HabitStorageService.loadAll(prefs: p);
    final categories = <String>{};
    
    for (final board in boards) {
      List<VisionComponent> components;
      if (board.layoutType == VisionBoardInfo.layoutGrid) {
        final tiles = await GridTilesStorageService.loadTiles(board.id, prefs: p);
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
                  habits: allHabits.where((h) => h.componentId == t.id).toList(),
                ))
            .toList();
      } else {
        components = await VisionBoardComponentsStorageService.loadComponents(board.id, prefs: p);
      }
      
      for (final component in components) {
        if (component is ImageComponent) {
          final goal = component.goal;
          final category = goal?.category;
          if (category != null && category.trim().isNotEmpty) {
            categories.add(category.trim());
          }
        }
      }
    }
    
    final sorted = categories.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Load affirmations from local storage
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
        return all.where((a) => a.category == category || a.category == null).toList();
      }
      return all;
    } catch (_) {
      return [];
    }
  }

  /// Save affirmations to local storage
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
