import 'package:flutter/material.dart';

import '../../../utils/app_typography.dart';
import '../../../models/journal_book.dart';
import '../../../models/journal_entry.dart';
import 'journal_book_carousel.dart';

/// Dark, minimal landing page with book carousel and Record/Type action pill.
class JournalHeroSection extends StatefulWidget {
  final VoidCallback onType;
  final VoidCallback onRecord;
  
  /// List of journal books to display in the carousel.
  final List<JournalBook> books;
  
  /// Currently selected book ID.
  final String? selectedBookId;
  
  /// Entry counts per book (bookId -> count).
  final Map<String, int> entryCounts;
  
  /// Entries grouped by book ID.
  final Map<String, List<JournalEntry>> entriesByBook;
  
  /// Callback when a book is selected.
  final ValueChanged<JournalBook>? onBookSelected;
  
  /// Callback to add a new book.
  final VoidCallback? onAddBook;
  
  /// Callback when an entry is opened.
  final void Function(JournalEntry)? onOpenEntry;

  /// Callback to delete a single entry (with confirmation).
  final void Function(JournalEntry)? onDeleteEntry;
  
  /// Callback to delete a book and all its entries.
  final void Function(String bookId)? onDeleteBook;
  
  /// Callback when book color is changed.
  final void Function(String bookId, int color)? onColorChanged;
  
  /// Callback when book title is changed.
  final void Function(String bookId, String newTitle)? onTitleChanged;
  
  /// ID of newly created book to auto-focus title.
  final String? newBookId;

  const JournalHeroSection({
    super.key,
    required this.onType,
    required this.onRecord,
    this.books = const [],
    this.selectedBookId,
    this.entryCounts = const {},
    this.entriesByBook = const {},
    this.onBookSelected,
    this.onAddBook,
    this.onOpenEntry,
    this.onDeleteEntry,
    this.onDeleteBook,
    this.onColorChanged,
    this.onTitleChanged,
    this.newBookId,
  });

  @override
  State<JournalHeroSection> createState() => _JournalHeroSectionState();
}

class _JournalHeroSectionState extends State<JournalHeroSection>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;
  bool _isBookOpen = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          padding: EdgeInsets.symmetric(horizontal: _isBookOpen ? 0 : 28),
          child: Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                child: SizedBox(height: _isBookOpen ? 0 : MediaQuery.of(context).padding.top + 8),
              ),
              // Title – hides & collapses when book is open
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: _isBookOpen
                    ? const SizedBox.shrink()
                    : Column(
                        children: [
                          AnimatedOpacity(
                            opacity: _isBookOpen ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              'Here, your journal\ncomes to life',
                              textAlign: TextAlign.center,
                              style: AppTypography.heading1(context).copyWith(height: 1.35),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
              // Book carousel
              if (widget.books.isNotEmpty && 
                  widget.onBookSelected != null && 
                  widget.onAddBook != null &&
                  widget.onOpenEntry != null &&
                  widget.onDeleteEntry != null &&
                  widget.onDeleteBook != null &&
                  widget.onColorChanged != null &&
                  widget.onTitleChanged != null)
                JournalBookCarousel(
                  books: widget.books,
                  selectedBookId: widget.selectedBookId,
                  entryCounts: widget.entryCounts,
                  entriesByBook: widget.entriesByBook,
                  onBookSelected: widget.onBookSelected!,
                  onAddBook: widget.onAddBook!,
                  onOpenEntry: widget.onOpenEntry!,
                  onDeleteEntry: widget.onDeleteEntry!,
                  onNewEntry: widget.onType,
                  onDeleteBook: widget.onDeleteBook!,
                  onColorChanged: widget.onColorChanged!,
                  onTitleChanged: widget.onTitleChanged!,
                  newBookId: widget.newBookId,
                  onBookOpenChanged: (open) => setState(() => _isBookOpen = open),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
