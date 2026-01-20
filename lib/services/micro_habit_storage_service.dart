import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for storing and retrieving selected micro habits per day.
final class MicroHabitStorageService {
  MicroHabitStorageService._();

  static const String _key = 'dv_micro_habit_selections_v1';

  /// Load the selected micro habit for a given date (ISO format: YYYY-MM-DD).
  /// Returns null if no micro habit is selected for that date.
  static Future<String?> loadSelectedMicroHabit(String isoDate, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map[isoDate] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Save the selected micro habit for a given date (ISO format: YYYY-MM-DD).
  static Future<void> saveSelectedMicroHabit(String isoDate, String microHabit, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    Map<String, dynamic> map;
    if (raw == null || raw.isEmpty) {
      map = {};
    } else {
      try {
        map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        map = {};
      }
    }
    map[isoDate] = microHabit;
    await p.setString(_key, jsonEncode(map));
  }

  /// Clear the selected micro habit for a given date.
  static Future<void> clearSelectedMicroHabit(String isoDate, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      map.remove(isoDate);
      await p.setString(_key, jsonEncode(map));
    } catch (_) {
      // Ignore errors
    }
  }

  /// Check if a micro habit is completed for a given date.
  /// Returns true if the micro habit was completed (stored with completion flag).
  static Future<bool> isMicroHabitCompleted(String isoDate, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString('${_key}_completions');
    if (raw == null || raw.isEmpty) return false;
    try {
      final set = Set<String>.from(jsonDecode(raw) as List);
      return set.contains(isoDate);
    } catch (_) {
      return false;
    }
  }

  /// Mark a micro habit as completed for a given date.
  static Future<void> markMicroHabitCompleted(String isoDate, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString('${_key}_completions');
    Set<String> set;
    if (raw == null || raw.isEmpty) {
      set = {};
    } else {
      try {
        set = Set<String>.from(jsonDecode(raw) as List);
      } catch (_) {
        set = {};
      }
    }
    set.add(isoDate);
    await p.setString('${_key}_completions', jsonEncode(set.toList()));
  }

  /// Unmark a micro habit as completed for a given date.
  static Future<void> unmarkMicroHabitCompleted(String isoDate, {SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString('${_key}_completions');
    if (raw == null || raw.isEmpty) return;
    try {
      final set = Set<String>.from(jsonDecode(raw) as List);
      set.remove(isoDate);
      await p.setString('${_key}_completions', jsonEncode(set.toList()));
    } catch (_) {
      // Ignore errors
    }
  }
}
