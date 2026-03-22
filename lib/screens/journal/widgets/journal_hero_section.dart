import 'package:flutter/material.dart';

import '../../../models/journal_book.dart';
import 'journal_bookshelf.dart';

/// Simplified hero section showing a bookshelf of journal books.
///
/// Renders a [JournalBookshelf] for navigating to books and managing their colors.
class JournalHeroSection extends StatelessWidget {
  final VoidCallback onType;
  final VoidCallback onRecord;

  /// List of journal books to display on the bookshelf.
  final List<JournalBook> books;

  /// Entry counts per book (bookId -> count).
  final Map<String, int> entryCounts;
  final int recipeCount;

  /// Callback when a book is tapped.
  final void Function(JournalBook) onBookTap;

  /// Callback to add a new book.
  final VoidCallback onAddBook;

  /// Callback when book color is changed.
  final void Function(String bookId, int color) onColorChanged;

  /// Callback to delete a book.
  final void Function(String bookId) onDeleteBook;

  const JournalHeroSection({
    super.key,
    required this.onType,
    required this.onRecord,
    this.books = const [],
    this.entryCounts = const {},
    this.recipeCount = 0,
    required this.onBookTap,
    required this.onAddBook,
    required this.onColorChanged,
    required this.onDeleteBook,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 12),
          if (books.isNotEmpty)
            JournalBookshelf(
              books: books,
              entryCounts: entryCounts,
              recipeCount: recipeCount,
              onBookTap: onBookTap,
              onAddBook: onAddBook,
              onColorChanged: onColorChanged,
              onDeleteBook: onDeleteBook,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
