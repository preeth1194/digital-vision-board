import 'dart:convert';

import 'package:intl/intl.dart';
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

  /// Load entries filtered by book ID.
  /// If bookId is null, returns all entries (for backward compat).
  /// Entries without a bookId are treated as belonging to the default book.
  static Future<List<JournalEntry>> loadEntriesByBook(
    String? bookId, {
    SharedPreferences? prefs,
  }) async {
    final allEntries = await loadEntries(prefs: prefs);
    if (bookId == null) return allEntries;
    // Entries without bookId belong to default book
    return allEntries.where((e) {
      if (e.bookId == null || e.bookId!.isEmpty) {
        return bookId == 'default_journal';
      }
      return e.bookId == bookId;
    }).toList();
  }

  /// Get entry count for a specific book.
  static Future<int> getEntryCountForBook(
    String bookId, {
    SharedPreferences? prefs,
  }) async {
    final entries = await loadEntriesByBook(bookId, prefs: prefs);
    return entries.length;
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
    String? selectedFont,
    List<Map<String, dynamic>>? imagePositions,
    List<String>? audioPaths,
    String? bookId,
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
    final bookIdNorm = (bookId ?? '').trim().isEmpty ? null : bookId!.trim();
    final entry = JournalEntry(
      id: 'jrnl_$now',
      createdAtMs: now,
      title: titleNorm,
      text: t,
      delta: d.isEmpty ? null : d,
      goalTitle: legacyGoal,
      tags: tagsNorm,
      imagePaths: imagePaths ?? const [],
      selectedFont: selectedFont,
      imagePositions: imagePositions,
      audioPaths: audioPaths ?? const [],
      bookId: bookIdNorm,
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

  static Future<JournalEntry?> updateEntry({
    required String id,
    String? title,
    String? text,
    List<dynamic>? delta,
    List<String>? tags,
    String? goalTitle,
    List<String>? imagePaths,
    String? selectedFont,
    List<Map<String, dynamic>>? imagePositions,
    List<String>? audioPaths,
    String? bookId,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = await loadEntries(prefs: p);
    final entryIndex = existing.indexWhere((e) => e.id == id);
    if (entryIndex == -1) return null;

    final oldEntry = existing[entryIndex];
    final tagsNorm = tags != null
        ? _normalizeTags([
            ...tags,
            if ((goalTitle ?? '').trim().isNotEmpty) goalTitle!.trim(),
          ])
        : oldEntry.tags;
    final legacyGoal = (goalTitle ?? '').trim().isEmpty ? null : goalTitle!.trim();
    final rawTitle = (title ?? '').trim();
    final titleNorm = rawTitle.isEmpty ? null : rawTitle;
    final textNorm = text?.trim() ?? oldEntry.text;
    final deltaNorm = delta ?? oldEntry.delta;
    final imagePathsNorm = imagePaths ?? oldEntry.imagePaths;
    final bookIdNorm = bookId ?? oldEntry.bookId;

    final updatedEntry = JournalEntry(
      id: oldEntry.id,
      createdAtMs: oldEntry.createdAtMs,
      title: titleNorm,
      text: textNorm,
      delta: deltaNorm,
      goalTitle: legacyGoal ?? oldEntry.goalTitle,
      tags: tagsNorm,
      imagePaths: imagePathsNorm,
      selectedFont: selectedFont ?? oldEntry.selectedFont,
      imagePositions: imagePositions ?? oldEntry.imagePositions,
      audioPaths: audioPaths ?? oldEntry.audioPaths,
      bookId: bookIdNorm,
    );

    final updatedEntries = List<JournalEntry>.from(existing);
    updatedEntries[entryIndex] = updatedEntry;
    await saveEntries(updatedEntries, prefs: p);
    return updatedEntry;
  }

  /// Append a daily log to an existing Goal Logs entry for this habit,
  /// or create a new entry if none exists yet.
  ///
  /// Each habit gets exactly one entry (chapter) with ID `goal_log_{habitId}`.
  /// Each completion adds a dated section (page) at the top of the text.
  static Future<JournalEntry?> appendOrCreateGoalLog({
    required String habitId,
    required String habitName,
    required String dayLog,
    required String bookId,
    List<String>? audioPaths,
    List<String>? imagePaths,
    SharedPreferences? prefs,
  }) async {
    final log = dayLog.trim();
    if (log.isEmpty) return null;

    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = await loadEntries(prefs: p);
    final entryId = 'goal_log_$habitId';
    final idx = existing.indexWhere((e) => e.id == entryId);

    final now = DateTime.now();
    final dateLine = '${DateFormat('d MMM, y').format(now)} at ${DateFormat('h:mm a').format(now)}';
    final newPage = '$dateLine\n$log';

    if (idx != -1) {
      final old = existing[idx];
      final oldText = old.text.trim();
      var updatedText = oldText.isEmpty ? newPage : '$newPage\n\n$oldText';

      // Keep only the 7 most recent daily pages
      updatedText = _trimToMaxPages(updatedText, 7);

      final delta = _textToDelta(updatedText);
      _appendMediaEmbeds(delta, audioPaths, imagePaths);
      // Re-append old media embeds that were in the previous delta
      _reappendOldMediaEmbeds(delta, old.delta);

      final mergedAudio = [
        ...?audioPaths,
        ...old.audioPaths,
      ];
      final mergedImages = [
        ...?imagePaths,
        ...old.imagePaths,
      ];
      final updated = JournalEntry(
        id: old.id,
        createdAtMs: old.createdAtMs,
        title: old.title,
        text: updatedText,
        delta: delta,
        goalTitle: old.goalTitle,
        tags: old.tags,
        imagePaths: mergedImages,
        selectedFont: old.selectedFont,
        imagePositions: old.imagePositions,
        audioPaths: mergedAudio,
        bookId: old.bookId,
      );
      final updatedEntries = List<JournalEntry>.from(existing);
      updatedEntries[idx] = updated;
      await saveEntries(updatedEntries, prefs: p);
      return updated;
    } else {
      final delta = _textToDelta(newPage);
      _appendMediaEmbeds(delta, audioPaths, imagePaths);

      final entry = JournalEntry(
        id: entryId,
        createdAtMs: now.millisecondsSinceEpoch,
        title: habitName,
        text: newPage,
        delta: delta,
        goalTitle: null,
        tags: [habitName],
        imagePaths: imagePaths ?? const [],
        audioPaths: audioPaths ?? const [],
        bookId: bookId,
      );
      await saveEntries([entry, ...existing], prefs: p);
      return entry;
    }
  }

  /// Append audio and image embed ops to a delta ops list so the Quill editor
  /// renders them as playable/viewable inline elements.
  static void _appendMediaEmbeds(
    List<Map<String, dynamic>> ops,
    List<String>? audioPaths,
    List<String>? imagePaths,
  ) {
    if ((audioPaths == null || audioPaths.isEmpty) &&
        (imagePaths == null || imagePaths.isEmpty)) return;

    // Spacer line before media
    ops.add(<String, dynamic>{'insert': '\n'});

    for (final path in audioPaths ?? const <String>[]) {
      ops.add(<String, dynamic>{
        'insert': <String, dynamic>{'audio': path},
      });
      ops.add(<String, dynamic>{'insert': '\n'});
    }

    for (final path in imagePaths ?? const <String>[]) {
      final imageData = jsonEncode({'path': path, 'width': 300.0});
      ops.add(<String, dynamic>{
        'insert': <String, dynamic>{'image': imageData},
      });
      ops.add(<String, dynamic>{'insert': '\n'});
    }
  }

  /// Re-append media embeds (audio/image) from a previous delta so they aren't
  /// lost when the text portion is regenerated.
  static void _reappendOldMediaEmbeds(
    List<Map<String, dynamic>> ops,
    List<dynamic>? oldDelta,
  ) {
    if (oldDelta == null) return;
    for (final op in oldDelta) {
      if (op is! Map<String, dynamic>) continue;
      final insert = op['insert'];
      if (insert is Map) {
        if (insert.containsKey('audio') || insert.containsKey('image')) {
          ops.add(Map<String, dynamic>.from(op));
          ops.add(<String, dynamic>{'insert': '\n'});
        }
      }
    }
  }

  /// Convert plain text to a Quill Delta ops list with bullet-journal styling.
  ///
  /// Date header lines (e.g. "17 Feb, 2026 at 3:07 PM") are split into:
  ///   - Large day number as H1 header
  ///   - Month/year/time as subtitle
  ///   - A horizontal divider line
  static List<Map<String, dynamic>> _textToDelta(String text) {
    final ops = <Map<String, dynamic>>[];
    final lines = text.split('\n');
    // Date header: "17 Feb, 2026 at 3:07 PM"
    final datePattern = RegExp(
      r'^(\d{1,2}) (\w{3}), (\d{4}) at (\d{1,2}:\d{2} [AP]M)$',
    );
    var isFirstPage = true;

    for (final line in lines) {
      final match = datePattern.firstMatch(line);
      if (match != null) {
        // Blank line separator between daily pages (not before the first)
        if (!isFirstPage) {
          ops.add(<String, dynamic>{'insert': '\n'});
        }
        isFirstPage = false;

        final day = match.group(1)!;
        final month = match.group(2)!;
        final year = match.group(3)!;
        final time = match.group(4)!;

        // Day number as H1 header
        ops.add(<String, dynamic>{'insert': day});
        ops.add(<String, dynamic>{
          'insert': '\n',
          'attributes': <String, dynamic>{'header': 1},
        });

        // Month, year, time as subtitle
        ops.add(<String, dynamic>{
          'insert': '$month $year \u00B7 $time',
          'attributes': <String, dynamic>{
            'italic': true,
            'color': '#888888',
          },
        });
        ops.add(<String, dynamic>{'insert': '\n'});
      } else if (line.isEmpty) {
        // Preserve blank lines
        ops.add(<String, dynamic>{'insert': '\n'});
      } else {
        ops.add(<String, dynamic>{'insert': '$line\n'});
      }
    }

    if (ops.isEmpty) {
      ops.add(<String, dynamic>{'insert': '\n'});
    }

    return ops;
  }

  /// Split text into daily page blocks by date headers and keep only
  /// the [max] most recent ones (newest first).
  static String _trimToMaxPages(String text, int max) {
    final datePattern = RegExp(
      r'\d{1,2} \w{3}, \d{4} at \d{1,2}:\d{2} [AP]M',
    );

    // Split on blank-line boundaries that precede a date header
    final pages = <String>[];
    final buffer = StringBuffer();

    for (final line in text.split('\n')) {
      if (datePattern.hasMatch(line) && buffer.isNotEmpty) {
        // A new date header starts a new page; flush the previous one
        final page = buffer.toString().trim();
        if (page.isNotEmpty) pages.add(page);
        buffer.clear();
      }
      buffer.writeln(line);
    }
    // Flush the last page
    final last = buffer.toString().trim();
    if (last.isNotEmpty) pages.add(last);

    if (pages.length <= max) return text;

    return pages.take(max).join('\n\n');
  }
}

