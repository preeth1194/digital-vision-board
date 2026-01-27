import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/journal_entry.dart';

final class JournalStorageService {
  JournalStorageService._();

  static const String _key = 'dv_journal_entries_v1';
  static List<String> _normalizeTags(Iterable<dynamic> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final x in raw) {
      final s = (x is String) ? x.trim() : '';
      if (s.isEmpty) continue;
      if (seen.add(s)) out.add(s);
    }
    return out;
  }

  static Future<List<JournalEntry>> loadEntries({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const <JournalEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <JournalEntry>[];
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(JournalEntry.fromJson)
          .where((e) => e.id.trim().isNotEmpty && (e.text.trim().isNotEmpty || (e.delta ?? const []).isNotEmpty))
          .toList();
      items.sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
      return items;
    } catch (_) {
      return const <JournalEntry>[];
    }
  }

  static Future<void> saveEntries(
    List<JournalEntry> entries, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final normalized = entries
        .where((e) => e.id.trim().isNotEmpty && (e.text.trim().isNotEmpty || (e.delta ?? const []).isNotEmpty))
        .toList()
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    await p.setString(_key, jsonEncode(normalized.map((e) => e.toJson()).toList()));
  }

  static Future<JournalEntry?> addEntry({
    required String text,
    String? title,
    List<dynamic>? delta,
    List<String>? tags,
    String? goalTitle, // legacy; kept for backwards compatibility
    List<String>? imagePaths,
    SharedPreferences? prefs,
  }) async {
    final t = text.trim();
    final d = (delta ?? const []).where((x) => x != null).toList();
    if (t.isEmpty && d.isEmpty) return null;
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = await loadEntries(prefs: p);
    final now = DateTime.now().millisecondsSinceEpoch;
    final tagsNorm = _normalizeTags([
      ...?tags,
      if ((goalTitle ?? '').trim().isNotEmpty) goalTitle!.trim(),
    ]);
    final legacyGoal = (goalTitle ?? '').trim().isEmpty ? null : goalTitle!.trim();
    final rawTitle = (title ?? '').trim();
    final titleNorm = rawTitle.isEmpty ? null : rawTitle;
    final entry = JournalEntry(
      id: 'jrnl_$now',
      createdAtMs: now,
      title: titleNorm,
      text: t,
      delta: d.isEmpty ? null : d,
      goalTitle: legacyGoal,
      tags: tagsNorm,
      imagePaths: imagePaths ?? const [],
    );
    await saveEntries([entry, ...existing], prefs: p);
    return entry;
  }

  static Future<void> deleteEntry(
    String id, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = await loadEntries(prefs: p);
    final next = existing.where((e) => e.id != id).toList();
    await saveEntries(next, prefs: p);
  }
}

