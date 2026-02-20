import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/challenge.dart';

/// Persistence layer for [Challenge] records using SharedPreferences.
class ChallengeStorageService {
  ChallengeStorageService._();

  static const String _key = 'dv_challenges_v1';
  static const String _activeChallengeIdKey = 'dv_active_challenge_id_v1';

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  static Future<List<Challenge>> loadAll({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Challenge.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAll(
    List<Challenge> challenges, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode(challenges.map((c) => c.toJson()).toList()),
    );
  }

  static Future<Challenge> addChallenge(
    Challenge challenge, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    all.add(challenge);
    await saveAll(all, prefs: p);
    return challenge;
  }

  static Future<void> updateChallenge(
    Challenge challenge, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    final idx = all.indexWhere((c) => c.id == challenge.id);
    if (idx != -1) {
      all[idx] = challenge;
    } else {
      all.add(challenge);
    }
    await saveAll(all, prefs: p);
  }

  static Future<void> deleteChallenge(
    String id, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final all = await loadAll(prefs: p);
    all.removeWhere((c) => c.id == id);
    await saveAll(all, prefs: p);
  }

  // ---------------------------------------------------------------------------
  // Active challenge
  // ---------------------------------------------------------------------------

  static Future<String?> loadActiveChallengeId({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    return p.getString(_activeChallengeIdKey);
  }

  static Future<void> setActiveChallengeId(
    String challengeId, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(_activeChallengeIdKey, challengeId);
  }

  static Future<void> clearActiveChallengeId({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.remove(_activeChallengeIdKey);
  }

  // ---------------------------------------------------------------------------
  // Lookup helpers
  // ---------------------------------------------------------------------------

  static Future<Challenge?> getActiveChallenge({
    SharedPreferences? prefs,
  }) async {
    final activeId = await loadActiveChallengeId(prefs: prefs);
    if (activeId == null) return null;
    final all = await loadAll(prefs: prefs);
    return all.cast<Challenge?>().firstWhere(
          (c) => c?.id == activeId,
          orElse: () => null,
        );
  }

  static Future<List<Challenge>> getActiveChallenges({
    SharedPreferences? prefs,
  }) async {
    final all = await loadAll(prefs: prefs);
    return all.where((c) => c.isActive).toList();
  }
}
