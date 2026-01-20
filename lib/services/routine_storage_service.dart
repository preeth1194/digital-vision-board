import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/routine.dart';

class RoutineStorageService {
  RoutineStorageService._();

  static const String routinesKey = 'routines_list_v1';
  static const String activeRoutineIdKey = 'active_routine_id_v1';

  static Future<List<Routine>> loadRoutines({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(routinesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Routine.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveRoutines(
    List<Routine> routines, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      routinesKey,
      jsonEncode(routines.map((r) => r.toJson()).toList()),
    );
  }

  static Future<String?> loadActiveRoutineId({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getString(activeRoutineIdKey);
  }

  static Future<void> setActiveRoutineId(
    String routineId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(activeRoutineIdKey, routineId);
  }

  static Future<void> clearActiveRoutineId({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(activeRoutineIdKey);
  }

  static Future<void> deleteRoutineData(
    String routineId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    // For now, routines only store the main data in the list
    // If we add additional data keys later, remove them here
  }
}
