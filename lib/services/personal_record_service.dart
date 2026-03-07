import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/personal_record.dart';

/// Persists personal-best lift records and a rolling history log.
///
/// Storage layout (SharedPreferences):
///   [_bestsKey]   → JSON object: { exerciseKey → PersonalRecord }
///   [_historyKey] → JSON array:  [ PersonalRecord, ... ] (newest-first, capped at 200)
class PersonalRecordService {
  PersonalRecordService._();

  static const String _bestsKey = 'dv_pr_bests';
  static const String _historyKey = 'dv_pr_history';
  static const int _historyLimit = 200;

  // ── Bests ──────────────────────────────────────────────────────────────────

  /// All current personal bests keyed by [PersonalRecord.exerciseKey].
  static Future<Map<String, PersonalRecord>> getAllBests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bestsKey);
    if (raw == null || raw.isEmpty) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map(
      (k, v) => MapEntry(k, PersonalRecord.fromJson(v as Map<String, dynamic>)),
    );
  }

  /// The current best for [exerciseKey], or null if never logged.
  static Future<PersonalRecord?> getBest(String exerciseKey) async {
    final bests = await getAllBests();
    return bests[PersonalRecord.normalizeKey(exerciseKey)];
  }

  // ── History ────────────────────────────────────────────────────────────────

  /// All logged entries, newest first (up to [_historyLimit]).
  static Future<List<PersonalRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PersonalRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// History for a specific exercise, newest first.
  static Future<List<PersonalRecord>> getHistoryForExercise(
    String exerciseKey,
  ) async {
    final key = PersonalRecord.normalizeKey(exerciseKey);
    final all = await getHistory();
    return all.where((r) => r.exerciseKey == key).toList();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Saves [record] to history and updates the personal best if it's better.
  ///
  /// Returns true if [record] is a new personal best.
  static Future<bool> saveRecord(PersonalRecord record) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Append to history (cap at limit)
    final history = await getHistory();
    final newHistory = [record, ...history].take(_historyLimit).toList();
    await prefs.setString(
      _historyKey,
      jsonEncode(newHistory.map((r) => r.toJson()).toList()),
    );

    // 2. Check and update personal best
    final bests = await getAllBests();
    final existing = bests[record.exerciseKey];
    final isNewBest = existing == null || record.isBetterThan(existing);
    if (isNewBest) {
      bests[record.exerciseKey] = record;
      await prefs.setString(
        _bestsKey,
        jsonEncode(bests.map((k, v) => MapEntry(k, v.toJson()))),
      );
    }
    return isNewBest;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Removes all PR data for [exerciseKey] (bests + history entries).
  static Future<void> deleteExercise(String exerciseKey) async {
    final prefs = await SharedPreferences.getInstance();
    final key = PersonalRecord.normalizeKey(exerciseKey);

    final bests = await getAllBests()..remove(key);
    await prefs.setString(
      _bestsKey,
      jsonEncode(bests.map((k, v) => MapEntry(k, v.toJson()))),
    );

    final history = (await getHistory()).where((r) => r.exerciseKey != key).toList();
    await prefs.setString(
      _historyKey,
      jsonEncode(history.map((r) => r.toJson()).toList()),
    );
  }

  /// Clears all personal records. Use with caution.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_bestsKey),
      prefs.remove(_historyKey),
    ]);
  }
}
