import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../models/journal_book.dart';
import '../../../models/journal_entry.dart';
import 'journal_book_carousel.dart';

/// Dark, minimal landing page with book carousel and Record/Type action pill.
class JournalHeroSection extends StatefulWidget {
  final VoidCallback onType;
  final VoidCallback onRecord;
  final VoidCallback onBookTap;
  final int entryCount;
  
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
    required this.onBookTap,
    required this.entryCount,
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
  late final AnimationController _breatheController;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;
  bool _isBookOpen = false;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
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
    _breatheController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

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
                              style: GoogleFonts.merriweather(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                height: 1.35,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
              ),
              // Book carousel or single book cover
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
                )
              else
                GestureDetector(
                  onTap: widget.onBookTap,
                  child: AnimatedBuilder(
                    animation: _breatheController,
                    builder: (context, child) {
                      final scale = 1.0 + (_breatheController.value * 0.015);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: JournalBookCover(
                      title: 'Journal',
                      subtitle: 'written by you',
                      entryCount: widget.entryCount,
                      width: math.min(180.0, size.width * 0.45),
                      height: math.min(230.0, size.height * 0.28),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Segmented Record / Type pill button.
class ActionPill extends StatelessWidget {
  final VoidCallback onRecord;
  final VoidCallback onType;

  const ActionPill({super.key, required this.onRecord, required this.onType});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final pillBg = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainer;
    final pillBorder = isDark
        ? colorScheme.outlineVariant.withOpacity(0.15)
        : colorScheme.outlineVariant.withOpacity(0.2);

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: pillBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Row(
        children: [
          // Record button
          Expanded(
            child: PillButton(
              icon: Icons.mic_rounded,
              label: 'Record',
              onTap: onRecord,
              isLeft: true,
            ),
          ),
          // Divider
          Container(
            width: 1,
            height: 28,
            color: isDark
                ? colorScheme.outlineVariant.withOpacity(0.2)
                : colorScheme.outlineVariant.withOpacity(0.3),
          ),
          // Type button
          Expanded(
            child: PillButton(
              icon: Icons.title_rounded,
              label: 'Type',
              onTap: onType,
              isLeft: false,
            ),
          ),
        ],
      ),
    );
  }
}

class PillButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLeft;

  const PillButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isLeft,
  });

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _pressed
              ? colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: widget.isLeft ? const Radius.circular(28) : Radius.zero,
            right: !widget.isLeft ? const Radius.circular(28) : Radius.zero,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 22,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable book cover card — displays a journal/diary cover with icon, title,
/// subtitle, and optional entry count. Used in the hero section and can be
/// instantiated for each journal book.
class JournalBookCover extends StatelessWidget {
  final String title;
  final String subtitle;
  final int entryCount;
  final IconData icon;
  final double? width;
  final double? height;

