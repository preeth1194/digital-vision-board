import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/journal_book.dart';

/// Service for persisting and retrieving journal books.
final class JournalBookStorageService {
  JournalBookStorageService._();

  static const String _key = 'dv_journal_books_v1';

  /// Default book ID for entries without a book association.
  static const String defaultBookId = 'default_journal';

  /// Book ID for the auto-created, non-deletable "Goal Logs" book.
  static const String goalLogsBookId = 'goal_logs';

  /// Load all books from storage. Returns empty list if none exist.
  static Future<List<JournalBook>> loadBooks({SharedPreferences? prefs}) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return const <JournalBook>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <JournalBook>[];
      final items = decoded
          .whereType<Map<String, dynamic>>()
          .map(JournalBook.fromJson)
          .where((b) => b.id.trim().isNotEmpty && b.name.trim().isNotEmpty)
          .toList();
      items.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
      return items;
    } catch (_) {
      return const <JournalBook>[];
    }
  }

  /// Save books list to storage.
  static Future<void> saveBooks(
    List<JournalBook> books, {
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final normalized = books
        .where((b) => b.id.trim().isNotEmpty && b.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    await p.setString(_key, jsonEncode(normalized.map((b) => b.toJson()).toList()));
  }

  /// Create a new book with the given name.
  /// Returns the created book, or null if name is empty.
  static Future<JournalBook?> addBook({
    required String name,
    String? subtitle,
    int? iconCodePoint,
    int? coverColor,
    String? coverImagePath,
    SharedPreferences? prefs,
  }) async {
    final n = name.trim();
    if (n.isEmpty) return null;
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = await loadBooks(prefs: p);
    final now = DateTime.now().millisecondsSinceEpoch;
    final book = JournalBook(
      id: 'book_$now',
      name: n,
      createdAtMs: now,
      iconCodePoint: iconCodePoint,
      subtitle: subtitle,
      coverColor: coverColor ?? JournalBook.defaultCoverColor,
      coverImagePath: coverImagePath,
    );
    await saveBooks([...existing, book], prefs: p);
    return book;
  }

  /// Delete a book by ID. The Goal Logs book cannot be deleted.
  static Future<void> deleteBook(
    String id, {
    SharedPreferences? prefs,
  }) async {
    if (id == goalLogsBookId) return;
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = await loadBooks(prefs: p);
    final next = existing.where((b) => b.id != id).toList();
    await saveBooks(next, prefs: p);
  }

  /// Update an existing book.
  /// Returns the updated book, or null if not found.
  static Future<JournalBook?> updateBook({
    required String id,
    String? name,
    String? subtitle,
    int? iconCodePoint,
    int? coverColor,
    String? coverImagePath,
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final existing = await loadBooks(prefs: p);
    final idx = existing.indexWhere((b) => b.id == id);
    if (idx == -1) return null;

    final old = existing[idx];
    final updated = old.copyWith(
      name: name ?? old.name,
      subtitle: subtitle ?? old.subtitle,
      iconCodePoint: iconCodePoint ?? old.iconCodePoint,
      coverColor: coverColor ?? old.coverColor,
      coverImagePath: coverImagePath ?? old.coverImagePath,
    );
    final updatedList = List<JournalBook>.from(existing);
    updatedList[idx] = updated;
    await saveBooks(updatedList, prefs: p);
    return updated;
  }

  /// Ensure default books exist (Journal + Goal Logs).
  /// Returns the list of books (with defaults created if needed).
  static Future<List<JournalBook>> ensureDefaultBook({
    SharedPreferences? prefs,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    var books = await loadBooks(prefs: p);
    var changed = false;

    if (books.isEmpty) {
      final defaultBook = JournalBook(
        id: defaultBookId,
        name: 'Journal',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        subtitle: 'written by you',
        coverColor: JournalBook.defaultCoverColor,
      );
      books = [defaultBook];
      changed = true;
    }

    if (!books.any((b) => b.id == goalLogsBookId)) {
      final goalLogsBook = JournalBook(
        id: goalLogsBookId,
        name: 'Goal Logs',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        subtitle: 'habit completions',
        coverColor: 0xFFAED581, // Light Green
      );
      books = [...books, goalLogsBook];
      changed = true;
    }

    if (changed) {
      await saveBooks(books, prefs: p);
    }
    return books;
  }
}
