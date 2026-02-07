import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/journal_book.dart';
import '../../../models/journal_entry.dart';
import 'book_action_bar.dart';
import 'interactive_journal_book.dart';

/// A horizontal carousel of interactive journal books.
class JournalBookCarousel extends StatefulWidget {
  final List<JournalBook> books;
  final String? selectedBookId;
  final Map<String, int> entryCounts;
  final Map<String, List<JournalEntry>> entriesByBook;
  final ValueChanged<JournalBook> onBookSelected;
  final VoidCallback onAddBook;
  final void Function(JournalEntry) onOpenEntry;
  final void Function(JournalEntry) onDeleteEntry;
  final VoidCallback onNewEntry;
  final void Function(String bookId) onDeleteBook;
  final void Function(String bookId, int color) onColorChanged;
  final void Function(String bookId, String newTitle) onTitleChanged;
  final String? newBookId; // ID of newly created book to auto-focus title

  const JournalBookCarousel({
    super.key,
    required this.books,
    required this.selectedBookId,
    required this.entryCounts,
    required this.entriesByBook,
    required this.onBookSelected,
    required this.onAddBook,
    required this.onOpenEntry,
    required this.onDeleteEntry,
    required this.onNewEntry,
    required this.onDeleteBook,
    required this.onColorChanged,
    required this.onTitleChanged,
    this.newBookId,
  });

  @override
  State<JournalBookCarousel> createState() => _JournalBookCarouselState();
}

class _JournalBookCarouselState extends State<JournalBookCarousel> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isBookOpen = false;

  static const double _closedViewportFraction = 0.65;
  static const double _openViewportFraction = 0.95;

  @override
  void initState() {
    super.initState();
    _currentPage = _getInitialPage();
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: _closedViewportFraction,
    );
  }

  int _getInitialPage() {
    if (widget.selectedBookId == null) return 0;
    final idx = widget.books.indexWhere((b) => b.id == widget.selectedBookId);
    return idx >= 0 ? idx : 0;
  }

  @override
  void didUpdateWidget(JournalBookCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Scroll to new book when added
    if (widget.books.length > oldWidget.books.length && widget.newBookId != null) {
      final newIdx = widget.books.indexWhere((b) => b.id == widget.newBookId);
      if (newIdx >= 0 && _pageController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageController.animateToPage(
            newIdx,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onBookOpenChanged(bool isOpen) {
    if (_isBookOpen == isOpen) return;
    setState(() {
      _isBookOpen = isOpen;
    });
    // Recreate controller with new viewportFraction, preserving page
    final page = _currentPage;
    _pageController.dispose();
    _pageController = PageController(
      initialPage: page,
      viewportFraction: isOpen ? _openViewportFraction : _closedViewportFraction,
    );
  }

  void _showMoreOptions(JournalBook book) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Change Cover Color'),
              onTap: () {
                Navigator.pop(ctx);
                _showColorPicker(book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename Book'),
              onTap: () {
                Navigator.pop(ctx);
                // Title editing is handled inline on the book
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(JournalBook book) async {
    final color = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ColorPickerSheet(
        currentColor: book.coverColor ?? JournalBook.defaultCoverColor,
      ),
    );
    if (color != null) {
      widget.onColorChanged(book.id, color);
    }
  }

  void _confirmDeleteBook(JournalBook book) {
    final entryCount = widget.entryCounts[book.id] ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book?'),
        content: Text(
          'This will permanently delete "${book.name}" and all $entryCount ${entryCount == 1 ? 'entry' : 'entries'} in it. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDeleteBook(book.id);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final closedHeight = math.min(320.0, size.height * 0.4);
    final openHeight = math.min(360.0, size.height * 0.45);
    final itemHeight = _isBookOpen ? openHeight : closedHeight;
    final totalItems = widget.books.length + 1;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          height: itemHeight,
          child: PageView.builder(
            key: ValueKey(_isBookOpen),
            controller: _pageController,
            itemCount: totalItems,
            physics: _isBookOpen
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              if (page < widget.books.length) {
                widget.onBookSelected(widget.books[page]);
              }
            },
            itemBuilder: (context, index) {
              if (index == widget.books.length) {
                return _AddBookCard(
                  onTap: widget.onAddBook,
                  isActive: _currentPage == index,
                );
              }

              final book = widget.books[index];
              final isActive = _currentPage == index;
              final entryCount = widget.entryCounts[book.id] ?? 0;
              final entries = widget.entriesByBook[book.id] ?? [];
              final isNewBook = book.id == widget.newBookId;

              return AnimatedScale(
                scale: isActive ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: isActive ? 1.0 : (_isBookOpen ? 0.0 : 0.7),
                  duration: const Duration(milliseconds: 200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: InteractiveJournalBook(
                      book: book,
                      entryCount: entryCount,
                      entries: entries,
                      onNewEntry: widget.onNewEntry,
                      onOpenEntry: widget.onOpenEntry,
                      onDeleteEntry: widget.onDeleteEntry,
                      onDeleteAllEntries: () => _confirmDeleteBook(book),
                      onCustomizeColor: () => _showColorPicker(book),
                      onTitleChanged: (title) => widget.onTitleChanged(book.id, title),
                      onOpenChanged: _onBookOpenChanged,
                      isActive: isActive,
                      isNewBook: isNewBook,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Action bar for current book
        if (_currentPage < widget.books.length)
          BookActionBar(
            onMore: () => _showMoreOptions(widget.books[_currentPage]),
            onDelete: () => _confirmDeleteBook(widget.books[_currentPage]),
            onAdd: widget.onNewEntry,
            isVisible: true,
          ),
      ],
    );
  }
}

/// Add book card that appears at the end of the carousel.
class _AddBookCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isActive;

  const _AddBookCard({
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final bgColor = isDark
        ? colorScheme.surfaceContainerHigh.withOpacity(0.5)
        : colorScheme.surfaceContainerLow.withOpacity(0.7);
    final borderColor = isDark
        ? colorScheme.outlineVariant.withOpacity(0.3)
        : colorScheme.outlineVariant.withOpacity(0.4);

    return AnimatedScale(
      scale: isActive ? 1.0 : 0.85,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: isActive ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 200),
        child: GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: math.min(200.0, size.width * 0.5),
              height: math.min(260.0, size.height * 0.32),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                    offset: const Offset(4, 6),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 32,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'New Book',
                    style: GoogleFonts.merriweather(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple color picker sheet.
class _ColorPickerSheet extends StatefulWidget {
  final int currentColor;

  const _ColorPickerSheet({required this.currentColor});

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late int _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.currentColor;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerHigh : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Choose Cover Color',
            style: GoogleFonts.merriweather(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: JournalBook.presetColors.map((color) {
              final isSelected = color == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(color).withOpacity(0.4),
                        blurRadius: isSelected ? 12 : 6,
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 24)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context, _selectedColor),
            style: FilledButton.styleFrom(
              backgroundColor: Color(_selectedColor),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Apply', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