  const JournalBookCover({
    super.key,
    required this.title,
    this.subtitle = 'written by you',
    this.entryCount = 0,
    this.icon = Icons.auto_stories_rounded,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    final bookBg = isDark
        ? colorScheme.surfaceContainerHigh
        : colorScheme.surfaceContainerLow;
    final bookBorder = isDark
        ? colorScheme.outlineVariant.withOpacity(0.2)
        : colorScheme.outlineVariant.withOpacity(0.3);

    return Container(
      width: width ?? math.min(180.0, size.width * 0.45),
      height: height ?? math.min(230.0, size.height * 0.28),
      decoration: BoxDecoration(
        color: bookBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bookBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            offset: const Offset(6, 8),
            blurRadius: 24,
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withOpacity(0.7),
              offset: const Offset(-4, -4),
              blurRadius: 16,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            offset: const Offset(2, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 36,
            color: colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.merriweather(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.8),
              letterSpacing: 1,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurface.withOpacity(0.35),
                letterSpacing: 1.5,
              ),
            ),
          ],
          if (entryCount > 0) ...[
            const SizedBox(height: 10),
            Text(
              '$entryCount ${entryCount == 1 ? 'entry' : 'entries'}',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withOpacity(0.25),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Stacked entry cards with 3D depth effect.
class StackedEntryCards extends StatelessWidget {
  final List<JournalEntry> entries;
  final List<JournalEntry> allEntries;
  final Set<String> pinnedIds;
  final bool selectionMode;
  final Set<String> selectedEntryIds;
  final void Function(JournalEntry entry) onOpenEntry;
  final void Function(String) onToggleEntrySelection;
  final void Function(JournalEntry) onTogglePin;
  final void Function(JournalEntry) onDelete;

  const StackedEntryCards({
    super.key,
    required this.entries,
    required this.allEntries,
    required this.pinnedIds,
    required this.selectionMode,
    required this.selectedEntryIds,
    required this.onOpenEntry,
    required this.onToggleEntrySelection,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Show up to 3 cards in the stack
    final stackCount = entries.length.clamp(1, 3);
    final topEntry = entries.first;

    // Paper-like back layer colors
    final backLayer1 = isDark
        ? colorScheme.surfaceContainer.withOpacity(0.6)
        : const Color(0xFFE8E3DB);
    final backLayer2 = isDark
        ? colorScheme.surfaceContainer.withOpacity(0.4)
        : const Color(0xFFDDD8D0);

    return SizedBox(
      height: 400,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Background cards (back to front) with Transform.translate
          if (stackCount >= 3)
            Positioned(
              top: 0,
              left: 20,
              right: 20,
              child: Transform.translate(
                offset: const Offset(0, 16),
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: backLayer2,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (stackCount >= 2)
            Positioned(
              top: 0,
              left: 10,
              right: 10,
              child: Transform.translate(
                offset: const Offset(0, 8),
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    color: backLayer1,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Front card (fully rendered with content)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                if (selectionMode) {
                  onToggleEntrySelection(topEntry.id);
                } else {
                  onOpenEntry(topEntry);
                }
              },
              onLongPress: () {
                if (!selectionMode) {
                  onToggleEntrySelection(topEntry.id);
                }
              },
              child: StackedFrontCard(
                entry: topEntry,
                isPinned: pinnedIds.contains(topEntry.id),
                isSelected: selectedEntryIds.contains(topEntry.id),
                selectionMode: selectionMode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The front card of the stacked entry display.
class StackedFrontCard extends StatelessWidget {
  final JournalEntry entry;
  final bool isPinned;
  final bool isSelected;
  final bool selectionMode;

  const StackedFrontCard({
    super.key,
    required this.entry,
    required this.isPinned,
    required this.isSelected,
    required this.selectionMode,
  });

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day}th ${months[dt.month - 1]}, ${dt.year}';
  }

  String _formatDay(DateTime dt) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[dt.weekday - 1];
  }

  String _getTitle() {
    final t = (entry.title ?? '').trim();
    if (t.isNotEmpty) return t;
    return 'Untitled';
  }

  String _getPreview() {
    if (entry.delta is List && (entry.delta as List).isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(entry.delta as List);
        return doc.toPlainText().replaceAll('\r', '').trim();
      } catch (_) {}
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Paper gradient colors
    final flat = isDark
        ? colorScheme.surfaceContainerHigh
        : const Color(0xFFF8F5F0);
    final highlight = isDark
        ? colorScheme.surfaceContainerHighest
        : const Color(0xFFFFFDF8);
    final shadow = isDark
        ? colorScheme.surfaceContainer
        : const Color(0xFFEDE8E0);

    final date = entry.createdAt;
    final preview = _getPreview();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 250,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0.0, 0.1, 0.5, 0.9, 1.0],
          colors: [shadow, highlight, flat, highlight, shadow],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withOpacity(isDark ? 0.15 : 0.2),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            offset: const Offset(0, 4),
            blurRadius: 16,
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              offset: const Offset(-2, -2),
              blurRadius: 8,
            ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header
          Row(
            children: [
              Text(
                _formatDate(date),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              Text(
                _formatDay(date),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              if (selectionMode) ...[
                const SizedBox(width: 8),
                Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Crease line
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  colorScheme.outlineVariant.withOpacity(0.25),
                  colorScheme.outlineVariant.withOpacity(0.25),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.2, 0.8, 1.0],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Title
          Text(
            _getTitle(),
            style: GoogleFonts.merriweather(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          // Preview text
          Expanded(
            child: Text(
              preview,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: colorScheme.onSurface.withOpacity(0.6),
                height: 1.55,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
          // Tags
          if (entry.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: entry.tags.take(3).map((t) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.primary,
                    ),
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Latest entry overlay shown when user taps the book cover.
class LatestEntryOverlay extends StatefulWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const LatestEntryOverlay({
    super.key,
    required this.entry,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<LatestEntryOverlay> createState() => _LatestEntryOverlayState();
}

class _LatestEntryOverlayState extends State<LatestEntryOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    _controller.reverse().then((_) => widget.onDismiss());
  }

  String _getTitle() {
    final t = (widget.entry.title ?? '').trim();
    if (t.isNotEmpty) return t;
    return 'Untitled';
  }

  String _getPreview() {
    if (widget.entry.delta is List && (widget.entry.delta as List).isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(widget.entry.delta as List);
        return doc.toPlainText().replaceAll('\r', '').trim();
      } catch (_) {}
    }
    return '';
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${weekdays[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Paper gradient colors
    final flat = isDark
        ? colorScheme.surfaceContainerHigh
        : const Color(0xFFF8F5F0);
    final highlight = isDark
        ? colorScheme.surfaceContainerHighest
        : const Color(0xFFFFFDF8);
    final shadow = isDark
        ? colorScheme.surfaceContainer
        : const Color(0xFFEDE8E0);

    final backLayer1 = isDark
        ? colorScheme.surfaceContainer.withOpacity(0.6)
        : const Color(0xFFE8E3DB);
    final backLayer2 = isDark
        ? colorScheme.surfaceContainer.withOpacity(0.4)
        : const Color(0xFFDDD8D0);

    final date = widget.entry.createdAt;
    final preview = _getPreview();

    return GestureDetector(
      onTap: _dismiss,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: Center(
            child: SlideTransition(
              position: _slideAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: GestureDetector(
                  onTap: () {}, // Absorb taps on the card
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      height: 340,
                      child: Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          // Bottom layer (darkest)
                          Positioned(
                            top: 16,
                            left: 16,
                            right: 16,
                            child: Container(
                              height: 310,
                              decoration: BoxDecoration(
                                color: backLayer2,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                                    offset: const Offset(0, 4),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Middle layer
                          Positioned(
                            top: 8,
                            left: 8,
                            right: 8,
                            child: Container(
                              height: 318,
                              decoration: BoxDecoration(
                                color: backLayer1,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                                    offset: const Offset(0, 2),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Front card (paper gradient)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: widget.onTap,
                              child: Container(
                                height: 320,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    stops: const [0.0, 0.1, 0.5, 0.9, 1.0],
                                    colors: [shadow, highlight, flat, highlight, shadow],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant.withOpacity(isDark ? 0.15 : 0.2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.5 : 0.12),
                                      offset: const Offset(0, 6),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Date
                                    Text(
                                      _formatDate(date),
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: colorScheme.onSurface.withOpacity(0.45),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Divider crease
                                    Container(
                                      height: 1,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            colorScheme.outlineVariant.withOpacity(0.3),
                                            colorScheme.outlineVariant.withOpacity(0.3),
                                            Colors.transparent,
                                          ],
                                          stops: const [0.0, 0.2, 0.8, 1.0],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    // Title
                                    Text(
                                      _getTitle(),
                                      style: GoogleFonts.merriweather(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.onSurface,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 12),
                                    // Preview
                                    Expanded(
                                      child: Text(
                                        preview,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: colorScheme.onSurface.withOpacity(0.55),
                                          height: 1.6,
                                        ),
                                        overflow: TextOverflow.fade,
                                      ),
                                    ),
                                    // Tags
                                    if (widget.entry.tags.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Wrap(
                                          spacing: 6,
                                          children: widget.entry.tags.take(3).map((t) => Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              t,
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          )).toList(),
                                        ),
                                      ),
                                    const SizedBox(height: 8),
                                    // Tap hint
                                    Center(
                                      child: Text(
                                        'Tap to open  ·  Tap outside to close',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: colorScheme.onSurface.withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
